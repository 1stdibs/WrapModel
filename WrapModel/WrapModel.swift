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
public let kWrapPropertySameDictionaryKey = "<same>"

// Used to demarcate the end of a keypath identifier that begins with kWrapPropertySameDictionaryKey
public let kWrapPropertySameDictionaryEndKey = "</same>"

@objcMembers
open class WrapModel : NSObject, NSCopying, NSMutableCopying, NSCoding {
    fileprivate let modelData:[String:Any]
    private(set) var originalJSON:String?
    private var properties = [AnyWrapProperty]()
    private lazy var sortedProperties: [AnyWrapProperty] = {
        // Pre-sort properties by length of key path so that when applying changes to the
        // data dictionary to produce a mutated copy, parent dictionaries are modified before
        // their children.
        properties.sort(by: { (p1, p2) -> Bool in
            let p1len = p1.keyPath.hasPrefix(kWrapPropertySameDictionaryKey) ? kWrapPropertySameDictionaryKey.count : p1.keyPath.count
            let p2len = p2.keyPath.hasPrefix(kWrapPropertySameDictionaryKey) ? kWrapPropertySameDictionaryKey.count : p2.keyPath.count
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
    public func currentModelData(withNulls:Bool, forOutput: Bool = false) -> [String:Any] {
        // Create a new data dictionary and put current property data into it
        var data = [String:Any].init(minimumCapacity: properties.count)
        
        func updateData(withProperty property: AnyWrapProperty) {
            if let pval = property.rawValue(withNulls: withNulls, forOutput: forOutput) {
                data.setValue(pval, forKeyPath: property.keyPath, createMissing: true)
            } else if withNulls {
                if !forOutput {
                    // Not for output - always emit value
                    data.setValue(NSNull(), forKeyPath: property.keyPath, createMissing: true)
                } else {
                    // For output to JSON - only emit value if property serializes for output
                    if property.serializeForOutput {
                        data.setValue(NSNull(), forKeyPath: property.keyPath, createMissing: true)
                    }
                }
            }
        }
        
        for property in sortedProperties {
            updateData(withProperty: property)
        }
        return data
    }
    // Note - .sortedKeys is iOS 11 or later only
    public let jsonOutputOptions: JSONSerialization.WritingOptions = [.prettyPrinted /*, .sortedKeys*/]
    public func currentModelDataAsJSON(withNulls:Bool) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: currentModelData(withNulls: withNulls, forOutput: true), options: jsonOutputOptions) else { return nil }
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
            model.lock.reading {
                self.cachedValues = model.cachedValues
            }
        }
    }
    
    //MARK: Cached property values
    
    // Keep cached/converted values for properties.
    private var contributedLock:WrapModelLock?
    private lazy var cacheLock:WrapModelLock = self.contributedLock ?? WrapModelLock()
    private lazy var cachedValues = [String:Any].init(minimumCapacity: self.properties.count)
    fileprivate func getCached(forProperty property:AnyWrapProperty) -> Any? {
        return lock.reading {
            return self.cachedValues[property.keyPath]
        }
    }
    fileprivate func setCached(value:Any?, forProperty property:AnyWrapProperty) {
        lock.writing {
            self.cachedValues[property.keyPath] = value
        }
    }
    fileprivate func clearCached(forProperty property:AnyWrapProperty) {
        lock.writing {
            self.cachedValues[property.keyPath] = nil
        }
    }

    public func clearMutations() {
        lock.writing {
            self.cachedValues = [String:Any]()
        }
    }
    
    public var lock: WrapModelLock {
        get {
            return self.cacheLock
        }
        set {
            self.contributedLock = newValue
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
        let myData = self.currentModelData(withNulls: false, forOutput: false)
        let theirData = model.currentModelData(withNulls: false, forOutput: false)
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
        lock.reading {
            theCopy.cachedValues = self.cachedValues
        }
        return theCopy
    }

    // Produce a mutable copy of the model in its current state
    public func mutableCopy(with zone: NSZone? = nil) -> Any {
        // Use a copy of the model's original data dictionary and copy any mutations
        // and already decoded values.
        let theCopy = type(of: self).init(data: self.originalModelData, mutable:true)
        lock.reading {
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
        if let dict = aDecoder.decodeObject(forKey: kNSCodingDataKey) as? [String:Any] {
            self.init(data: dict, mutable: mutable)
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
        if keys.count == 1, keyPath.hasPrefix(kWrapPropertySameDictionaryKey), let valueDict = value as? [String:Any] {
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
        if keys.count == 1 && keyPath.hasPrefix(kWrapPropertySameDictionaryKey) {
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
    // withNulls applies to submodels where properties are either omitted when missing (withNulls == false)
    // or replaced by an instance of NSNull (withNulls == true).
    func rawValue(withNulls:Bool, forOutput:Bool) -> Any?
    // Determines whether or not a property should be serialized for output to JSON
    var serializeForOutput: Bool { get }
}

private let trimCharSet = CharacterSet.init(charactersIn: "_")

open class WrapProperty<T> : AnyWrapProperty {
    public let keyPath: String
    public let defaultValue: T
    public weak var model:WrapModel!
    public let serializeForOutput: Bool

    // closure to convert JSON value to native model value - usually assigned by a subclass if necessary
    public var toModelConverter: ((_ jsonValue: Any) -> T)?
    
    // closure to convert native model value back to JSON value - assigned by subclass if necessary
    public var fromModelConverter: ((_ nativeValue: T) -> Any?)?
    
    public init(_ keyPath: String, defaultValue: T, serializeForOutput: Bool = true) {
        self.keyPath = keyPath.trimmingCharacters(in: trimCharSet)
        self.defaultValue = defaultValue
        self.serializeForOutput = serializeForOutput
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

    // Note submodel properties will need to override to obey withNulls and forOutput
    public func rawValue(withNulls: Bool, forOutput: Bool) -> Any? {
        if forOutput && !self.serializeForOutput {
            return nil
        }
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
    public init(_ keyPath: String, defaultEnum: T, conversionDict: [String:T], serializeForOutput: Bool = true) {
        self.conversionDict = conversionDict
        var reversed = [Int:String]()
        reversed.reserveCapacity(conversionDict.count)
        conversionDict.forEach { (keyString:String, value:T) in
            reversed[value.rawValue] = keyString
        }
        self.reverseDict = reversed
        super.init(keyPath,
                   defaultValue: defaultEnum,
                   serializeForOutput: serializeForOutput)
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
        return rawValue(withNulls: false, forOutput: false) as? String
    }
}

public class WrapPropertyConvertibleEnum<T:WrapConvertibleEnum> : WrapPropertyEnum<T> {
    public init(_ keyPath: String, defaultEnum: T, serializeForOutput: Bool = true) {
        super.init(keyPath,
                   defaultEnum: defaultEnum,
                   conversionDict: T.conversionDict(), serializeForOutput: serializeForOutput)
    }
}

public class WrapPropertyOptional<DataClass:Any>: WrapProperty<DataClass?> {
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: nil, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> DataClass? in
            return jsonValue as? DataClass
        }
        self.fromModelConverter = { (nativeValue:DataClass?) -> Any? in
            return nativeValue
        }
    }
}

public class WrapPropertyModel<ModelClass>: WrapProperty<ModelClass?> where ModelClass:WrapModel {
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: nil, serializeForOutput: serializeForOutput)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> ModelClass? in
            guard let dictValue = jsonValue as? [String:Any] else { return nil }
            // Copy mutable status of parent model
            let aModel = ModelClass.init(data: dictValue, mutable: self?.model.isMutable ?? false)
            if let lock = self?.model.lock {
                // Share parent model's data lock with child model
                aModel.lock = lock
            }
            return aModel
        }
        self.fromModelConverter = { (nativeValue:ModelClass?) -> Any? in
            return nativeValue?.currentModelData(withNulls:false, forOutput: false)
        }
    }
    override public func rawValue(withNulls: Bool, forOutput: Bool) -> Any? {
        return self.value?.currentModelData(withNulls: withNulls, forOutput: forOutput)
    }
}

public class WrapPropertyGroup<ModelClass:WrapModel>: WrapProperty<ModelClass> {
    public init() {
        // A default value that will never be used
        let dummy = ModelClass.init(data: [:], mutable: false)
        let groupKeyPath = kWrapPropertySameDictionaryKey + UUID().uuidString + kWrapPropertySameDictionaryEndKey
        super.init(groupKeyPath, defaultValue: dummy, serializeForOutput: true)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> ModelClass in
            let dictValue = jsonValue as? [String:Any] ?? [String:Any]()
            // Copy mutable status of parent model
            let aModel = ModelClass.init(data: dictValue, mutable: self?.model.isMutable ?? false)
            if let lock = self?.model.lock {
                // Share parent model's data lock with child model
                aModel.lock = lock
            }
            return aModel
        }
        self.fromModelConverter = { (nativeValue:ModelClass) -> Any? in
            return nativeValue.currentModelData(withNulls:false, forOutput: false)
        }
    }
    override public func rawValue(withNulls: Bool, forOutput: Bool) -> Any? {
        return self.value.currentModelData(withNulls: withNulls, forOutput: forOutput)
    }
}

public class WrapPropertyArray<ElementClass:Any>: WrapProperty<[ElementClass]> {
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: [], serializeForOutput: serializeForOutput)
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

public class WrapPropertyArrayOfModel<ModelClass>: WrapProperty<[ModelClass]> where ModelClass:WrapModel {
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: [], serializeForOutput: serializeForOutput)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> [ModelClass] in
            guard let dictArray = jsonValue as? [[String:Any]] else { return [] }
            // Copy mutable status of parent model
            let modelArray:[ModelClass] = dictArray.map {
                let aModel = ModelClass.init(data:$0, mutable:self?.model.isMutable ?? false)
                if let lock = self?.model.lock {
                    // Share parent model's data lock with child model
                    aModel.lock = lock
                }
                return aModel
            }
            return modelArray
        }
        self.fromModelConverter = { (nativeValue:[ModelClass]) -> Any? in
            return nativeValue.map { return $0.currentModelData(withNulls:false, forOutput: false) }
        }
    }
    override public func rawValue(withNulls: Bool, forOutput: Bool) -> Any? {
        return self.value.map { $0.currentModelData(withNulls: withNulls, forOutput: forOutput) }
    }
}

public class WrapPropertyOptionalArrayOfModel<ModelClass>: WrapProperty<[ModelClass]?> where ModelClass:WrapModel {
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: nil, serializeForOutput: serializeForOutput)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> [ModelClass]? in
            guard let dictArray = jsonValue as? [[String:Any]] else { return nil }
            // Copy mutable status of parent model
            let modelArray:[ModelClass] = dictArray.map {
                let aModel = ModelClass.init(data:$0, mutable:self?.model.isMutable ?? false)
                if let lock = self?.model.lock {
                    // Share parent model's data lock with child model
                    aModel.lock = lock
                }
                return aModel
            }
            return modelArray
        }
        self.fromModelConverter = { (nativeValue:[ModelClass]?) -> Any? in
            guard let modelArray = nativeValue else { return nil }
            return modelArray.map { return $0.currentModelData(withNulls:false, forOutput: false) }
        }
    }
    override public func rawValue(withNulls: Bool, forOutput: Bool) -> Any? {
        return self.value?.map { $0.currentModelData(withNulls: withNulls, forOutput: forOutput) }
    }
}

public class WrapPropertyDictionaryOfModel<ModelClass>: WrapProperty<[String:ModelClass]> where ModelClass:WrapModel {
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: [:], serializeForOutput: serializeForOutput)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> [String:ModelClass] in
            guard let dict = jsonValue as? [String:[String:Any]] else { return [:] }
            // Copy mutable status of parent model
            var modelDict = [String:ModelClass]()
            modelDict.reserveCapacity(dict.count)
            for (key,value) in dict {
                let aModel = ModelClass.init(data:value, mutable:self?.model.isMutable ?? false)
                if let lock = self?.model.lock {
                    // Share parent model's data lock with child model
                    aModel.lock = lock
                }
                modelDict[key] = aModel
            }
            return modelDict
        }
        self.fromModelConverter = { (nativeValue:[String:ModelClass]) -> Any? in
            var rawDict = [String:Any]()
            rawDict.reserveCapacity(nativeValue.count)
            for (key,value) in nativeValue {
                rawDict[key] = value.currentModelData(withNulls:false, forOutput: false)
            }
            return rawDict
        }
    }
    override public func rawValue(withNulls: Bool, forOutput: Bool) -> Any? {
        var mdict = [String:Any]()
        for (k, m) in self.value {
            mdict[k] = m.currentModelData(withNulls: withNulls, forOutput: forOutput)
        }
        return mdict
    }
}

public class WrapPropertyOptionalDictionaryOfModel<ModelClass>: WrapProperty<[String:ModelClass]?> where ModelClass:WrapModel {
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: nil, serializeForOutput: serializeForOutput)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> [String:ModelClass]? in
            guard let dict = jsonValue as? [String:[String:Any]] else { return nil }
            // Copy mutable status of parent model
            var modelDict = [String:ModelClass]()
            modelDict.reserveCapacity(dict.count)
            for (key,value) in dict {
                let aModel = ModelClass.init(data:value, mutable:self?.model.isMutable ?? false)
                if let lock = self?.model.lock {
                    // Share parent model's data lock with child model
                    aModel.lock = lock
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
                rawDict[key] = value.currentModelData(withNulls:false, forOutput: false)
            }
            return rawDict
        }
    }
    override public func rawValue(withNulls: Bool, forOutput: Bool) -> Any? {
        guard let val = self.value else { return nil }
        var mdict = [String:Any]()
        for (k, m) in val {
            mdict[k] = m.currentModelData(withNulls: withNulls, forOutput: forOutput)
        }
        return mdict
    }
}

public class WrapPropertyIntFromString: WrapProperty<Int> {
    override public init(_ keyPath: String, defaultValue: Int = 0, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
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

public class WrapPropertyOptionalIntFromString: WrapPropertyOptional<Int> {
    override public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> Int? in
            if let strVal = jsonValue as? String {
                if let intVal =  Int(strVal) {
                    return intVal
                } else if let dblVal = Double(strVal) {
                    return Int(dblVal.rounded())
                }
                return 0
            } else if let intVal = jsonValue as? Int {
                return intVal
            } else if let dblVal = jsonValue as? Double {
                return Int(dblVal.rounded())
            }
            return nil
        }
        self.fromModelConverter = {(nativeValue:Int?) -> Any? in
            if let nativeInt = nativeValue {
                return "\(nativeInt)"
            }
            return nil
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

fileprivate extension String {
    func isTrueString() -> Bool {
        if let firstChar = self.first {
            return "tTyY1".contains(firstChar)
        }
        return false
    }
}

public class WrapPropertyBool: WrapProperty<Bool> {
    public init(_ keyPath: String, boolType: WrapPropertyBoolOutputType = .boolean, defaultValue: Bool = false, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> Bool in
            if let boolVal = jsonValue as? Bool {
                return boolVal
            } else if let strVal = jsonValue as? String {
                return strVal.isTrueString()
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

fileprivate func intFromAny(_ val:Any) -> Int? {
    if let dblVal = val as? Double {
        return Int(dblVal.rounded())
    } else if let intVal = val as? Int {
        return intVal
    } else if let strVal = val as? String {
        if let intVal =  Int(strVal) {
            return intVal
        } else if let dblVal = Double(strVal) {
            return Int(dblVal.rounded())
        }
    }
    return nil
}

fileprivate func floatFromAny(_ val:Any) -> Float? {
    if let dblVal = val as? Double {
        return Float(dblVal)
    } else if let strVal = val as? String {
        return Float(strVal)
    } else if let intVal = val as? Int {
        return Float(intVal)
    }
    return nil
}

fileprivate func doubleFromAny(_ val:Any) -> Double? {
    if let dblVal = val as? Double {
        return dblVal
    } else if let strVal = val as? String {
        return Double(strVal)
    } else if let intVal = val as? Int {
        return Double(intVal)
    }
    return nil
}

public class WrapPropertyInt: WrapProperty<Int> {
    override public init(_ keyPath: String, defaultValue: Int = 0, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> Int in
            return intFromAny(jsonValue) ?? 0
        }
    }
}

public class WrapPropertyOptionalInt: WrapPropertyOptional<Int> {
    override public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> Int? in
            return intFromAny(jsonValue)
        }
    }
}

public class WrapPropertyIntArray: WrapPropertyArray<Int> {
    override public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> [Int] in
            guard let array = jsonValue as? [Any] else { return [] }
            return array.compactMap { intFromAny($0) }
        }
    }
}

public class WrapPropertyOptionalIntArray: WrapPropertyOptionalArray<Int> {
    override public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> [Int]? in
            guard let array = jsonValue as? [Any] else { return nil }
            return array.compactMap { intFromAny($0) }
        }
    }
}

public class WrapPropertyDouble: WrapProperty<Double> {
    override public init(_ keyPath: String, defaultValue: Double = 0, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
    }
}

public class WrapPropertyFloat: WrapProperty<Float> {
    // Must convert between Double and Float since fractional values in
    // JSON are treated as Doubles by the JSON decoder
    override public init(_ keyPath: String, defaultValue: Float = 0, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> Float in
            return floatFromAny(jsonValue) ?? 0.0
        }
        self.fromModelConverter = { (nativeValue:Float) -> Any? in
            return Double(nativeValue)
        }
    }
}

public class WrapPropertyFloatArray: WrapPropertyArray<Float> {
    override public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> [Float] in
            guard let array = jsonValue as? [Any] else { return [] }
            return array.compactMap { floatFromAny($0) }
        }
    }
}

public class WrapPropertyOptionalFloatArray: WrapPropertyOptionalArray<Float> {
    override public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> [Float]? in
            guard let array = jsonValue as? [Any] else { return nil }
            return array.compactMap { floatFromAny($0) }
        }
    }
}

public class WrapPropertyNSNumberInt: WrapProperty<NSNumber?> {
    // Must convert between Double and Int since fractional values in
    // JSON are treated as Doubles by the JSON decoder
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: nil, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> NSNumber? in
            if let intVal = intFromAny(jsonValue) {
                return NSNumber(value: intVal)
            }
            return nil
        }
        self.fromModelConverter = { (nativeValue:NSNumber?) -> Any? in
            return nativeValue?.intValue ?? nil
        }
    }
}

public class WrapPropertyNSNumberFloat: WrapProperty<NSNumber?> {
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: nil, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> NSNumber? in
            if let dblVal = doubleFromAny(jsonValue) {
                return NSNumber(value: dblVal)
            }
            return nil
        }
        self.fromModelConverter = { (nativeValue:NSNumber?) -> Any? in
            return nativeValue?.doubleValue ?? nil
        }
    }
}

public class WrapPropertyString: WrapProperty<String> {
    override public init(_ keyPath: String, defaultValue: String = "", serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
    }
}

public class WrapPropertyDict: WrapProperty<[String:Any]> {
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: [:], serializeForOutput: serializeForOutput)
    }
}

public class WrapPropertyDate: WrapProperty<Date?> {
    
    @objc(WrapPropertyDateOutputType)
    public enum DateOutputType: Int, CaseIterable {
        // Should be defined in the order that they should be tried when decoding JSON value
        case dibs               // 2017-02-05T17:03:13.000-03:00
        case secondary          // Tue Jun 3 2008 11:05:30 GMT
        case iso8601            // 2016-11-01T21:14:33Z
        case yyyymmddSlashes    // 2018/02/15
        case yyyymmddDashes     // 2018-02-15
        case yyyymmdd           // 20180215
        case mdySlashesFormatStr // 05/06/2018
        case mdyDashesFormatStr  // 05-06-2018
        case dmySlashesFormatStr // 30/02/2017
        case dmyDashesFormatStr  // 30-02-2017

        static fileprivate let formatterISO8601: Formatter = {
            return ISO8601DateFormatter()
        }()
        static fileprivate let ios8601FormatStr = "iso8601"
        
        static fileprivate let formatsByType: [DateOutputType:String] = [
            DateOutputType.dibs: "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
            DateOutputType.secondary: "EEE MMM dd yyyy HH:mm:ss z",
            DateOutputType.iso8601: "iso8601",
            DateOutputType.yyyymmddSlashes: "yyyy/MM/dd",
            DateOutputType.yyyymmddDashes: "yyyy-MM-dd",
            DateOutputType.yyyymmdd: "yyyyMMdd",
            DateOutputType.mdySlashesFormatStr: "MM/dd/yyyy",
            DateOutputType.mdyDashesFormatStr: "MM-dd-yyyy",
            DateOutputType.dmySlashesFormatStr: "dd/MM/yyyy",
            DateOutputType.dmyDashesFormatStr: "dd-MM-yyyy"
        ]
        
        func formatString() -> String {
            assert(DateOutputType.formatsByType[self] != nil)
            return DateOutputType.formatsByType[self] ?? DateOutputType.formatsByType[DateOutputType.iso8601]!
        }
        
        private static var formatters = [String:Formatter]()
        
        func formatter() -> Formatter {
            let fs = self.formatString()
            if let f = DateOutputType.formatters[fs] {
                return f
            }
            
            // Special case ISO 8601
            if fs == DateOutputType.ios8601FormatStr {
                let isoFormatter = DateOutputType.formatterISO8601
                DateOutputType.formatters[fs] = isoFormatter
                return isoFormatter
            }
            
            let newFormatter = DateFormatter()
            newFormatter.locale = Locale(identifier: "en_US_POSIX")
            newFormatter.dateFormat = fs
            DateOutputType.formatters[fs] = newFormatter
            
            return newFormatter
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
                for outputType in DateOutputType.allCases {
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
    
    public init(_ keyPath: String, dateType: DateOutputType, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: nil, serializeForOutput: serializeForOutput)
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

// Basic types - optional with default values
public typealias WPOptInt = WrapPropertyOptionalInt

// NSNumber types
public typealias WPNumInt = WrapPropertyNSNumberInt
public typealias WPNumFloat = WrapPropertyNSNumberFloat

// Integer encoded as string
public typealias WPIntStr = WrapPropertyIntFromString // def val 0
public typealias WPOptIntStr = WrapPropertyOptionalIntFromString // optional

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
public typealias WPIntArray = WrapPropertyIntArray
public typealias WPFloatArray = WrapPropertyFloatArray
public typealias WPDoubleArray = WrapPropertyArray<Double>
public typealias WPStrArray = WrapPropertyArray<String>
public typealias WPDictArray = WrapPropertyArray<[String:Any]>

public typealias WPOptIntArray = WrapPropertyOptionalIntArray
public typealias WPOptFloatArray = WrapPropertyOptionalFloatArray
public typealias WPOptDoubleArray = WrapPropertyOptionalArray<Double>
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
