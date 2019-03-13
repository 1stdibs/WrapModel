//
//  WrapModel.swift
//  NewModel
//
//  Created by Ken Worley on 11/25/17.
//  Copyright © 2017 Ken Worley. All rights reserved.
//

import Foundation

fileprivate let kNSCodingIsMutableKey = "mutable"
fileprivate let kNSCodingDataKey = "data"

// Used at the beginning of a keyPath internally to indicate the current level of the dictionary.
// Used by submodels that represent properties at the same level of the data dict as the parent model.
fileprivate let kSameDictionaryKey = "<same>"

// Used to demarcate the end of a keypath identifier that begins with kSameDictionaryKey
fileprivate let kSameDictionaryEndKey = "</same>"

@objcMembers
open class WrapModel : NSObject, NSCopying, NSMutableCopying, NSCoding, FDModelSerializing {
    fileprivate let modelData:[String:Any]
    private(set) var originalJSON:String?
    private var properties = [AnyWrapProperty]()
    private lazy var sortedProperties: [AnyWrapProperty] = {
        // Pre-sort properties by length of key path so that when applying changes to the
        // data dictionary to produce a mutated copy, parent dictionaries are modified before
        // their children.
        properties.sort(by: { (p1, p2) -> Bool in
            let p1len = p1.keyPath.hasPrefix(kSameDictionaryKey) ? kSameDictionaryKey.count : p1.keyPath.count
            let p2len = p2.keyPath.hasPrefix(kSameDictionaryKey) ? kSameDictionaryKey.count : p2.keyPath.count
            return p1len < p2len
        })
        return properties
    }()
    
    public let isMutable:Bool
    public var originalModelData: [String:Any] {
        return modelData
    }
    public var originalModelDataAsJSON: String? {
        guard let data = try? JSONSerialization.data(withJSONObject: originalModelData, options: [.prettyPrinted]) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    public func currentModelData(withNulls:Bool, forSerialization: Bool = false) -> [String:Any] {
        // Create a new data dictionary and put current property data into it
        var data = [String:Any].init(minimumCapacity: properties.count)
        
        func updateData(withProperty property: AnyWrapProperty) {
            if let pval = property.rawValue() {
                data.setValue(pval, forKeyPath: property.keyPath, createMissing: true)
            } else if withNulls {
                data.setValue(NSNull(), forKeyPath: property.keyPath, createMissing: true)
            }
        }
        
        for property in sortedProperties {
            if !forSerialization {
                updateData(withProperty: property)
                continue
            }
            
            switch property.serialize {
            case .always:
                updateData(withProperty: property)
            case .never:
                continue // do nothing, we don't want this property in the data dictionary
            }
           
        }
        return data
    }
    // Note - .sortedKeys is iOS 11 or later only
    public let jsonOutputOptions: JSONSerialization.WritingOptions = [.prettyPrinted /*, .sortedKeys*/]
    public func currentModelDataAsJSON(withNulls:Bool) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: currentModelData(withNulls: withNulls, forSerialization: true), options: jsonOutputOptions) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Initialize with data dictionary
    public required init(data:[String:Any], mutable:Bool) {
        self.modelData = data
        self.isMutable = mutable
        super.init()
        
        // Get property references
        let mirror = Mirror(reflecting: self)
        properties.reserveCapacity(mirror.children.count)
        for prop in mirror.children {
            switch prop.value {
            case let optionalObj as Optional<Any>:
                switch optionalObj {
                case .some(let innerObj):
                    if let wrapProp = innerObj as? AnyWrapProperty {
                        properties.append(wrapProp)
                    }
                case .none:
                    break
                }
            }
        }
        
        // Give each property a reference back to the model object
        properties.forEach { $0.model = self }
    }
    
    /// Initialize new empty model
    public convenience override init() {
        self.init(data: [String:Any](), mutable: true)
    }

    /// Initialize with JSON String
    public convenience init?(json:String?, mutable:Bool = false) {
        guard let json = json else { return nil }
        // convert json string to dict and call other initializer
        if let data = json.data(using: .utf8),
            let dataObj = try? JSONSerialization.jsonObject(with: data),
            let dataDict = dataObj as? [String:Any] {
            self.init(data: dataDict, mutable:mutable)
            #if DEBUG
            originalJSON = json
            #endif
        } else {
            return nil
        }
    }
    
    /// Initialize with JSON string encoded as Data
    public convenience init?(jsonData:Data?, mutable:Bool = false) {
        guard let jsonData = jsonData else { return nil }
        // convert data to json string and call other initializer
        if let jsonStr = String(data: jsonData, encoding: .utf8) {
            self.init(json:jsonStr, mutable:mutable)
        } else {
            return nil
        }
    }
    
    /// Initialize as copy of another model with or without mutations
    public convenience init(asCopyOf model:WrapModel, withMutations:Bool, mutable:Bool) {
        // Use a copy of the model's original data dictionary and copy any mutations
        // and already decoded values if the copy should include mutations.
        self.init(data:model.originalModelData, mutable:mutable)
        if withMutations {
            model.cacheLock.reading {
                self.cachedValues = model.cachedValues
            }
        }
    }
    
    //MARK: FDModelSerializing conformance
    
    /// FDModelSerializing conforming initializer
    required public convenience init(jsonDictionary: [AnyHashable : Any], mutable: Bool) {
        if let dict = jsonDictionary as? [String : Any] {
            self.init(data: dict, mutable: mutable)
        } else {
            assert(false, "Dictionary with non-string keys used to initialize WrapModel")
            self.init(data: [:], mutable: mutable)
        }
    }
    
    public func jsonDictionaryWithoutNulls(_ withoutNulls: Bool) -> [AnyHashable : Any] {
        return currentModelData(withNulls: !withoutNulls, forSerialization: true)
    }

    //MARK: Cached property values
    
    // Keep cached/converted values for properties.
    fileprivate var dataLock:WrapModelLock?
    fileprivate lazy var cacheLock:WrapModelLock = self.dataLock ?? WrapModelLock()
    private lazy var cachedValues = [String:Any].init(minimumCapacity: self.properties.count)
    fileprivate func getCached(forProperty property:AnyWrapProperty) -> Any? {
        return cacheLock.reading {
            return self.cachedValues[property.keyPath]
        }
    }
    fileprivate func setCached(value:Any?, forProperty property:AnyWrapProperty) {
        cacheLock.writing {
            self.cachedValues[property.keyPath] = value
        }
    }
    fileprivate func clearCached(forProperty property:AnyWrapProperty) {
        cacheLock.writing {
            self.cachedValues[property.keyPath] = nil
        }
    }

    public func clearMutations() {
        cacheLock.writing {
            self.cachedValues = [String:Any]()
        }
    }
    
    // Returns untyped property from the model's data dictionary.
    fileprivate func propertyFromKeyPath(_ keyPath: String) -> Any? {
        return self.modelData.value(forKeyPath: keyPath)
    }

    //MARK: - Comparable
    
    /// By default, equality is determined by comparing mutated data dictionaries.
    /// Override to change this.
    open func isEqualToModel(model: WrapModel?) -> Bool {
        guard let model = model else { return false }
        guard self !== model else { return true }
        let myData = self.currentModelData(withNulls: false)
        let theirData = model.currentModelData(withNulls: false)
        guard myData.count == theirData.count else { return false }
        // Sadly, have to depend on ObjC NSDictionary for this...
        return (myData as NSDictionary).isEqual(to: theirData)
    }
    
    override open func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? WrapModel else { return false }
        guard self !== object else { return true }
        guard object.isKind(of: self.classForCoder) else { return false }
        return self.isEqualToModel(model: object)
    }
    
    static func == (lhs: WrapModel, rhs: WrapModel) -> Bool {
        return lhs.isEqualToModel(model: rhs)
    }

    //MARK: - NSCopying
    
    // Produce an immutable copy of model in its current state
    public func copy(with zone: NSZone? = nil) -> Any {
        // If the object is immutable, don't actually copy - just return this instance
        if (!isMutable) {
            return self
        }
        // Use a copy of the model's original data dictionary and copy any mutations
        // and already decoded values.
        let theCopy = type(of: self).init(data: self.originalModelData, mutable:false)
        cacheLock.reading {
            theCopy.cachedValues = self.cachedValues
        }
        return theCopy
    }

    // Produce a mutable copy of the model in its current state
    public func mutableCopy(with zone: NSZone? = nil) -> Any {
        // Use a copy of the model's original data dictionary and copy any mutations
        // and already decoded values.
        let theCopy = type(of: self).init(data: self.originalModelData, mutable:true)
        cacheLock.reading {
            theCopy.cachedValues = self.cachedValues
        }
        return theCopy
    }
    
    //MARK: - NSCoding
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(isMutable, forKey: kNSCodingIsMutableKey)
        if isMutable {
            aCoder.encode(currentModelData(withNulls: false), forKey:kNSCodingDataKey)
        } else {
            aCoder.encode(modelData, forKey:kNSCodingDataKey)
        }
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        let mutable = aDecoder.decodeBool(forKey: kNSCodingIsMutableKey)
        if let dict = aDecoder.decodeObject(forKey: kNSCodingDataKey) as? [AnyHashable:Any] {
            self.init(jsonDictionary: dict, mutable: mutable)
        } else {
            return nil
        }
    }
    
    //MARK: - CustomDebugStringConvertible
    
    override open var debugDescription: String {
        return description
    }

    //MARK: - CustomStringConvertible

    override open var description: String {
        var desc = "Model \(type(of:self)) - \(super.description) mutable: \(isMutable) \n"
        let json = currentModelDataAsJSON(withNulls: true) ?? "{}"
        desc.append(json)
        return desc
    }
}

// Dictionary extension is (modified) from: https://gist.github.com/dfrib/d7419038f7e680d3f268750d63f0dfae
fileprivate extension Dictionary {
    mutating func setValue(_ value: Any, forKeyPath keyPath: String, createMissing: Bool = false) {
        guard let keys = Dictionary.keyPathKeys(forKeyPath: keyPath) else { return }
        if keys.count == 1, keyPath.hasPrefix(kSameDictionaryKey), let valueDict = value as? [String:Any] {
            // Merge top level keys from given dictionary with this one
            for (key, val) in valueDict {
                self.setValue(val, forKeyPath: key)
            }
        } else {
            setValueForKeys(value: value, keys: keys, createMissing: createMissing)
        }
    }
    
    func value(forKeyPath keyPath: String) -> Any? {
        guard let keys = Dictionary.keyPathKeys(forKeyPath: keyPath) else { return nil }
        if keys.count == 1 && keyPath.hasPrefix(kSameDictionaryKey) {
            // No subdictionary - return myself
            return self
        }
        return getValueForKeys(keys)
    }
    
    static private func keyPathKeys(forKeyPath: String) -> [Key]? {
        let keys = forKeyPath.components(separatedBy: ".")
            .reversed().compactMap({ $0 as? Key })
        return keys.isEmpty ? nil : keys
    }
    
    // recursively (attempt to) access queried subdictionaries
    // (keyPath will never be empty here; the explicit unwrapping is safe)
    private func getValueForKeys(_ keys: [Key]) -> Any? {
        guard let value = self[keys.last!] else { return nil }
        return keys.count == 1 ? value : (value as? [Key: Any])
            .flatMap { $0.getValueForKeys(Array(keys.dropLast())) }
    }
    
    // recursively (attempt to) access the queried subdictionaries to
    // finally replace the "inner value", given that the key path is valid
    // If a dictionary is missing, add an empty one.
    private mutating func setValueForKeys(value: Any, keys: [Key], createMissing:Bool) {
        if keys.count == 1 {
            (value as? Value).map { self[keys.last!] = $0 }
        }
        else {
            let subDictVal = self[keys.last!]
            if subDictVal == nil {
                if createMissing {
                    // Missing subdictionary - create an empty one.
                    var subDict = [Key:Value]()
                    subDict.setValueForKeys(value: value, keys: Array(keys.dropLast()), createMissing: createMissing)
                    (subDict as? Value).map { self[keys.last!] = $0 }
                }
            } else if var subDict = subDictVal as? [Key:Value] {
                // Subdict exists and type is correct
                subDict.setValueForKeys(value: value, keys: Array(keys.dropLast()), createMissing: createMissing)
                (subDict as? Value).map { self[keys.last!] = $0 }
            } else {
                // Subdict exists but is wrong type - can't execute mutation
            }
        }
    }
}

// Protocol which all WrapProperty instances conform to
public protocol AnyWrapProperty : class {
    // Key path within the model's data dictionary where this property's value is found
    var keyPath: String {get}
    // The model this property resides in - set by the model itself at initialization
    var model:WrapModel! {set get}
    // Return this property to its initial unmutated value
    func clearMutation()
    // Return the property's current value as represented in the data dictionary
    func rawValue() -> Any?
    // Determines how a model should be serialized.
    var serialize: WrapPropertySerializationMode { get }

}

private let trimCharSet = CharacterSet.init(charactersIn: "_")

public enum WrapPropertySerializationMode {
    case never
    case always
}

open class WrapProperty<T> : AnyWrapProperty {
    public let keyPath: String
    public let defaultValue: T
    public weak var model:WrapModel!
    public let serialize: WrapPropertySerializationMode

    // closure to convert JSON value to native model value - usually assigned by a subclass if necessary
    public var toModelConverter: ((_ jsonValue: Any) -> T)?
    
    // closure to convert native model value back to JSON value - assigned by subclass if necessary
    public var fromModelConverter: ((_ nativeValue: T) -> Any?)?
    
    public init(_ keyPath: String, defaultValue: T, serialize: WrapPropertySerializationMode = .always) {
        self.keyPath = keyPath.trimmingCharacters(in: trimCharSet)
        self.defaultValue = defaultValue
        self.serialize = serialize
    }
    
    public func hasValue() -> Bool {
        return internalValue() != nil
    }
    
    public var value: T {
        get {
            return internalValue() ?? defaultValue
        }
        set {
            internalSetValue(newValue)
        }
    }

    private func internalValue() -> T? {
        if let cachedValue = model.getCached(forProperty: self) {
            if cachedValue is NSNull { return nil }
            return cachedValue as? T
        }
        var convertedValue:T?
        if let extractedValue = model.propertyFromKeyPath(keyPath) {
            if let converter = toModelConverter {
                convertedValue = converter(extractedValue)
            } else if let finalValue = extractedValue as? T {
                convertedValue = finalValue
            }
        }
        model.setCached(value: convertedValue ?? NSNull(), forProperty: self)
        return convertedValue
    }
    
    private func internalSetValue(_ value: T) {
        assert(model.isMutable, "Attempt to mutate immutable model")
        guard model.isMutable else { return }
        switch value {
        case let optionalObj as Optional<Any>:
            switch optionalObj {
            case .some(let innerObj):
                model.setCached(value: innerObj, forProperty: self)
            case .none:
                // Setting value to nil
                model.setCached(value: NSNull(), forProperty: self)
            }
        default:
            model.setCached(value: value, forProperty: self)
        }
    }

    public func rawValue() -> Any? {
        let currentValue = value
        if let converter = fromModelConverter {
            return converter(currentValue)
        }
        return currentValue
    }
    
    public func clearMutation() {
        model.clearCached(forProperty: self)
    }
}

public protocol WrapConvertibleEnum: RawRepresentable, Hashable where RawValue == Int {
    static func conversionDict() -> [String:Self]
    static func stringValue(from:Self) -> String?
}

public extension WrapConvertibleEnum {
    public func stringValue() -> String? {
        return type(of: self).stringValue(from: self)
    }
    public static func stringValue(from:Self) -> String? {
        return conversionDict().inverted()[from]
    }
    public var hashValue:Int {
        return rawValue.hashValue
    }
}

// For use with Enum types with Int raw value type represented by a String in the
// data dictionary.
public class WrapPropertyEnum<T:RawRepresentable> : WrapProperty<T> where T.RawValue == Int {
    let conversionDict: [String:T]
    private let reverseDict: [Int:String]
    public init(_ keyPath: String, defaultEnum: T, conversionDict: [String:T], serialize: WrapPropertySerializationMode = .always) {
        self.conversionDict = conversionDict
        var reversed = [Int:String]()
        reversed.reserveCapacity(conversionDict.count)
        conversionDict.forEach { (keyString:String, value:T) in
            reversed[value.rawValue] = keyString
        }
        self.reverseDict = reversed
        super.init(keyPath,
                   defaultValue: defaultEnum,
                   serialize: serialize)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> T in
            guard let strongSelf = self,
                    let strValue = jsonValue as? String else { return defaultEnum }
            if let converted = strongSelf.conversionDict[strValue] {
                return converted
            }
            return defaultEnum
        }
        self.fromModelConverter = { [weak self] (nativeValue:T) -> Any? in
            guard let strongSelf = self else { return nil }
            return strongSelf.reverseDict[nativeValue.rawValue]
        }
    }
    
    public func asString() -> String? {
        return rawValue() as? String
    }
}

public class WrapPropertyConvertibleEnum<T:WrapConvertibleEnum> : WrapPropertyEnum<T> {
    public init(_ keyPath: String, defaultEnum: T, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath,
                   defaultEnum: defaultEnum,
                   conversionDict: T.conversionDict(), serialize: serialize)
    }
}

public class WrapPropertyOptional<DataClass:Any>: WrapProperty<DataClass?> {
    public init(_ keyPath: String, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: nil, serialize: serialize)
        self.toModelConverter = { (jsonValue:Any) -> DataClass? in
            return jsonValue as? DataClass
        }
        self.fromModelConverter = { (nativeValue:DataClass?) -> Any? in
            return nativeValue
        }
    }
}

public class WrapPropertyModel<ModelClass:FDModelSerializing>: WrapProperty<ModelClass?> {
    public init(_ keyPath: String, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: nil, serialize: serialize)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> ModelClass? in
            guard let dictValue = jsonValue as? [String:Any] else { return nil }
            // Copy mutable status of parent model
            let aModel = ModelClass.init(jsonDictionary: dictValue, mutable: self?.model.isMutable ?? false)
            if let wrapModel = aModel as? WrapModel, let lock = self?.model.cacheLock {
                // Share parent model's data lock with child model
                wrapModel.dataLock = lock
            }
            return aModel
        }
        self.fromModelConverter = { (nativeValue:ModelClass?) -> Any? in
            return nativeValue?.jsonDictionaryWithoutNulls(true)
        }
    }
}

public class WrapPropertyGroup<ModelClass:WrapModel>: WrapProperty<ModelClass> {
    public init() {
        // A default value that will never be used
        let dummy = ModelClass.init(data: [:], mutable: false)
        let groupKeyPath = kSameDictionaryKey + UUID().uuidString + kSameDictionaryEndKey
        super.init(groupKeyPath, defaultValue: dummy, serialize: .always)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> ModelClass in
            let dictValue = jsonValue as? [String:Any] ?? [String:Any]()
            // Copy mutable status of parent model
            let aModel = ModelClass.init(data: dictValue, mutable: self?.model.isMutable ?? false)
            if let lock = self?.model.cacheLock {
                // Share parent model's data lock with child model
                aModel.dataLock = lock
            }
            return aModel
        }
        self.fromModelConverter = { (nativeValue:ModelClass) -> Any? in
            return nativeValue.jsonDictionaryWithoutNulls(true)
        }
    }
}

public class WrapPropertyArray<ElementClass:Any>: WrapProperty<[ElementClass]> {
    public init(_ keyPath: String, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: [], serialize: serialize)
        self.toModelConverter = { (jsonValue:Any) -> [ElementClass] in
            return jsonValue as? [ElementClass] ?? []
        }
        self.fromModelConverter = { (nativeValue:[ElementClass]) -> Any? in
            return nativeValue
        }
    }
}

public class WrapPropertyOptionalArray<ElementClass:Any>: WrapPropertyOptional<[ElementClass]> {
}

public class WrapPropertyArrayOfModel<ModelClass:FDModelSerializing>: WrapProperty<[ModelClass]> {
    public init(_ keyPath: String, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: [], serialize: serialize)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> [ModelClass] in
            guard let dictArray = jsonValue as? [[String:Any]] else { return [] }
            // Copy mutable status of parent model
            let modelArray:[ModelClass] = dictArray.map {
                let aModel = ModelClass.init(jsonDictionary:$0, mutable:self?.model.isMutable ?? false)
                if let wrapModel = aModel as? WrapModel, let lock = self?.model.cacheLock {
                    // Share parent model's data lock with child model
                    wrapModel.dataLock = lock
                }
                return aModel
            }
            return modelArray
        }
        self.fromModelConverter = { (nativeValue:[ModelClass]) -> Any? in
            return nativeValue.map { return $0.jsonDictionaryWithoutNulls(true) }
        }
    }
}

public class WrapPropertyOptionalArrayOfModel<ModelClass:FDModelSerializing>: WrapProperty<[ModelClass]?> {
    public init(_ keyPath: String, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: nil, serialize: serialize)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> [ModelClass]? in
            guard let dictArray = jsonValue as? [[String:Any]] else { return nil }
            // Copy mutable status of parent model
            let modelArray:[ModelClass] = dictArray.map {
                let aModel = ModelClass.init(jsonDictionary:$0, mutable:self?.model.isMutable ?? false)
                if let wrapModel = aModel as? WrapModel, let lock = self?.model.cacheLock {
                    // Share parent model's data lock with child model
                    wrapModel.dataLock = lock
                }
                return aModel
            }
            return modelArray
        }
        self.fromModelConverter = { (nativeValue:[ModelClass]?) -> Any? in
            guard let modelArray = nativeValue else { return nil }
            return modelArray.map { return $0.jsonDictionaryWithoutNulls(true) }
        }
    }
}

public class WrapPropertyDictionaryOfModel<ModelClass:FDModelSerializing>: WrapProperty<[String:ModelClass]> {
    public init(_ keyPath: String, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: [:], serialize: serialize)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> [String:ModelClass] in
            guard let dict = jsonValue as? [String:[String:Any]] else { return [:] }
            // Copy mutable status of parent model
            var modelDict = [String:ModelClass]()
            modelDict.reserveCapacity(dict.count)
            for (key,value) in dict {
                let aModel = ModelClass.init(jsonDictionary:value, mutable:self?.model.isMutable ?? false)
                if let wrapModel = aModel as? WrapModel, let lock = self?.model.cacheLock {
                    // Share parent model's data lock with child model
                    wrapModel.dataLock = lock
                }
                modelDict[key] = aModel
            }
            return modelDict
        }
        self.fromModelConverter = { (nativeValue:[String:ModelClass]) -> Any? in
            var rawDict = [String:Any]()
            rawDict.reserveCapacity(nativeValue.count)
            for (key,value) in nativeValue {
                rawDict[key] = value.jsonDictionaryWithoutNulls(true)
            }
            return rawDict
        }
    }
}

public class WrapPropertyOptionalDictionaryOfModel<ModelClass:FDModelSerializing>: WrapProperty<[String:ModelClass]?> {
    public init(_ keyPath: String, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: nil, serialize: serialize)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> [String:ModelClass]? in
            guard let dict = jsonValue as? [String:[String:Any]] else { return nil }
            // Copy mutable status of parent model
            var modelDict = [String:ModelClass]()
            modelDict.reserveCapacity(dict.count)
            for (key,value) in dict {
                let aModel = ModelClass.init(jsonDictionary:value, mutable:self?.model.isMutable ?? false)
                if let wrapModel = aModel as? WrapModel, let lock = self?.model.dataLock {
                    // Share parent model's data lock with child model
                    wrapModel.dataLock = lock
                }
                modelDict[key] = aModel
            }
            return modelDict
        }
        self.fromModelConverter = { (nativeValue:[String:ModelClass]?) -> Any? in
            guard let modelDict = nativeValue else { return nil }
            var rawDict = [String:Any]()
            rawDict.reserveCapacity(modelDict.count)
            for (key,value) in modelDict {
                rawDict[key] = value.jsonDictionaryWithoutNulls(true)
            }
            return rawDict
        }
    }
}

public class WrapPropertyIntFromString: WrapProperty<Int> {
    override public init(_ keyPath: String, defaultValue: Int = 0, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: defaultValue, serialize: serialize)
        self.toModelConverter = { (jsonValue:Any) -> Int in
            if let strVal = jsonValue as? String {
                if let intVal =  Int(strVal) {
                    return intVal
                } else if let dblVal = Double(strVal) {
                    return Int(dblVal.rounded())
                }
                return defaultValue

            } else if let intVal = jsonValue as? Int {
                return intVal
            } else if let dblVal = jsonValue as? Double {
                return Int(dblVal.rounded())
            }
            return 0
        }
        self.fromModelConverter = {(nativeValue:Int) -> Any? in
            return "\(nativeValue)"
        }
    }
}

@objc
public enum WrapPropertyBoolOutputType: Int {
    case boolean // native JSON true/false
    case yesNo // "Y" or "N"
    case tfString // "T" or "F"
    case numeric // 0 or 1
}

public class WrapPropertyBool: WrapProperty<Bool> {
    public init(_ keyPath: String, boolType: WrapPropertyBoolOutputType = .boolean, defaultValue: Bool = false, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: defaultValue, serialize: serialize)
        self.toModelConverter = { (jsonValue:Any) -> Bool in
            if let boolVal = jsonValue as? Bool {
                return boolVal
            } else if let strVal = jsonValue as? String {
                if let charVal = strVal.first {
                    return WPTrueCharSet().contains(String(charVal))
                } else {
                    return false
                }
            } else if let intVal = jsonValue as? Int {
                return intVal != 0
            }
            return false
        }
        self.fromModelConverter = { (nativeValue:Bool) -> Any? in
            switch boolType {
                case .boolean: return nativeValue
                case .yesNo: return nativeValue ? "yes" : "no"
                case .tfString: return nativeValue ? "T" : "F"
                case .numeric: return nativeValue ? 1 : 0
            }
        }
    }
}

extension WPBoolean {

    init(boolVal:Bool) {
        self.init(rawValue: boolVal ? WPBoolean.trueVal.rawValue : WPBoolean.falseVal.rawValue)!
    }
    
    public func boolValue(default defaultVal:Bool) -> Bool {
        switch self {
        case .trueVal: return true
        case .falseVal: return false
        case .notSet: return defaultVal
        }
    }
    
    public func isSet() -> Bool {
        return self != .notSet
    }
    
    public func isTrue() -> Bool {
        return self == .trueVal
    }
    
    public func isNotTrue() -> Bool {
        return self != .trueVal
    }
    
    public func isFalse() -> Bool {
        return self == .falseVal
    }
}

public class WrapPropertyOptionalBool: WrapProperty<WPBoolean> {
    public init(_ keyPath: String, boolType: WrapPropertyBoolOutputType = .boolean, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: .notSet, serialize: serialize)
        self.toModelConverter = { (jsonValue:Any) -> WPBoolean in
            if let boolVal = jsonValue as? Bool {
                return boolVal ? .trueVal : .falseVal
            } else if let strVal = jsonValue as? String {
                if let charVal = strVal.first {
                    return WPTrueCharSet().contains(String(charVal)) ? .trueVal : .falseVal
                } else {
                    return .notSet
                }
            } else if let intVal = jsonValue as? Int {
                return intVal != 0 ? .trueVal : .falseVal
            }
            return .notSet
        }
        self.fromModelConverter = { (nativeValue:WPBoolean) -> Any? in
            let boolVal:Bool
            switch nativeValue {
                case .trueVal: boolVal = true
                case .falseVal: boolVal = false
                case .notSet: return nil //boolVal = nil
            }
            switch boolType {
                case .boolean: return boolVal
                case .yesNo: return boolVal ? "yes" : "no"
                case .tfString: return boolVal ? "T" : "F"
                case .numeric: return boolVal ? 1 : 0
            }
        }
    }
}

public class WrapPropertyInt: WrapProperty<Int> {
    override public init(_ keyPath: String, defaultValue: Int = 0, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: defaultValue, serialize: serialize)
        self.toModelConverter = { (jsonValue:Any) -> Int in
            if let dblVal = jsonValue as? Double {
                return Int(dblVal.rounded())
            } else if let intVal = jsonValue as? Int {
                return intVal
            } else if let strVal = jsonValue as? String {
                if let intVal =  Int(strVal) {
                    return intVal
                } else if let dblVal = Double(strVal) {
                    return Int(dblVal.rounded())
                }
                return 0
            }
            return 0
        }
    }
}

public class WrapPropertyOptionalInt: WrapProperty<Int?> {
    public init(_ keyPath: String, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: nil, serialize: serialize)
        self.toModelConverter = { (jsonValue:Any) -> Int? in
            if let dblVal = jsonValue as? Double {
                return Int(dblVal.rounded())
            } else if let intVal = jsonValue as? Int {
                return intVal
            } else if let strVal = jsonValue as? String {
                if let intVal =  Int(strVal) {
                    return intVal
                } else if let dblVal = Double(strVal) {
                    return Int(dblVal.rounded())
                }
                return nil
            }
            return nil
        }
    }
}

public class WrapPropertyDouble: WrapProperty<Double> {
    override public init(_ keyPath: String, defaultValue: Double = 0, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: defaultValue, serialize: serialize)
    }
}

public class WrapPropertyFloat: WrapProperty<Float> {
    // Must convert between Double and Float since fractional values in
    // JSON are treated as Doubles by the JSON decoder
    override public init(_ keyPath: String, defaultValue: Float = 0, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: defaultValue, serialize: serialize)
        self.toModelConverter = { (jsonValue:Any) -> Float in
            if let dblVal = jsonValue as? Double {
                return Float(dblVal)
            } else if let strVal = jsonValue as? String {
                return Float(strVal) ?? defaultValue
            } else if let intVal = jsonValue as? Int {
                return Float(intVal)
            }
            return 0.0
        }
        self.fromModelConverter = { (nativeValue:Float) -> Any? in
            return Double(nativeValue)
        }
    }
}

public class WrapPropertyNSNumberInt: WrapProperty<NSNumber?> {
    // Must convert between Double and Int since fractional values in
    // JSON are treated as Doubles by the JSON decoder
    public init(_ keyPath: String, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: nil, serialize: serialize)
        self.toModelConverter = { (jsonValue:Any) -> NSNumber? in
            if let dblVal = jsonValue as? Double {
                return NSNumber(value: dblVal)
            } else if let strVal = jsonValue as? String,
                let floatVal = Double(strVal) {
                return NSNumber(value: floatVal)
            }
            return nil
        }
        self.fromModelConverter = { (nativeValue:NSNumber?) -> Any? in
            return nativeValue?.intValue ?? nil
        }
    }
}

public class WrapPropertyNSNumberFloat: WrapProperty<NSNumber?> {
    public init(_ keyPath: String, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: nil, serialize: serialize)
        self.toModelConverter = { (jsonValue:Any) -> NSNumber? in
            if let dblVal = jsonValue as? Double {
                return NSNumber(value: dblVal)
            } else if let strVal = jsonValue as? String,
                let floatVal = Double(strVal) {
                return NSNumber(value: floatVal)
            }
            return nil
        }
        self.fromModelConverter = { (nativeValue:NSNumber?) -> Any? in
            return nativeValue?.doubleValue ?? nil
        }
    }
}

public class WrapPropertyString: WrapProperty<String> {
    override public init(_ keyPath: String, defaultValue: String = "", serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: defaultValue, serialize: serialize)
    }
}

public class WrapPropertyDict: WrapProperty<[String:Any]> {
    public init(_ keyPath: String, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: [:], serialize: serialize)
    }
}

public class WrapPropertyDate: WrapProperty<Date?> {
    static let formatterDibs: Formatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = WrapPropertyDate.dibsFormatStr
        return formatter
    }()
    
    static let formatterAlt: Formatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = WrapPropertyDate.altFormatStr
        return formatter
    }()
    
    static let formatterISO8601: Formatter = {
        return ISO8601DateFormatter()
    }()
    
    static let formatterSlashes: Formatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = WrapPropertyDate.slashesFormatStr
        return formatter
    }()
    
    static let formatterDashes: Formatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = WrapPropertyDate.dashesFormatStr
        return formatter
    }()
    
    static let formatterYYYYMMDD: Formatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = WrapPropertyDate.yyyymmddFormatStr
        return formatter
    }()
    
    static let dibsFormatStr = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"
    static let altFormatStr = "EEE MMM dd yyyy HH:mm:ss z"
    //static let iso8601FormatStr = "" <- no formatStr required
    static let slashesFormatStr = "yyyy/MM/dd"
    static let dashesFormatStr = "yyyy-MM-dd"
    static let yyyymmddFormatStr = "yyyyMMdd"

    public enum DateOutputType {
        case dibs               // 2017-02-05T17:03:13.000-03:00
        case secondary          // Tue Jun 3 2008 11:05:30 GMT
        case iso8601            // 2016-11-01T21:14:33Z
        case yyyymmddSlashes    // 2018/02/15
        case yyyymmddDashes     // 2018-02-15
        case yyyymmdd           // 20180215
        
        static func all() -> [DateOutputType] {
            // In the order we should try them
            return [
                .dibs,
                .secondary,
                .iso8601,
                .yyyymmddSlashes,
                .yyyymmddDashes,
                .yyyymmdd
            ]
        }
        
        func formatter() -> Formatter {
            switch self {
                case .dibs: return WrapPropertyDate.formatterDibs
                case .secondary: return WrapPropertyDate.formatterAlt
                case .iso8601: return WrapPropertyDate.formatterISO8601
                case .yyyymmddSlashes: return WrapPropertyDate.formatterSlashes
                case .yyyymmddDashes: return WrapPropertyDate.formatterDashes
                case .yyyymmdd: return WrapPropertyDate.formatterYYYYMMDD
            }
        }
        
        func string(from date: Date?) -> String? {
            guard let date = date else { return nil }
            return formatter().string(for: date)
        }
        
        func date(from string: String, fallbackToOtherFormats fallback: Bool) -> Date? {
            var returnDate:Date?
            if let dateFormatter = formatter() as? DateFormatter {
                returnDate = dateFormatter.date(from: string)
            } else if let isoFormatter = formatter() as? ISO8601DateFormatter {
                returnDate = isoFormatter.date(from: string)
            }
            if returnDate == nil && fallback {
                // Try other formatters
                for outputType in DateOutputType.all() {
                    if outputType == self { continue }
                    if let date = outputType.date(from: string, fallbackToOtherFormats: false) {
                        returnDate = date
                        break
                    }
                }
            }
            return returnDate
        }
    }
    
    public init(_ keyPath: String, dateType: DateOutputType, serialize: WrapPropertySerializationMode = .always) {
        super.init(keyPath, defaultValue: nil, serialize: serialize)
        self.toModelConverter = { (jsonValue:Any) -> Date? in
            if let strVal = jsonValue as? String {
                return dateType.date(from: strVal, fallbackToOtherFormats: true)
            } else if let dblVal = jsonValue as? Double {
                // Possibly an integer date like yyyymmdd
                let intVal = Int(dblVal)
                let minPossibleIntegerDate = 19000101 // Jan 1 1900
                let maxPossibleIntegerDate = 99991231 // Dec 31 9999 ;)
                if intVal >= minPossibleIntegerDate && intVal <= maxPossibleIntegerDate {
                    return DateOutputType.yyyymmdd.date(from: "\(intVal)", fallbackToOtherFormats: false)
                }
            }
            return nil
        }
        self.fromModelConverter = { (nativeValue:Date?) -> Any? in
            return dateType.string(from: nativeValue)
        }
    }
}



// Typealiases for common types and for brevity when defining properties
public typealias WP<T> = WrapProperty<T>
public typealias WPOpt<T> = WrapPropertyOptional<T>

// Basic types - nonoptional with default values
public typealias WPInt = WrapPropertyInt // def val 0
public typealias WPFloat = WrapPropertyFloat // def val 0.0
public typealias WPDouble = WrapPropertyDouble // def value 0.0
public typealias WPBool = WrapPropertyBool // def value false
public typealias WPOptBool = WrapPropertyOptionalBool // WPBoolean enum - def value .notSet

// Basic types - optional with default values
public typealias WPOptInt = WrapPropertyOptionalInt

// NSNumber types
public typealias WPNumInt = WrapPropertyNSNumberInt
public typealias WPNumFloat = WrapPropertyNSNumberFloat

// Integer encoded as string - nonoptional with default value of 0
public typealias WPIntStr = WrapPropertyIntFromString // def val 0

// Dictionaries and Strings - both optional and nonoptional with default values
public typealias WPDict = WrapPropertyDict // dict - def val [:]
public typealias WPStr = WrapPropertyString // string - def val ""
public typealias WPOptDict = WrapPropertyOptional<[String:Any]>
public typealias WPOptStr = WrapPropertyOptional<String>

// Enums encoded as string - provide enum class as template parameter (WPEnum<MyEnumType>)
public typealias WPEnum = WrapPropertyConvertibleEnum

// Property group - still defined by a submodel type
public typealias WPGroup = WrapPropertyGroup // specify model type - nonoptional

// Submodels - either alone or in an array or dictionary
public typealias WPModel = WrapPropertyModel // submodel - specify model type - always optional
public typealias WPModelArray = WrapPropertyArrayOfModel // array of model - specify model type - def value []
public typealias WPOptModelArray = WrapPropertyOptionalArrayOfModel // optional array of model - specify model type
public typealias WPModelDict = WrapPropertyDictionaryOfModel // dict in form [String:<model>]
public typealias WPOptModelDict = WrapPropertyOptionalDictionaryOfModel // optional dict in form [String:<model>]

// Dates - always optional
public typealias WPDate = WrapPropertyDate

// Arrays of basic types - optional or nonoptional with default value of empty array
public typealias WPIntArray = WrapPropertyArray<Int>
public typealias WPFloatArray = WrapPropertyArray<Float>
public typealias WPStrArray = WrapPropertyArray<String>
public typealias WPDictArray = WrapPropertyArray<[String:Any]>

public typealias WPOptIntArray = WrapPropertyOptionalArray<Int>
public typealias WPOptFloatArray = WrapPropertyOptionalArray<Float>
public typealias WPOptStrArray = WrapPropertyOptionalArray<String>
public typealias WPOptDictArray = WrapPropertyOptionalArray<[String:Any]>


public extension Dictionary where Value:Hashable {
    func inverted() -> [Value:Key] {
        var invDict = [Value:Key]()
        invDict.reserveCapacity(self.count)
        for (key, val) in self {
            invDict[val] = key
        }
        return invDict
    }
}
