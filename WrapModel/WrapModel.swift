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

// MARK: WrapModel

@objcMembers
open class WrapModel : NSObject, NSCopying, NSMutableCopying, NSCoding {
    fileprivate let modelData:[String:Any]
    private(set) var originalJSON:String?
    private var properties = [AnyWrapProperty]()
    private lazy var sortedProperties: [AnyWrapProperty] = {
        // Pre-sort properties by length of key path so that when applying changes to the
        // data dictionary to produce a mutated copy, parent dictionaries are modified before
        // their children.
        let sorted = properties.sorted(by: { (p1, p2) -> Bool in
            let p1len = p1.keyPath.hasPrefix(kWrapPropertySameDictionaryKey) ? kWrapPropertySameDictionaryKey.count : p1.keyPath.count
            let p2len = p2.keyPath.hasPrefix(kWrapPropertySameDictionaryKey) ? kWrapPropertySameDictionaryKey.count : p2.keyPath.count
            return p1len < p2len
        })
        return sorted
    }()
    
    public let isMutable:Bool
    public var originalModelData: [String:Any] {
        return modelData
    }
    open var originalModelDataAsJSON: String? {
        guard let data = try? JSONSerialization.data(withJSONObject: originalModelData, options: [.prettyPrinted]) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    open func currentModelData(withNulls:Bool, forOutput: Bool = false) -> [String:Any] {
        // Create a new data dictionary and put current property data into it
        var data = [String:Any].init(minimumCapacity: properties.count)
        
        for property in sortedProperties {
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
        
        return data
    }
    // Note - .sortedKeys is iOS 11 or later only
    public let jsonOutputOptions: JSONSerialization.WritingOptions = [.prettyPrinted /*, .sortedKeys*/]
    open func currentModelDataAsJSON(withNulls:Bool) -> String? {
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
        properties = mirror.allChildren().compactMap { (prop) -> AnyWrapProperty? in
            switch prop.value {
            case let optionalObj as Optional<Any>:
                switch optionalObj {
                case .some(let innerObj):
                    if let wrapProp = innerObj as? AnyWrapProperty {
                        return wrapProp
                    }
                    #if swift(>=5.1)
                    if let wrapPropProvider = innerObj as? AnyWrapPropertyProvider {
                        return wrapPropProvider.property()
                    }
                    #endif
                case .none:
                    return nil
                }
            }
            return nil
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
        if withMutations {
            if model.isMutable {
                if mutable {
                    // Mutable -> mutable. Initialize from the source model's original dictionary and
                    // copy all cached/mutated data.
                    self.init(data:model.originalModelData, mutable:mutable)
                    model.lock.reading {
                        self.cachedValues = model.cachedValues
                    }
                } else {
                    // Creating an immutable model from a mutable model with possible mutations.
                    // Generate a new data dictionary from the source model's current state and
                    // use that as the source data for the new immutable model.
                    self.init(data: model.currentModelData(withNulls: false, forOutput: false), mutable: mutable)
                }
            } else {
                // Source model is immutable, so initialize from its original data.
                self.init(data: model.originalModelData, mutable: mutable)
            }
        } else {
            // Doesn't include any mutations, so initialize with the source model's original data.
            self.init(data: model.originalModelData, mutable: mutable)
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

    //MARK: Comparable
    
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
    
    static public func == (lhs: WrapModel, rhs: WrapModel) -> Bool {
        return lhs.isEqualToModel(model: rhs)
    }

    //MARK: NSCopying
    
    // Produce an immutable copy of model in its current state
    open func copy(with zone: NSZone? = nil) -> Any {
        // If the object is immutable, don't actually copy - just return this instance
        if (!isMutable) {
            return self
        }
        // Generate a current data dictionary and initialize a new model from that.
        // Cannot copy cached values since the mutable status of submodels in the cache
        // differs from the mutable status of the copy.
        let curData = self.currentModelData(withNulls: false, forOutput: false)
        let theCopy = type(of: self).init(data: curData, mutable:false)
        return theCopy
    }

    // Produce a mutable copy of the model in its current state
    open func mutableCopy(with zone: NSZone? = nil) -> Any {
        if self.isMutable {
            // Use a copy of the model's original data dictionary and copy any mutations
            // and already decoded values.
            let theCopy = type(of: self).init(data: self.originalModelData, mutable:true)
            lock.reading {
                theCopy.cachedValues = self.cachedValues
            }
            return theCopy
        } else {
            // Source model is immutable, so initialize copy from original data.
            let theCopy = type(of: self).init(data: self.originalModelData, mutable:true)
            return theCopy
        }
    }
    
    //MARK: NSCoding
    
    open func encode(with aCoder: NSCoder) {
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
    
    //MARK: CustomDebugStringConvertible
    
    override open var debugDescription: String {
        return description
    }

    //MARK: CustomStringConvertible

    override open var description: String {
        var desc = "Model \(type(of:self)) - \(super.description) mutable: \(isMutable) \n"
        let json = currentModelDataAsJSON(withNulls: true) ?? "{}"
        desc.append(json)
        return desc
    }
}

// MARK: -

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

// MARK: AnyWrapProperty protocol

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

// MARK: WrapProperty parent class

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
    open func rawValue(withNulls: Bool, forOutput: Bool) -> Any? {
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
    func stringValue() -> String? {
        return type(of: self).stringValue(from: self)
    }
    static func stringValue(from:Self) -> String? {
        return conversionDict().inverted()[from]
    }
    var hashValue:Int {
        return rawValue.hashValue
    }
}

// MARK: General Property Wrapper support
// See later in file for specific property type wrappers. These are for generic support using any WrapProperty class.

#if swift(>=5.1)
@propertyWrapper
public struct ROProperty<T> {
    let wrapProperty: WrapProperty<T>
    let getModifier: (T)->T
    public var wrappedValue: T {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ property:WrapProperty<T>, modifier: @escaping (T)->T = { $0 } ) {
        self.wrapProperty = property
        self.getModifier = modifier
    }
}
@propertyWrapper
public struct RWProperty<T> {
    let wrapProperty: WrapProperty<T>
    let getModifier: (T)->T
    let setModifier: (T)->T
    public var wrappedValue: T {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ property:WrapProperty<T>, getModifier: @escaping (T)->T = { $0 }, setModifier: @escaping (T)->T = { $0 }) {
        self.wrapProperty = property
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
public protocol AnyWrapPropertyProvider {
    func property() -> AnyWrapProperty
}
extension ROProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}
extension RWProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}
#endif


// MARK: WrapPropertyEnum

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

// MARK: WrapPropertyConvertibleEnum

public class WrapPropertyConvertibleEnum<T:WrapConvertibleEnum> : WrapPropertyEnum<T> {
    public init(_ keyPath: String, defaultEnum: T, serializeForOutput: Bool = true) {
        super.init(keyPath,
                   defaultEnum: defaultEnum,
                   conversionDict: T.conversionDict(), serializeForOutput: serializeForOutput)
    }
}

// MARK: WrapPropertyOptionalEnum

// For use with Enum types with Int raw value type represented by a String in the
// data dictionary.
public class WrapPropertyOptionalEnum<T:RawRepresentable> : WrapPropertyOptional<T> where T.RawValue == Int {
    let conversionDict: [String:T]
    private let reverseDict: [Int:String]
    public init(_ keyPath: String, conversionDict: [String:T], serializeForOutput: Bool = true) {
        self.conversionDict = conversionDict
        var reversed = [Int:String]()
        reversed.reserveCapacity(conversionDict.count)
        conversionDict.forEach { (keyString:String, value:T) in
            reversed[value.rawValue] = keyString
        }
        self.reverseDict = reversed
        super.init(keyPath,
                   serializeForOutput: serializeForOutput)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> T? in
            guard let strongSelf = self,
                let strValue = jsonValue as? String else { return nil }
            if let converted = strongSelf.conversionDict[strValue] {
                return converted
            }
            return nil
        }
        self.fromModelConverter = { [weak self] (nativeValue:T?) -> Any? in
            guard let strongSelf = self,
                let nativeValue = nativeValue else { return nil }
            return strongSelf.reverseDict[nativeValue.rawValue]
        }
    }
    
    public func asString() -> String? {
        return rawValue(withNulls: false, forOutput: false) as? String
    }
}

// MARK: WrapPropertyConvertibleOptionalEnum

public class WrapPropertyConvertibleOptionalEnum<T:WrapConvertibleEnum> : WrapPropertyOptionalEnum<T> {
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath,
                   conversionDict: T.conversionDict(), serializeForOutput: serializeForOutput)
    }
}

// MARK: WrapPropertyOptional

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

// MARK: WrapPropertyModel

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
        guard !forOutput || self.serializeForOutput else { return nil }
        return self.value?.currentModelData(withNulls: withNulls, forOutput: forOutput)
    }
}

// MARK: WrapPropertyGroup

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
        guard !forOutput || self.serializeForOutput else { return nil }
        return self.value.currentModelData(withNulls: withNulls, forOutput: forOutput)
    }
}

// MARK: WrapPropertyArray

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

// MARK: WrapPropertyOptionalArray

public class WrapPropertyOptionalArray<ElementClass:Any>: WrapPropertyOptional<[ElementClass]> {
}

// MARK: WrapPropertyArrayOfModel

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
        guard !forOutput || self.serializeForOutput else { return nil }
        return self.value.map { $0.currentModelData(withNulls: withNulls, forOutput: forOutput) }
    }
}

// MARK: WrapPropertyOptionalArrayOfModel

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
        guard !forOutput || self.serializeForOutput else { return nil }
        return self.value?.map { $0.currentModelData(withNulls: withNulls, forOutput: forOutput) }
    }
}

// MARK: Array of embedded models

/// A property representing an array of models where each model is embedded in one or more levels of
/// dictionaries. Specify an embedPath to drill down to the actual model dictionary.
/// Example:
/// {
///   "edges": [
///     {
///       "node": {
///         "item": {
///           "actualModelFieldsHere": "value"
///         }
///       }
///     }
///   ]
/// }
/// WrapModel property would be declared like this:
///   private let _models = FDEmbedArray<MyModelClass>("edges", embedPath: "node.item")
///   var models:[MyModelClass] { return _models.value }
///
public class WrapPropertyArrayOfEmbeddedModel<ModelClass>: WrapProperty<[ModelClass]> where ModelClass:WrapModel {
    let embedKeys:[String]
    public init(_ keyPath: String, embedPath:String? = nil, serializeForOutput: Bool = true) {
        self.embedKeys = (embedPath?.split(separator: ".") ?? []).map { String($0) }
        super.init(keyPath, defaultValue: [], serializeForOutput: serializeForOutput)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> [ModelClass] in
            guard let dicts = jsonValue as? [[String: Any]], let self = self else { return [] }
            // Embedding key path
            return dicts.compactMap { (dict) -> ModelClass? in
                if self.embedKeys.isEmpty {
                    // not really embedded
                    return ModelClass.init(data:dict, mutable:self.model.isMutable)
                }
                // Dig into the actual model dictionary
                let modelDict = self.embedKeys.reduce(dict) { (dict:[String:Any]?, key) -> [String:Any]? in
                    dict?[key] as? [String:Any]
                }
                if let dict = modelDict {
                    return ModelClass.init(data:dict, mutable:self.model.isMutable)
                }
                return nil
            }
        }
        self.fromModelConverter = { [weak self] (nativeValue:[ModelClass]) -> Any? in
            // Embedding key path in reverse order
            guard let embedKeys = self?.embedKeys.reversed() else { return nil }
            return nativeValue.compactMap { (model) -> [String: Any]? in
                let modelDict = model.currentModelData(withNulls: false, forOutput: false)
                if embedKeys.isEmpty {
                    // not really embedded
                    return modelDict
                }
                // Embed dictionary in layers of dictionaries
                return embedKeys.reduce(modelDict) { (dict:[String:Any], key) -> [String:Any] in
                    return [key:dict]
                }
            }
        }
    }
    override public func rawValue(withNulls: Bool, forOutput: Bool) -> Any? {
        // Embedding key path in reverse order
        let embedKeys = self.embedKeys.reversed()
        let dictArray:[Any] = self.value.compactMap { (model) -> [String: Any]? in
            let modelDict = model.currentModelData(withNulls: withNulls, forOutput: forOutput)
            if embedKeys.isEmpty {
                // not really embedded
                return modelDict
            }
            // Embed dictionary in layers of dictionaries
            return embedKeys.reduce(modelDict) { (dict:[String:Any], key) -> [String:Any] in
                return [key:dict]
            }
        }
        return dictArray
    }
}

public class WrapPropertyOptionalArrayOfEmbeddedModel<ModelClass>: WrapProperty<[ModelClass]?> where ModelClass:WrapModel {
    let embedKeys:[String]
    public init(_ keyPath: String, embedPath:String? = nil, serializeForOutput: Bool = true) {
        self.embedKeys = (embedPath?.split(separator: ".") ?? []).map { String($0) }
        super.init(keyPath, defaultValue: [], serializeForOutput: serializeForOutput)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> [ModelClass] in
            guard let dicts = jsonValue as? [[String: Any]], let self = self else { return [] }
            // Embedding key path
            return dicts.compactMap { (dict) -> ModelClass? in
                if self.embedKeys.isEmpty {
                    // not really embedded
                    return ModelClass.init(data:dict, mutable:self.model.isMutable)
                }
                // Dig into the actual model dictionary
                let modelDict = self.embedKeys.reduce(dict) { (dict:[String:Any]?, key) -> [String:Any]? in
                    dict?[key] as? [String:Any]
                }
                if let dict = modelDict {
                    return ModelClass.init(data:dict, mutable:self.model.isMutable)
                }
                return nil
            }
        }
        self.fromModelConverter = { [weak self] (nativeValue:[ModelClass]?) -> Any? in
            // Embedding key path in reverse order
            guard let embedKeys = self?.embedKeys.reversed() else { return nil }
            return nativeValue?.compactMap { (model) -> [String: Any]? in
                let modelDict = model.currentModelData(withNulls: false, forOutput: false)
                if embedKeys.isEmpty {
                    // not really embedded
                    return modelDict
                }
                // Embed dictionary in layers of dictionaries
                return embedKeys.reduce(modelDict) { (dict:[String:Any], key) -> [String:Any] in
                    return [key:dict]
                }
            }
        }
    }
    override public func rawValue(withNulls: Bool, forOutput: Bool) -> Any? {
        guard let val = self.value else { return nil }
        // Embedding key path in reverse order
        let embedKeys = self.embedKeys.reversed()
        let dictArray:[Any] = val.compactMap { (model) -> [String: Any]? in
            let modelDict = model.currentModelData(withNulls: withNulls, forOutput: forOutput)
            if embedKeys.isEmpty {
                // not really embedded
                return modelDict
            }
            // Embed dictionary in layers of dictionaries
            return embedKeys.reduce(modelDict) { (dict:[String:Any], key) -> [String:Any] in
                return [key:dict]
            }
        }
        return dictArray
    }
}

// MARK: WrapPropertyDictionaryOfModel

public class WrapPropertyDictionaryOfModel<ModelClass>: WrapProperty<[String:ModelClass]> where ModelClass:WrapModel {
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: [:], serializeForOutput: serializeForOutput)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> [String:ModelClass] in
            // Type check
            guard let jsonDict = jsonValue as? [String:Any] else { return [:] }
            var dict = [String:[String:Any]]()
            for (key,val) in jsonDict {
                if let dictVal = val as? [String:Any] {
                    dict[key] = dictVal
                }
            }
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
        guard !forOutput || self.serializeForOutput else { return nil }
        var mdict = [String:Any]()
        for (k, m) in self.value {
            mdict[k] = m.currentModelData(withNulls: withNulls, forOutput: forOutput)
        }
        return mdict
    }
}

// MARK: WrapPropertyOptionalDictionaryOfModel

public class WrapPropertyOptionalDictionaryOfModel<ModelClass>: WrapProperty<[String:ModelClass]?> where ModelClass:WrapModel {
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: nil, serializeForOutput: serializeForOutput)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> [String:ModelClass]? in
            // Type check
            guard let jsonDict = jsonValue as? [String:Any] else { return nil }
            var dict = [String:[String:Any]]()
            for (key,val) in jsonDict {
                if let dictVal = val as? [String:Any] {
                    dict[key] = dictVal
                }
            }
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
        guard !forOutput || self.serializeForOutput else { return nil }
        guard let val = self.value else { return nil }
        var mdict = [String:Any]()
        for (k, m) in val {
            mdict[k] = m.currentModelData(withNulls: withNulls, forOutput: forOutput)
        }
        return mdict
    }
}

// MARK: WrapPropertyDictionaryOfArrayOfModel

public class WrapPropertyDictionaryOfArrayOfModel<ModelClass>: WrapProperty<[String:[ModelClass]]> where ModelClass:WrapModel {
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: [:], serializeForOutput: serializeForOutput)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> [String:[ModelClass]] in
            // Type check
            guard let jsonDict = jsonValue as? [String:Any] else { return [:] }
            var dict = [String:[[String:Any]]]()
            for (key,val) in jsonDict {
                if let dictVal = val as? [[String:Any]] {
                    dict[key] = dictVal
                }
            }
            // Copy mutable status of parent model
            var modelDict = [String:[ModelClass]]()
            modelDict.reserveCapacity(dict.count)
            for (key,value) in dict {
                // Copy mutable status of parent model
                let modelArray:[ModelClass] = value.map {
                    let aModel = ModelClass.init(data:$0, mutable:self?.model.isMutable ?? false)
                    if let lock = self?.model.lock {
                        // Share parent model's data lock with child model
                        aModel.lock = lock
                    }
                    return aModel
                }
                modelDict[key] = modelArray
            }
            return modelDict
        }
        self.fromModelConverter = { (nativeValue:[String:[ModelClass]]?) -> Any? in
            guard let modelDict = nativeValue else { return nil }
            var rawDict = [String:Any]()
            rawDict.reserveCapacity(modelDict.count)
            for (key,value) in modelDict {
                let dictArray:[[String:Any]] = value.map { $0.currentModelData(withNulls: false, forOutput: false) }
                rawDict[key] = dictArray
            }
            return rawDict
        }
    }
    override public func rawValue(withNulls: Bool, forOutput: Bool) -> Any? {
        guard !forOutput || self.serializeForOutput else { return nil }
        var mdict = [String:Any]()
        for (k, v) in self.value {
            let dictArray:[[String:Any]] = v.map { $0.currentModelData(withNulls: withNulls, forOutput: forOutput) }
            mdict[k] = dictArray
        }
        return mdict
    }
}

// MARK: WrapPropertyOptionalDictionaryOfArrayOfModel

public class WrapPropertyOptionalDictionaryOfArrayOfModel<ModelClass>: WrapProperty<[String:[ModelClass]]?> where ModelClass:WrapModel {
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: [:], serializeForOutput: serializeForOutput)
        self.toModelConverter = { [weak self] (jsonValue:Any) -> [String:[ModelClass]]? in
            // Type check
            guard let jsonDict = jsonValue as? [String:Any] else { return nil }
            var dict = [String:[[String:Any]]]()
            for (key,val) in jsonDict {
                if let dictVal = val as? [[String:Any]] {
                    dict[key] = dictVal
                }
            }
            // Copy mutable status of parent model
            var modelDict = [String:[ModelClass]]()
            modelDict.reserveCapacity(dict.count)
            for (key,value) in dict {
                // Copy mutable status of parent model
                let modelArray:[ModelClass] = value.map {
                    let aModel = ModelClass.init(data:$0, mutable:self?.model.isMutable ?? false)
                    if let lock = self?.model.lock {
                        // Share parent model's data lock with child model
                        aModel.lock = lock
                    }
                    return aModel
                }
                modelDict[key] = modelArray
            }
            return modelDict
        }
        self.fromModelConverter = { (nativeValue:[String:[ModelClass]]?) -> Any? in
            guard let modelDict = nativeValue else { return nil }
            var rawDict = [String:Any]()
            rawDict.reserveCapacity(modelDict.count)
            for (key,value) in modelDict {
                let dictArray:[[String:Any]] = value.map { $0.currentModelData(withNulls: false, forOutput: false) }
                rawDict[key] = dictArray
            }
            return rawDict
        }
    }
    override public func rawValue(withNulls: Bool, forOutput: Bool) -> Any? {
        guard !forOutput || self.serializeForOutput else { return nil }
        guard let val = self.value else { return nil }
        var mdict = [String:Any]()
        for (k, v) in val {
            let dictArray:[[String:Any]] = v.map { $0.currentModelData(withNulls: withNulls, forOutput: forOutput) }
            mdict[k] = dictArray
        }
        return mdict
    }
}

// MARK: WrapPropertyIntFromString

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

// MARK: WrapPropertyOptionalIntFromString

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

// MARK: WrapPropertyBool

@objc
public enum WrapPropertyBoolOutputType: Int {
    case boolean // native JSON true/false
    case yesNo // "yes" or "no"
    case ynString // "Y" or "N"
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
                case .ynString: return nativeValue ? "Y" : "N"
                case .tfString: return nativeValue ? "T" : "F"
                case .numeric: return nativeValue ? 1 : 0
            }
        }
    }
    
    static public func isTrueString(_ str:String?) -> Bool {
        return str?.isTrueString() ?? false
    }
}

// MARK: Number conversions

fileprivate func intFromAny(_ val:Any) -> Int? {
    if let dblVal = val as? Double {
        return Int(dblVal.rounded())
    } else if let fltVal = val as? Float {
        return Int(fltVal.rounded())
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
    } else if let fltVal = val as? Float {
        return fltVal
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
    } else if let fltVal = val as? Float {
        return Double(fltVal)
    } else if let strVal = val as? String {
        return Double(strVal)
    } else if let intVal = val as? Int {
        return Double(intVal)
    }
    return nil
}

// MARK: WrapPropertyInt

public class WrapPropertyInt: WrapProperty<Int> {
    override public init(_ keyPath: String, defaultValue: Int = 0, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> Int in
            return intFromAny(jsonValue) ?? 0
        }
    }
}

// MARK: WrapPropertyOptionalInt

public class WrapPropertyOptionalInt: WrapPropertyOptional<Int> {
    override public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> Int? in
            return intFromAny(jsonValue)
        }
    }
}

// MARK: WrapPropertyIntArray

public class WrapPropertyIntArray: WrapPropertyArray<Int> {
    override public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> [Int] in
            guard let array = jsonValue as? [Any] else { return [] }
            return array.compactMap { intFromAny($0) }
        }
    }
}

// MARK: WrapPropertyOptionalIntArray

public class WrapPropertyOptionalIntArray: WrapPropertyOptionalArray<Int> {
    override public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> [Int]? in
            guard let array = jsonValue as? [Any] else { return nil }
            return array.compactMap { intFromAny($0) }
        }
    }
}

// MARK: WrapPropertyDouble

public class WrapPropertyDouble: WrapProperty<Double> {
    override public init(_ keyPath: String, defaultValue: Double = 0, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
    }
}

// MARK: WrapPropertyFloat

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

// MARK: WrapPropertyFloatArray

public class WrapPropertyFloatArray: WrapPropertyArray<Float> {
    override public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> [Float] in
            guard let array = jsonValue as? [Any] else { return [] }
            return array.compactMap { floatFromAny($0) }
        }
    }
}

// MARK: WrapPropertyOptionalFloatArray

public class WrapPropertyOptionalFloatArray: WrapPropertyOptionalArray<Float> {
    override public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> [Float]? in
            guard let array = jsonValue as? [Any] else { return nil }
            return array.compactMap { floatFromAny($0) }
        }
    }
}

// MARK: WrapPropertyNSNumberInt

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

// MARK: WrapPropertyNSNumberFloat

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

// MARK: WrapPropertyString

public class WrapPropertyString: WrapProperty<String> {
    override public init(_ keyPath: String, defaultValue: String = "", serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
    }
}

// MARK: WrapPropertyDict

public class WrapPropertyDict: WrapProperty<[String:Any]> {
    public init(_ keyPath: String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: [:], serializeForOutput: serializeForOutput)
    }
}

// MARK: WrapPropertyDate

/// WrapPropertyDate handles a variety of date input formats, but always outputs in the format specified to the initializer.
/// ISO8601 formatted dates are handled using the default options of ISO8601DateFormatter.
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
        case mdySlashes         // 05/06/2018
        case mdyDashes          // 05-06-2018
        case dmySlashes         // 30/02/2017
        case dmyDashes          // 30-02-2017

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
            DateOutputType.mdySlashes: "MM/dd/yyyy",
            DateOutputType.mdyDashes: "MM-dd-yyyy",
            DateOutputType.dmySlashes: "dd/MM/yyyy",
            DateOutputType.dmyDashes: "dd-MM-yyyy"
        ]
        static fileprivate let formatsLock = WrapModelLock()
        
        func formatString() -> String {
            assert(DateOutputType.formatsByType[self] != nil)
            return DateOutputType.formatsByType[self] ?? DateOutputType.formatsByType[DateOutputType.iso8601]!
        }
        
        private static var formatters = [String:Formatter]()
        
        func formatter() -> Formatter {
            let fs = self.formatString()
            var foundFormatter:Formatter?
            DateOutputType.formatsLock.reading {
                if let f = DateOutputType.formatters[fs] {
                    foundFormatter = f
                }
            }
            if let ff = foundFormatter {
                return ff
            }
            
            // Special case ISO 8601
            if fs == DateOutputType.ios8601FormatStr {
                let isoFormatter = DateOutputType.formatterISO8601
                DateOutputType.formatsLock.writing {
                    DateOutputType.formatters[fs] = isoFormatter
                }
                return isoFormatter
            }
            
            let newFormatter = DateFormatter()
            DateOutputType.formatsLock.writing {
                newFormatter.locale = Locale(identifier: "en_US_POSIX")
                newFormatter.dateFormat = fs
                DateOutputType.formatters[fs] = newFormatter
            }
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

// MARK: WrapPropertyDateISO8601

/// WrapPropertyDateISO8601 handles IOS8601 formatted dates and allows specification of ISO8601DateFormatter.Options flags to handle
/// specific variations.
public class WrapPropertyDateISO8601: WrapProperty<Date?> {
    
    static var formatters = [ISO8601DateFormatter.Options.RawValue:ISO8601DateFormatter]()
    static fileprivate let formattersLock = WrapModelLock()

    // Cache formatters by option flags combos
    private static func formatter(forOptions options:ISO8601DateFormatter.Options?) -> ISO8601DateFormatter {
        let key = options?.rawValue ?? 0
        
        // Check for already created formatter in cache
        var foundFormatter:ISO8601DateFormatter?
        formattersLock.reading {
            if let f = formatters[key] {
                foundFormatter = f
            }
        }
        if let foundFormatter = foundFormatter {
            return foundFormatter
        }
        
        // Create new formatter using given option flags
        let newFormatter = ISO8601DateFormatter()
        if let options = options {
            newFormatter.formatOptions = options
        }
        formattersLock.writing {
            formatters[key] = newFormatter
        }
        return newFormatter
    }
    
    public init(_ keyPath: String, options: ISO8601DateFormatter.Options?, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: nil, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> Date? in
            if let strVal = jsonValue as? String {
                return WrapPropertyDateISO8601.formatter(forOptions: options).date(from: strVal)
            }
            return nil
        }
        self.fromModelConverter = { (nativeValue:Date?) -> Any? in
            if let date = nativeValue {
                return WrapPropertyDateISO8601.formatter(forOptions: options).string(from: date)
            }
            return nil
        }
    }
}

// MARK: WrapPropertyDateFormatted

/// WrapPropertyDateFormatted handles formatted dates using a specified date format string along with DateFormatter
public class WrapPropertyDateFormatted: WrapProperty<Date?> {
    
    static var formatters = [String:DateFormatter]()
    static fileprivate let formattersLock = WrapModelLock()

    // Cache formatters by format string
    private static func formatter(forFormat format:String) -> DateFormatter {
        
        // Check for already created formatter in cache
        var foundFormatter:DateFormatter?
        formattersLock.reading {
            if let f = formatters[format] {
                foundFormatter = f
            }
        }
        if let foundFormatter = foundFormatter {
            return foundFormatter
        }
        
        // Create new formatter using given format string
        let newFormatter = DateFormatter()
        newFormatter.locale = Locale(identifier: "en_US_POSIX")
        newFormatter.dateFormat = format
        formattersLock.writing {
            formatters[format] = newFormatter
        }
        return newFormatter
    }
    
    public init(_ keyPath: String, dateFormatString format:String, serializeForOutput: Bool = true) {
        super.init(keyPath, defaultValue: nil, serializeForOutput: serializeForOutput)
        self.toModelConverter = { (jsonValue:Any) -> Date? in
            if let strVal = jsonValue as? String {
                return WrapPropertyDateFormatted.formatter(forFormat: format).date(from: strVal)
            }
            return nil
        }
        self.fromModelConverter = { (nativeValue:Date?) -> Any? in
            if let date = nativeValue {
                return WrapPropertyDateFormatted.formatter(forFormat: format).string(from: date)
            }
            return nil
        }
    }
}

// MARK: Specific Property Wrapper support

#if swift(>=5.1)
// MARK: EnumUnkProperty
// Property wrapper for WPOptEnum
// A WrapConvertibleEnum conformant enum property with an "unknown" enum value which is never
// written to the data dictionary and which is returned if the data dictionary contains no value.
@propertyWrapper
public struct EnumUnkProperty<T:WrapConvertibleEnum> {
    let wrapProperty: WPOptEnum<T>
    let unknownEnum: T
    let getModifier: (T)->T
    public var wrappedValue: T {
        get { return getModifier(wrapProperty.value ?? unknownEnum) }
    }
    public init(_ keyPath:String, unknown: T, serializeForOutput: Bool = true, modifier: @escaping (T)->T = { $0 } ) {
        self.wrapProperty = WPOptEnum<T>(keyPath, serializeForOutput: serializeForOutput)
        self.unknownEnum = unknown
        self.getModifier = modifier
    }
}
extension EnumUnkProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutEnumUnkProperty<T:WrapConvertibleEnum> {
    let wrapProperty: WPOptEnum<T>
    let unknownEnum: T
    let getModifier: (T)->T
    let setModifier: (T)->T
    public var wrappedValue: T {
        get { return getModifier(wrapProperty.value ?? unknownEnum) }
        set { let mod = setModifier(newValue); wrapProperty.value = mod == unknownEnum ? nil : mod }
    }
    public init(_ keyPath:String, unknown: T, serializeForOutput: Bool = true, getModifier: @escaping (T)->T = { $0 }, setModifier: @escaping (T)->T = { $0 } ) {
        self.wrapProperty = WPOptEnum<T>(keyPath, serializeForOutput: serializeForOutput)
        self.unknownEnum = unknown
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutEnumUnkProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: EnumProperty
// Property Wrapper for WPEnum (WrapPropertyConvertibleEnum)
// A WrapConvertibleEnum conformant enum property with a default enum value which will be
// returned as the property value and also written to JSON output if no other value is set
// (assuming serializeForOutput is true).
@propertyWrapper
public struct EnumProperty<T:WrapConvertibleEnum> {
    let wrapProperty: WPEnum<T>
    let getModifier: (T)->T
    public var wrappedValue: T {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, defaultEnum: T, serializeForOutput: Bool = true, modifier: @escaping (T)->T = { $0 } ) {
        self.wrapProperty = WPEnum<T>(keyPath, defaultEnum: defaultEnum ,serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension EnumProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutEnumProperty<T:WrapConvertibleEnum> {
    let wrapProperty: WPEnum<T>
    let getModifier: (T)->T
    let setModifier: (T)->T
    public var wrappedValue: T {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, defaultEnum: T, serializeForOutput: Bool = true, getModifier: @escaping (T)->T = { $0 }, setModifier: @escaping (T)->T = { $0 } ) {
        self.wrapProperty = WPEnum<T>(keyPath, defaultEnum: defaultEnum ,serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutEnumProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: OptEnumProperty
// Property wrapper for WPOptEnum
// A WrapConvertibleEnum conformant optional enum property.
@propertyWrapper
public struct OptEnumProperty<T:WrapConvertibleEnum> {
    let wrapProperty: WPOptEnum<T>
    let getModifier: (T?)->T?
    public var wrappedValue: T? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping (T?)->T? = { $0 } ) {
        self.wrapProperty = WPOptEnum<T>(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension OptEnumProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutOptEnumProperty<T:WrapConvertibleEnum> {
    let wrapProperty: WPOptEnum<T>
    let getModifier: (T?)->T?
    let setModifier: (T?)->T?
    public var wrappedValue: T? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping (T?)->T? = { $0 }, setModifier: @escaping (T?)->T? = { $0 } ) {
        self.wrapProperty = WPOptEnum<T>(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutOptEnumProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: IntProperty
// Property wrapper for WPInt (WrapPropertyInt)
@propertyWrapper
public struct IntProperty {
    let wrapProperty: WPInt
    let getModifier: (Int)->Int
    public var wrappedValue: Int {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, defaultValue: Int = 0, serializeForOutput: Bool = true, modifier: @escaping (Int)->Int = { $0 } ) {
        self.wrapProperty = WPInt(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension IntProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutIntProperty {
    let wrapProperty: WPInt
    let getModifier: (Int)->Int
    let setModifier: (Int)->Int
    public var wrappedValue: Int {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, defaultValue: Int = 0, serializeForOutput: Bool = true, getModifier: @escaping (Int)->Int = { $0 }, setModifier: @escaping (Int)->Int = { $0 } ) {
        self.wrapProperty = WPInt(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutIntProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: OptIntProperty
// Property wrapper for WPOptInt (WrapPropertyOptionalInt)
@propertyWrapper
public struct OptIntProperty {
    let wrapProperty: WPOptInt
    let getModifier: (Int?)->Int?
    public var wrappedValue: Int? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping (Int?)->Int? = { $0 } ) {
        self.wrapProperty = WPOptInt(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension OptIntProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutOptIntProperty {
    let wrapProperty: WPOptInt
    let getModifier: (Int?)->Int?
    let setModifier: (Int?)->Int?
    public var wrappedValue: Int? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping (Int?)->Int? = { $0 }, setModifier: @escaping (Int?)->Int? = { $0 } ) {
        self.wrapProperty = WPOptInt(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutOptIntProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: FloatProperty
// Property wrapper for WPFloat (WrapPropertyFloat)
@propertyWrapper
public struct FloatProperty {
    let wrapProperty: WPFloat
    let getModifier: (Float)->Float
    public var wrappedValue: Float {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, defaultValue: Float = 0.0, serializeForOutput: Bool = true, modifier: @escaping (Float)->Float = { $0 } ) {
        self.wrapProperty = WPFloat(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension FloatProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutFloatProperty {
    let wrapProperty: WPFloat
    let getModifier: (Float)->Float
    let setModifier: (Float)->Float
    public var wrappedValue: Float {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, defaultValue: Float = 0.0, serializeForOutput: Bool = true, getModifier: @escaping (Float)->Float = { $0 }, setModifier: @escaping (Float)->Float = { $0 } ) {
        self.wrapProperty = WPFloat(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutFloatProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: DoubleProperty
// Property wrapper for WPDouble (WrapPropertyDouble)
@propertyWrapper
public struct DoubleProperty {
    let wrapProperty: WPDouble
    let getModifier: (Double)->Double
    public var wrappedValue: Double {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, defaultValue: Double = 0.0, serializeForOutput: Bool = true, modifier: @escaping (Double)->Double = { $0 } ) {
        self.wrapProperty = WPDouble(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension DoubleProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutDoubleProperty {
    let wrapProperty: WPDouble
    let getModifier: (Double)->Double
    let setModifier: (Double)->Double
    public var wrappedValue: Double {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, defaultValue: Double = 0.0, serializeForOutput: Bool = true, getModifier: @escaping (Double)->Double = { $0 }, setModifier: @escaping (Double)->Double = { $0 } ) {
        self.wrapProperty = WPDouble(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutDoubleProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: BoolProperty
// Property wrapper for WPBool (WrapPropertyBool)
@propertyWrapper
public struct BoolProperty {
    let wrapProperty: WPBool
    let getModifier: (Bool)->Bool
    public var wrappedValue: Bool {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, defaultValue: Bool = false, serializeForOutput: Bool = true, modifier: @escaping (Bool)->Bool = { $0 } ) {
        self.wrapProperty = WPBool(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension BoolProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutBoolProperty {
    let wrapProperty: WPBool
    let getModifier: (Bool)->Bool
    let setModifier: (Bool)->Bool
    public var wrappedValue: Bool {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, defaultValue: Bool = false, serializeForOutput: Bool = true, getModifier: @escaping (Bool)->Bool = { $0 }, setModifier: @escaping (Bool)->Bool = { $0 } ) {
        self.wrapProperty = WPBool(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutBoolProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: NumIntProperty
// Property wrapper for WPNumInt (WrapPropertyNSNumberInt)
@propertyWrapper
public struct NumIntProperty {
    let wrapProperty: WPNumInt
    let getModifier: (NSNumber?)->NSNumber?
    public var wrappedValue: NSNumber? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping (NSNumber?)->NSNumber? = { $0 } ) {
        self.wrapProperty = WPNumInt(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension NumIntProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutNumIntProperty {
    let wrapProperty: WPNumInt
    let getModifier: (NSNumber?)->NSNumber?
    let setModifier: (NSNumber?)->NSNumber?
    public var wrappedValue: NSNumber? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping (NSNumber?)->NSNumber? = { $0 }, setModifier: @escaping (NSNumber?)->NSNumber? = { $0 } ) {
        self.wrapProperty = WPNumInt(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutNumIntProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: NumFloatProperty
// Property wrapper for WPNumFloat (WrapPropertyNSNumberFloat)
@propertyWrapper
public struct NumFloatProperty {
    let wrapProperty: WPNumFloat
    let getModifier: (NSNumber?)->NSNumber?
    public var wrappedValue: NSNumber? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping (NSNumber?)->NSNumber? = { $0 } ) {
        self.wrapProperty = WPNumFloat(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension NumFloatProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutNumFloatProperty {
    let wrapProperty: WPNumFloat
    let getModifier: (NSNumber?)->NSNumber?
    let setModifier: (NSNumber?)->NSNumber?
    public var wrappedValue: NSNumber? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping (NSNumber?)->NSNumber? = { $0 }, setModifier: @escaping (NSNumber?)->NSNumber? = { $0 } ) {
        self.wrapProperty = WPNumFloat(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutNumFloatProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: IntStrProperty
// Property wrapper for WPIntStr (WrapPropertyIntFromString)
@propertyWrapper
public struct IntStrProperty {
    let wrapProperty: WPIntStr
    let getModifier: (Int)->Int
    public var wrappedValue: Int {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, defaultValue: Int = 0, serializeForOutput: Bool = true, modifier: @escaping (Int)->Int = { $0 } ) {
        self.wrapProperty = WPIntStr(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension IntStrProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutIntStrProperty {
    let wrapProperty: WPIntStr
    let getModifier: (Int)->Int
    let setModifier: (Int)->Int
    public var wrappedValue: Int {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, defaultValue: Int = 0, serializeForOutput: Bool = true, getModifier: @escaping (Int)->Int = { $0 }, setModifier: @escaping (Int)->Int = { $0 } ) {
        self.wrapProperty = WPIntStr(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutIntStrProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: OptIntStrProperty
// Property wrapper for WPOptIntStr (WrapPropertyOptionalIntFromString)
@propertyWrapper
public struct OptIntStrProperty {
    let wrapProperty: WPOptIntStr
    let getModifier: (Int?)->Int?
    public var wrappedValue: Int? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping (Int?)->Int? = { $0 } ) {
        self.wrapProperty = WPOptIntStr(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension OptIntStrProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutOptIntStrProperty {
    let wrapProperty: WPOptIntStr
    let getModifier: (Int?)->Int?
    let setModifier: (Int?)->Int?
    public var wrappedValue: Int? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping (Int?)->Int? = { $0 }, setModifier: @escaping (Int?)->Int? = { $0 } ) {
        self.wrapProperty = WPOptIntStr(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutOptIntStrProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: DictProperty
// Property wrapper for WPDict (WrapPropertyDict)
@propertyWrapper
public struct DictProperty {
    let wrapProperty: WPDict
    let getModifier: ([String:Any])->[String:Any]
    public var wrappedValue: [String:Any] {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([String:Any])->[String:Any] = { $0 } ) {
        self.wrapProperty = WPDict(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension DictProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutDictProperty {
    let wrapProperty: WPDict
    let getModifier: ([String:Any])->[String:Any]
    let setModifier: ([String:Any])->[String:Any]
    public var wrappedValue: [String:Any] {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([String:Any])->[String:Any] = { $0 }, setModifier: @escaping ([String:Any])->[String:Any] = { $0 } ) {
        self.wrapProperty = WPDict(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutDictProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: OptDictProperty
// Property wrapper for WPOptDict (WrapPropertyOptional<[String:Any]>)
@propertyWrapper
public struct OptDictProperty {
    let wrapProperty: WPOptDict
    let getModifier: ([String:Any]?)->[String:Any]?
    public var wrappedValue: [String:Any]? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([String:Any]?)->[String:Any]? = { $0 } ) {
        self.wrapProperty = WPOptDict(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension OptDictProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutOptDictProperty {
    let wrapProperty: WPOptDict
    let getModifier: ([String:Any]?)->[String:Any]?
    let setModifier: ([String:Any]?)->[String:Any]?
    public var wrappedValue: [String:Any]? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([String:Any]?)->[String:Any]? = { $0 }, setModifier: @escaping ([String:Any]?)->[String:Any]? = { $0 } ) {
        self.wrapProperty = WPOptDict(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutOptDictProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: StrProperty
// Property wrapper for WPStr (WrapPropertyString)
@propertyWrapper
public struct StrProperty {
    let wrapProperty: WPStr
    let getModifier: (String)->String
    public var wrappedValue: String {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, defaultValue: String = "", serializeForOutput: Bool = true, modifier: @escaping (String)->String = { $0 } ) {
        self.wrapProperty = WPStr(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension StrProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutStrProperty {
    let wrapProperty: WPStr
    let getModifier: (String)->String
    let setModifier: (String)->String
    public var wrappedValue: String {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, defaultValue: String = "", serializeForOutput: Bool = true, getModifier: @escaping (String)->String = { $0 }, setModifier: @escaping (String)->String = { $0 } ) {
        self.wrapProperty = WPStr(keyPath, defaultValue: defaultValue, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutStrProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: OptStrProperty
// Property wrapper for WPOptStr (WrapPropertyOptional<String>)
@propertyWrapper
public struct OptStrProperty {
    let wrapProperty: WPOptStr
    let getModifier: (String?)->String?
    public var wrappedValue: String? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping (String?)->String? = { $0 } ) {
        self.wrapProperty = WPOptStr(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension OptStrProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutOptStrProperty {
    let wrapProperty: WPOptStr
    let getModifier: (String?)->String?
    let setModifier: (String?)->String?
    public var wrappedValue: String? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping (String?)->String? = { $0 }, setModifier: @escaping (String?)->String? = { $0 } ) {
        self.wrapProperty = WPOptStr(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutOptStrProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: GroupProperty
// Property Wrapper for WPGroup (WrapPropertyGroup)
// Has no mutable variant
@propertyWrapper
public struct GroupProperty<T:WrapModel> {
    let wrapProperty: WPGroup<T>
    public var wrappedValue: T {
        get { return wrapProperty.value }
    }
    public init() {
        self.wrapProperty = WPGroup<T>()
    }
}
extension GroupProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: ModelProperty
// Property wrapper for WPModel (WrapPropertyModel)
@propertyWrapper
public struct ModelProperty<T:WrapModel> {
    let wrapProperty: WPModel<T>
    let getModifier: (T?)->T?
    public var wrappedValue: T? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping (T?)->T? = { $0 } ) {
        self.wrapProperty = WPModel<T>(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension ModelProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutModelProperty<T:WrapModel> {
    let wrapProperty: WPModel<T>
    let getModifier: (T?)->T?
    let setModifier: (T?)->T?
    public var wrappedValue: T? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping (T?)->T? = { $0 }, setModifier: @escaping (T?)->T? = { $0 } ) {
        self.wrapProperty = WPModel<T>(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutModelProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: ModelArrayProperty
// Property wrapper for WPModelArray (WrapPropertyArrayOfModel)
@propertyWrapper
public struct ModelArrayProperty<T:WrapModel> {
    let wrapProperty: WPModelArray<T>
    let getModifier: ([T])->[T]
    public var wrappedValue: [T] {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([T])->[T] = { $0 } ) {
        self.wrapProperty = WPModelArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension ModelArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutModelArrayProperty<T:WrapModel> {
    let wrapProperty: WPModelArray<T>
    let getModifier: ([T])->[T]
    let setModifier: ([T])->[T]
    public var wrappedValue: [T] {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([T])->[T] = { $0 }, setModifier: @escaping ([T])->[T] = { $0 } ) {
        self.wrapProperty = WPModelArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutModelArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: OptModelArrayProperty
// Property wrapper for WPOptModelArray (WrapPropertyOptionalArrayOfModel)
@propertyWrapper
public struct OptModelArrayProperty<T:WrapModel> {
    let wrapProperty: WPOptModelArray<T>
    let getModifier: ([T]?)->[T]?
    public var wrappedValue: [T]? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([T]?)->[T]? = { $0 } ) {
        self.wrapProperty = WPOptModelArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension OptModelArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutOptModelArrayProperty<T:WrapModel> {
    let wrapProperty: WPOptModelArray<T>
    let getModifier: ([T]?)->[T]?
    let setModifier: ([T]?)->[T]?
    public var wrappedValue: [T]? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([T]?)->[T]? = { $0 }, setModifier: @escaping ([T]?)->[T]? = { $0 } ) {
        self.wrapProperty = WPOptModelArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutOptModelArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: ModelDictProperty
// Property wrapper for WPModelDict (WrapPropertyDictionaryOfModel)
@propertyWrapper
public struct ModelDictProperty<T:WrapModel> {
    let wrapProperty: WPModelDict<T>
    let getModifier: ([String:T])->[String:T]
    public var wrappedValue: [String:T] {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([String:T])->[String:T] = { $0 } ) {
        self.wrapProperty = WPModelDict(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension ModelDictProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutModelDictProperty<T:WrapModel> {
    let wrapProperty: WPModelDict<T>
    let getModifier: ([String:T])->[String:T]
    let setModifier: ([String:T])->[String:T]
    public var wrappedValue: [String:T] {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([String:T])->[String:T] = { $0 }, setModifier: @escaping ([String:T])->[String:T] = { $0 } ) {
        self.wrapProperty = WPModelDict(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutModelDictProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: OptModelDictProperty
// Property wrapper for WPOptModelDict (WrapPropertyOptionalDictionaryOfModel)
@propertyWrapper
public struct OptModelDictProperty<T:WrapModel> {
    let wrapProperty: WPOptModelDict<T>
    let getModifier: ([String:T]?)->[String:T]?
    public var wrappedValue: [String:T]? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([String:T]?)->[String:T]? = { $0 } ) {
        self.wrapProperty = WPOptModelDict(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension OptModelDictProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutOptModelDictProperty<T:WrapModel> {
    let wrapProperty: WPOptModelDict<T>
    let getModifier: ([String:T]?)->[String:T]?
    let setModifier: ([String:T]?)->[String:T]?
    public var wrappedValue: [String:T]? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([String:T]?)->[String:T]? = { $0 }, setModifier: @escaping ([String:T]?)->[String:T]? = { $0 } ) {
        self.wrapProperty = WPOptModelDict(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutOptModelDictProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: EmbModelArrayProperty
// Property wrapper for WPEmbModelArray (WrapPropertyArrayOfEmbeddedModel)
@propertyWrapper
public struct EmbModelArrayProperty<T:WrapModel> {
    let wrapProperty: WPEmbModelArray<T>
    let getModifier: ([T])->[T]
    public var wrappedValue: [T] {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, embedPath:String? = nil, serializeForOutput: Bool = true, modifier: @escaping ([T])->[T] = { $0 } ) {
        self.wrapProperty = WPEmbModelArray(keyPath, embedPath: embedPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension EmbModelArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutEmbModelArrayProperty<T:WrapModel> {
    let wrapProperty: WPEmbModelArray<T>
    let getModifier: ([T])->[T]
    let setModifier: ([T])->[T]
    public var wrappedValue: [T] {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, embedPath:String? = nil, serializeForOutput: Bool = true, getModifier: @escaping ([T])->[T] = { $0 }, setModifier: @escaping ([T])->[T] = { $0 } ) {
        self.wrapProperty = WPEmbModelArray(keyPath, embedPath: embedPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutEmbModelArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: OptEmbModelArrayProperty
// Property wrapper for WPOptEmbModelArray (WrapPropertyOptionalArrayOfEmbeddedModel)
@propertyWrapper
public struct OptEmbModelArrayProperty<T:WrapModel> {
    let wrapProperty: WPOptEmbModelArray<T>
    let getModifier: ([T]?)->[T]?
    public var wrappedValue: [T]? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, embedPath:String? = nil, serializeForOutput: Bool = true, modifier: @escaping ([T]?)->[T]? = { $0 } ) {
        self.wrapProperty = WPOptEmbModelArray(keyPath, embedPath: embedPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension OptEmbModelArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutOptEmbModelArrayProperty<T:WrapModel> {
    let wrapProperty: WPOptEmbModelArray<T>
    let getModifier: ([T]?)->[T]?
    let setModifier: ([T]?)->[T]?
    public var wrappedValue: [T]? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, embedPath:String? = nil, serializeForOutput: Bool = true, getModifier: @escaping ([T]?)->[T]? = { $0 }, setModifier: @escaping ([T]?)->[T]? = { $0 } ) {
        self.wrapProperty = WPOptEmbModelArray(keyPath, embedPath: embedPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutOptEmbModelArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: DictModelArrayProperty
// Property wrapper for WPDictModelArray (WrapPropertyDictionaryOfArrayOfModel)
@propertyWrapper
public struct DictModelArrayProperty<T:WrapModel> {
    let wrapProperty: WPDictModelArray<T>
    let getModifier: ([String:[T]])->[String:[T]]
    public var wrappedValue: [String:[T]] {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([String:[T]])->[String:[T]] = { $0 } ) {
        self.wrapProperty = WPDictModelArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension DictModelArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutDictModelArrayProperty<T:WrapModel> {
    let wrapProperty: WPDictModelArray<T>
    let getModifier: ([String:[T]])->[String:[T]]
    let setModifier: ([String:[T]])->[String:[T]]
    public var wrappedValue: [String:[T]] {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([String:[T]])->[String:[T]] = { $0 }, setModifier: @escaping ([String:[T]])->[String:[T]] = { $0 } ) {
        self.wrapProperty = WPDictModelArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutDictModelArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: OptDictModelArrayProperty
// Property wrapper for WPOptDictModelArray (WrapPropertyOptionalDictionaryOfArrayOfModel)
@propertyWrapper
public struct OptDictModelArrayProperty<T:WrapModel> {
    let wrapProperty: WPOptDictModelArray<T>
    let getModifier: ([String:[T]]?)->[String:[T]]?
    public var wrappedValue: [String:[T]]? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([String:[T]]?)->[String:[T]]? = { $0 } ) {
        self.wrapProperty = WPOptDictModelArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension OptDictModelArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutOptDictModelArrayProperty<T:WrapModel> {
    let wrapProperty: WPOptDictModelArray<T>
    let getModifier: ([String:[T]]?)->[String:[T]]?
    let setModifier: ([String:[T]]?)->[String:[T]]?
    public var wrappedValue: [String:[T]]? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([String:[T]]?)->[String:[T]]? = { $0 }, setModifier: @escaping ([String:[T]]?)->[String:[T]]? = { $0 } ) {
        self.wrapProperty = WPOptDictModelArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutOptDictModelArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: DateProperty
// Property wrapper for WPDate (WrapPropertyDate)
@propertyWrapper
public struct DateProperty {
    let wrapProperty: WPDate
    let getModifier: (Date?)->Date?
    public var wrappedValue: Date? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, dateType: WrapPropertyDate.DateOutputType, serializeForOutput: Bool = true, modifier: @escaping (Date?)->Date? = { $0 } ) {
        self.wrapProperty = WPDate(keyPath, dateType: dateType, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension DateProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutDateProperty {
    let wrapProperty: WPDate
    let getModifier: (Date?)->Date?
    let setModifier: (Date?)->Date?
    public var wrappedValue: Date? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, dateType: WrapPropertyDate.DateOutputType, serializeForOutput: Bool = true, getModifier: @escaping (Date?)->Date? = { $0 }, setModifier: @escaping (Date?)->Date? = { $0 } ) {
        self.wrapProperty = WPDate(keyPath, dateType: dateType, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutDateProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}


// MARK: Date8601Property
// Property wrapper for WPDate8601 (WrapPropertyDateISO8601)
@propertyWrapper
public struct Date8601Property {
    let wrapProperty: WPDate8601
    let getModifier: (Date?)->Date?
    public var wrappedValue: Date? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, options: ISO8601DateFormatter.Options?, serializeForOutput: Bool = true, modifier: @escaping (Date?)->Date? = { $0 } ) {
        self.wrapProperty = WPDate8601(keyPath, options:options, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension Date8601Property: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutDate8601Property {
    let wrapProperty: WPDate8601
    let getModifier: (Date?)->Date?
    let setModifier: (Date?)->Date?
    public var wrappedValue: Date? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, options: ISO8601DateFormatter.Options?, serializeForOutput: Bool = true, getModifier: @escaping (Date?)->Date? = { $0 }, setModifier: @escaping (Date?)->Date? = { $0 } ) {
        self.wrapProperty = WPDate8601(keyPath, options:options, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutDate8601Property: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}


/// MARK: DateFmtProperty
// Property wrapper for WPDateFmt (WrapPropertyDateFormatted)
@propertyWrapper
public struct DateFmtProperty {
    let wrapProperty: WPDateFmt
    let getModifier: (Date?)->Date?
    public var wrappedValue: Date? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, dateFormatString format:String, serializeForOutput: Bool = true, modifier: @escaping (Date?)->Date? = { $0 } ) {
        self.wrapProperty = WPDateFmt(keyPath, dateFormatString:format, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension DateFmtProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutDateFmtProperty {
    let wrapProperty: WPDateFmt
    let getModifier: (Date?)->Date?
    let setModifier: (Date?)->Date?
    public var wrappedValue: Date? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, dateFormatString format:String, serializeForOutput: Bool = true, getModifier: @escaping (Date?)->Date? = { $0 }, setModifier: @escaping (Date?)->Date? = { $0 } ) {
        self.wrapProperty = WPDateFmt(keyPath, dateFormatString:format, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutDateFmtProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}


// MARK: IntArrayProperty
// Property wrapper for WPIntArray (WrapPropertyIntArray)
@propertyWrapper
public struct IntArrayProperty {
    let wrapProperty: WPIntArray
    let getModifier: ([Int])->[Int]
    public var wrappedValue: [Int] {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([Int])->[Int] = { $0 } ) {
        self.wrapProperty = WPIntArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension IntArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutIntArrayProperty {
    let wrapProperty: WPIntArray
    let getModifier: ([Int])->[Int]
    let setModifier: ([Int])->[Int]
    public var wrappedValue: [Int] {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([Int])->[Int] = { $0 }, setModifier: @escaping ([Int])->[Int] = { $0 } ) {
        self.wrapProperty = WPIntArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutIntArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: OptIntArrayProperty
// Property wrapper for WPOptIntArray (WrapPropertyOptionalIntArray)
@propertyWrapper
public struct OptIntArrayProperty {
    let wrapProperty: WPOptIntArray
    let getModifier: ([Int]?)->[Int]?
    public var wrappedValue: [Int]? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([Int]?)->[Int]? = { $0 } ) {
        self.wrapProperty = WPOptIntArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension OptIntArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutOptIntArrayProperty {
    let wrapProperty: WPOptIntArray
    let getModifier: ([Int]?)->[Int]?
    let setModifier: ([Int]?)->[Int]?
    public var wrappedValue: [Int]? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([Int]?)->[Int]? = { $0 }, setModifier: @escaping ([Int]?)->[Int]? = { $0 } ) {
        self.wrapProperty = WPOptIntArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutOptIntArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: FloatArrayProperty
// Property wrapper for WPFloatArray (WrapPropertyFloatArray)
@propertyWrapper
public struct FloatArrayProperty {
    let wrapProperty: WPFloatArray
    let getModifier: ([Float])->[Float]
    public var wrappedValue: [Float] {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([Float])->[Float] = { $0 } ) {
        self.wrapProperty = WPFloatArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension FloatArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutFloatArrayProperty {
    let wrapProperty: WPFloatArray
    let getModifier: ([Float])->[Float]
    let setModifier: ([Float])->[Float]
    public var wrappedValue: [Float] {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([Float])->[Float] = { $0 }, setModifier: @escaping ([Float])->[Float] = { $0 } ) {
        self.wrapProperty = WPFloatArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutFloatArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: OptFloatArrayProperty
// Property wrapper for WPOptFloatArray (WrapPropertyOptionalFloatArray)
@propertyWrapper
public struct OptFloatArrayProperty {
    let wrapProperty: WPOptFloatArray
    let getModifier: ([Float]?)->[Float]?
    public var wrappedValue: [Float]? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([Float]?)->[Float]? = { $0 } ) {
        self.wrapProperty = WPOptFloatArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension OptFloatArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutOptFloatArrayProperty {
    let wrapProperty: WPOptFloatArray
    let getModifier: ([Float]?)->[Float]?
    let setModifier: ([Float]?)->[Float]?
    public var wrappedValue: [Float]? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([Float]?)->[Float]? = { $0 }, setModifier: @escaping ([Float]?)->[Float]? = { $0 } ) {
        self.wrapProperty = WPOptFloatArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutOptFloatArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: DoubleArrayProperty
// Property wrapper for WPDoubleArray (WrapPropertyArray<Double>)
@propertyWrapper
public struct DoubleArrayProperty {
    let wrapProperty: WPDoubleArray
    let getModifier: ([Double])->[Double]
    public var wrappedValue: [Double] {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([Double])->[Double] = { $0 } ) {
        self.wrapProperty = WPDoubleArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension DoubleArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutDoubleArrayProperty {
    let wrapProperty: WPDoubleArray
    let getModifier: ([Double])->[Double]
    let setModifier: ([Double])->[Double]
    public var wrappedValue: [Double] {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([Double])->[Double] = { $0 }, setModifier: @escaping ([Double])->[Double] = { $0 } ) {
        self.wrapProperty = WPDoubleArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutDoubleArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: OptDoubleArrayProperty
// Property wrapper for WPOptDoubleArray (WrapPropertyOptionalArray<Double>)
@propertyWrapper
public struct OptDoubleArrayProperty {
    let wrapProperty: WPOptDoubleArray
    let getModifier: ([Double]?)->[Double]?
    public var wrappedValue: [Double]? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([Double]?)->[Double]? = { $0 } ) {
        self.wrapProperty = WPOptDoubleArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension OptDoubleArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutOptDoubleArrayProperty {
    let wrapProperty: WPOptDoubleArray
    let getModifier: ([Double]?)->[Double]?
    let setModifier: ([Double]?)->[Double]?
    public var wrappedValue: [Double]? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([Double]?)->[Double]? = { $0 }, setModifier: @escaping ([Double]?)->[Double]? = { $0 } ) {
        self.wrapProperty = WPOptDoubleArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutOptDoubleArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: StrArrayProperty
// Property wrapper for WPStrArray (WrapPropertyArray<String>)
@propertyWrapper
public struct StrArrayProperty {
    let wrapProperty: WPStrArray
    let getModifier: ([String])->[String]
    public var wrappedValue: [String] {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([String])->[String] = { $0 } ) {
        self.wrapProperty = WPStrArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension StrArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutStrArrayProperty {
    let wrapProperty: WPStrArray
    let getModifier: ([String])->[String]
    let setModifier: ([String])->[String]
    public var wrappedValue: [String] {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([String])->[String] = { $0 }, setModifier: @escaping ([String])->[String] = { $0 } ) {
        self.wrapProperty = WPStrArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutStrArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: OptStrArrayProperty
// Property wrapper for WPOptStrArray (WrapPropertyOptionalArray<String>)
@propertyWrapper
public struct OptStrArrayProperty {
    let wrapProperty: WPOptStrArray
    let getModifier: ([String]?)->[String]?
    public var wrappedValue: [String]? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([String]?)->[String]? = { $0 } ) {
        self.wrapProperty = WPOptStrArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension OptStrArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutOptStrArrayProperty {
    let wrapProperty: WPOptStrArray
    let getModifier: ([String]?)->[String]?
    let setModifier: ([String]?)->[String]?
    public var wrappedValue: [String]? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([String]?)->[String]? = { $0 }, setModifier: @escaping ([String]?)->[String]? = { $0 } ) {
        self.wrapProperty = WPOptStrArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutOptStrArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: DictArrayProperty
// Property wrapper for WPDictArray (WrapPropertyArray<[String:Any]>)
@propertyWrapper
public struct DictArrayProperty {
    let wrapProperty: WPDictArray
    let getModifier: ([[String:Any]])->[[String:Any]]
    public var wrappedValue: [[String:Any]] {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([[String:Any]])->[[String:Any]] = { $0 } ) {
        self.wrapProperty = WPDictArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension DictArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutDictArrayProperty {
    let wrapProperty: WPDictArray
    let getModifier: ([[String:Any]])->[[String:Any]]
    let setModifier: ([[String:Any]])->[[String:Any]]
    public var wrappedValue: [[String:Any]] {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([[String:Any]])->[[String:Any]] = { $0 }, setModifier: @escaping ([[String:Any]])->[[String:Any]] = { $0 } ) {
        self.wrapProperty = WPDictArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutDictArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// MARK: OptDictArrayProperty
// Property wrapper for WPOptDictArray (WrapPropertyOptionalArray<[String:Any]>)
@propertyWrapper
public struct OptDictArrayProperty {
    let wrapProperty: WPOptDictArray
    let getModifier: ([[String:Any]]?)->[[String:Any]]?
    public var wrappedValue: [[String:Any]]? {
        get { return getModifier(wrapProperty.value) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, modifier: @escaping ([[String:Any]]?)->[[String:Any]]? = { $0 } ) {
        self.wrapProperty = WPOptDictArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = modifier
    }
}
extension OptDictArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}

// Mutable variant
@propertyWrapper
public struct MutOptDictArrayProperty {
    let wrapProperty: WPOptDictArray
    let getModifier: ([[String:Any]]?)->[[String:Any]]?
    let setModifier: ([[String:Any]]?)->[[String:Any]]?
    public var wrappedValue: [[String:Any]]? {
        get { return getModifier(wrapProperty.value) }
        set { wrapProperty.value = setModifier(newValue) }
    }
    public init(_ keyPath:String, serializeForOutput: Bool = true, getModifier: @escaping ([[String:Any]]?)->[[String:Any]]? = { $0 }, setModifier: @escaping ([[String:Any]]?)->[[String:Any]]? = { $0 } ) {
        self.wrapProperty = WPOptDictArray(keyPath, serializeForOutput: serializeForOutput)
        self.getModifier = getModifier
        self.setModifier = setModifier
    }
}
extension MutOptDictArrayProperty: AnyWrapPropertyProvider {
    public func property() -> AnyWrapProperty {
        return wrapProperty
    }
}
#endif


//MARK: Typealiases

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
public typealias WPOptEnum = WrapPropertyConvertibleOptionalEnum

// Property group - still defined by a submodel type
public typealias WPGroup = WrapPropertyGroup // specify model type - nonoptional

// Submodels - either alone or in an array or dictionary
public typealias WPModel = WrapPropertyModel // submodel - specify model type - always optional
public typealias WPModelArray = WrapPropertyArrayOfModel // array of model - specify model type - def value []
public typealias WPOptModelArray = WrapPropertyOptionalArrayOfModel // optional array of model - specify model type
public typealias WPModelDict = WrapPropertyDictionaryOfModel // dict in form [String:<model>]
public typealias WPOptModelDict = WrapPropertyOptionalDictionaryOfModel // optional dict in form [String:<model>]

public typealias WPEmbModelArray = WrapPropertyArrayOfEmbeddedModel // array of embedded models - specify model type - def value []
public typealias WPOptEmbModelArray = WrapPropertyOptionalArrayOfEmbeddedModel // optional array of embedded models - specify model type

public typealias WPDictModelArray = WrapPropertyDictionaryOfArrayOfModel // dict of arrays of model - specify model type - type is [String:[<model>]]
public typealias WPOptDictModelArray = WrapPropertyOptionalDictionaryOfArrayOfModel // optional dict of arrays of model - specify model type - [String:[<model>]]?

// Dates - always optional
public typealias WPDate = WrapPropertyDate
public typealias WPDate8601 = WrapPropertyDateISO8601
public typealias WPDateFmt = WrapPropertyDateFormatted

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


// MARK: Internal extensions

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

extension Mirror {
    
    /// Collects the mirror's children and all its parents' mirror's children into one array
    func allChildren() -> [Mirror.Child] {
        var all = Array(self.children)
        
        var parentMirror = self.superclassMirror
        while let parent = parentMirror {
            all.append(contentsOf: parent.children)
            parentMirror = parent.superclassMirror
        }
        
        return all
    }
}
