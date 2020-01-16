

<p align="center">
<img src="https://img.shields.io/cocoapods/p/WrapModel.svg" alt="Platform">
<img src="https://img.shields.io/github/license/1stdibs/WrapModel.svg" alt="License">
<img src="https://img.shields.io/cocoapods/v/WrapModel.svg" alt="Version">	
</p>

# WrapModel
WrapModel is a different way of turning JSON data into a usable model object in Swift (while preserving Objective C compatibility). Instead of viewing the JSON as raw input and immediately transforming it into something else, WrapModel wraps the JSON data with an object that knows how to access parts of the data and only performs transformations as needed.


```swift
// With a bit of JSON data like this
let modelStr =
{
    "last-name": "Smith",
    "first-name": "John",
    "most-recent-purchase": "05/02/2018",
    "cust-no": 12345
}

// A model is defined like this - Objective C compatible with property wrappers (requires Swift 5.1)
class Customer: WrapModel {

	@StrProperty("last-name") var lastName: String
	@StrProperty("first-name") var firstName: String
	@DateProperty("most-recent-purchase", dateType: .mdySlashes) var lastPurchase: Date?
	@IntProperty("cust-no") var custNumber: Int
}

// For PRE-Swift 5.1, a model is defined like this - Objective C compatible public accessors are
// provided in this example. If ObjC compatibility is not needed, those can be removed and the
// property definitions made public so their values can be read/written via their .value member.
class Customer: WrapModel {

	// Property definitions
    private let _lastName     = WPStr("last-name")
    private let _firstName    = WPStr("first-name")
    private let _lastPurchase = WPDate("most-recent-purchase", dateType: .mdySlashes)
    private let _custNumber   = WPInt("cust-no")
    
	// ObjC compatible accessors
	var lastName:String { get { return _lastName.value } set { _lastName.value = newValue } }
	var firstName:String { get { return _firstName.value } set { _firstName.value = newValue } }
	var lastPurchase:Date? { get { return _lastPurchase.value } set { _lastPurchase.value = newValue } }
	var custNumber:Int { get { return _custNumber.value } set { _custNumber.value = newValue } }
}

// Model properties can be read/written just like any other member of a class.
// The model is marked as mutable/immutable on creation.
if let cust = Customer(json: modelStr, mutable: true) {

	// Read properties
    let fullName = "\(cust.firstName) \(cust.lastName)"
    print("customer is \(fullName)")
    
    // Mutate a property
    cust.lastPurchase = Date()
}
```

## Contents

1. [Rationale](#rationale)
1. [Requirements](#requirements)
1. [Communication](#communication)
1. [Why not Codable?](#codable)
1. [Usage](#usage)
	- [Define a model using Property Wrappers - Swift 5.1 & later - ObjC accessible](#usage-example-property-wrappers)
	- [Define a model using WrapProperty objects only - Swift accessible only](#usage-example-objects-only)
	- [Define a model using the private definitions/public accessors pattern - ObjC accessible](#usage-example-accessors)
	- [Initializing a model object from a Dictionary or JSON String](#usage-example-initializing)
1. [Thread safety](#thread-safety)
1. [Model Properties](#model-properties)
    - [Key paths](#key-paths)
    - [Default property values](#defaults)
    - [Provided property types](#property-types)
	    1. [Basic](#pt-basic)
	    1. [NSNumber](#pt-nsnumber)
	    1. [Integer encoded as string](#pt-integer-string)
	    1. [Dictionaries](#pt-dictionaries)
	    1. [Strings](#pt-strings)
	    1. [Enums](#pt-enums)
	    1. [Submodels](#pt-submodels)
	    1. [Arrays of submodels](#pt-arrays-of-submodels)
	    1. [Property Groups](#pt-groups)
	    1. [Dates](#pt-dates)
	    1. [Arrays](#pt-arrays)
	    1. [Others](#pt-others)
    - [More about some property types](#more-about-properties)
	    - [Enum properties](#enums)
	    - [Date properties](#dates)
	    - [Arrays of embedded submodels](#embedded-submodel-arrays)
	    - [Property Groups](#property-groups)
    - [Property serialization](#serialization-modes)
    - [Custom properties](#custom-properties)
1. [Property Wrappers & Value Modifiers](#wrappers-and-modifiers)
	- [Generic property wrappers](#generic-wrappers)
	- [Type-specific property wrappers](#typed-wrappers)
	- [Value Modifier arguments](#value-modifiers)
1. [Models](#models)
    - [Mutating models](#mutating)
    - [Comparing models](#comparing)
    - [Copying models](#copying)
    - [Output](#output)
    - [NSCoding](#nscoding)
1. [Goals (in more depth)](#goals)
    1. [Easy to declare in Swift](#easy-to-declare)
    1. [Easy to use](#easy-to-use)
    1. [Speed](#speed)
    1. [Properties defined once](#no-duplication)
    1. [Easy to transform](#easy-to-transform)
    1. [Flexible structure](#flexible)
    1. [Easy to debug](#easy-to-debug)
    1. [Enforceable immutability](#immutability)
    1. [Objective C compatibility](#objc-compatible)
1. [Integration](#integration)
1. [Finally](#finally)


### <a name="rationale"></a>Rationale

`WrapModel` provides structured access to data models received in the form of JSON. Models can be initialized with the JSON string (or Data) directly, or with a data Dictionary. There are a number of solutions out there that provide this sort of functionality, but `WrapModel` was created with several specific goals in mind:

* Easy to declare in Swift
* Easy to use with a similar usage model as direct properties
* Speed - transformation of data happens lazily
* Properties defined once (no second list to maintain)
* Easy to transform data types and enums
* Flexible structure
* Easy to debug
* Enforceable immutability
* Objective C compatibility

These goals are presented in a little more detail below, but here are some of the main ways `WrapModel` meets its goals:

* retaining the original data dictionary
* transforming property data lazily on access
* caching transformed (or mutated) properties to prevent multiple transformations

### <a name="requirements"></a>Requirements

Swift 4.2+ | iOS 10+

Using Property Wrapper based property definitions requires Swift 5.1

### <a name="communication"></a>Communication

- To report bugs or request features, please open an issue.
- If you'd like to contribute changes, please submit a pull request.

### <a name="codable"></a>Why not Codable?

Why write a new solution when Swift itself includes `Codable`? `Codable` is a neat way to convert data to/from model objects by conforming to a protocol. This works well for small, well-defined and consistent data, but the main disadvantages that caused me to overlook it are:

* If one property requires custom decoding, you have to manually define all keys - now you’re basically defining properties in two places
* All transformation of data happens up front - slow transformations happen every time regardless of whether you use that property
* Codable objects are a fairly strict reflection of the structure of the encoded data where I was looking for more flexibility in the structure

### <a name="usage"></a>Usage

Your model class derives from `WrapModel`. Under the hood, each property is a subclass of `WrapProperty` which provides typing and transformation. A number of `WrapProperty` subclasses are provided representing all the basic data types including integers, floating point values, booleans, strings, enums, dates, dictionaries, arrays and submodels (see below).

New property types can be defined by subclassing `WrapProperty` and providing translation to/from closures so data can be transformed into any type.

<a name="usage-example-property-wrappers"></a>**Defining a model object - using property wrappers:**

`WrapModel` provides property wrappers for all its provided property types, each with an immutable and mutable variation. All have optional value modifier arguments that can be used to customize values as they're read from or written to the property if desired.

```swift
// A Customer model definition using property wrappers - for >= Swift 5.1
// Properties are directly readable and writable using property name. E.g. cust.lastName = "Jones"
class Customer: WrapModel {
	@MutStrProperty("last-name") var lastName: String
	@MutStrProperty("first-name") var firstName: String
	@DateProperty("join-date", dateType: .mdySlashes) var joinDate: Date?
	@IntProperty("cust-no") var custNumber: Int
}
```

In addition to the type-specific wrappers provided, two generic property wrappers are available to wrap other WrapProperty subclasses if you create them. Your property object is passed into the wrapper as an argument. The two wrappers let you differentiate between properties that can be read from and written to (`@RWProperty`) and those which should only ever be read (`@ROProperty`). These will also accept optional value modifier closure arguments.

```swift
// A Customer model definition using property wrappers - for >= Swift 5.1
// Properties are directly readable and writable using property name. E.g. cust.lastName = "Jones"
class Customer: WrapModel {
	@RWProperty( CustomClassProperty("last-name-origin")) var lastNameOrigin: MyCustomClass?
}
```
<a name="usage-example-objects-only"></a>**Defining a model object - using WrapProperty objects only:**

It's also possible to use bare property objects and access values via the `value` property on each (from Swift only).
```swift
// Properties are accessible via value member. E.g. cust.lastName.value = "Jones"
class Customer: WrapModel {

    let lastName     = WPStr("last-name")
    let firstName    = WPStr("first-name")
    let lastPurchase = WPDate("most-recent-purchase", dateType: .mdySlashes)
    let custNumber   = WPInt("cust-no")
}
```

<a name="usage-example-accessors"></a>**Defining a model object - using private definitions/public accessors:**

If you can't use Swift 5.1 or later, you can still get Objective C accessibility for properties using a private definition/public accessor pattern. The properties themselves are declared as private and you provide public accessors to access/write the property values. The properties themselves aren't available to Objective C because they're based on Swift generics.

The public accessors are doing the same work that the property wrappers do for us in Swift 5.1 and later.
```swift
// A Customer model definition using private definition/public accessor pattern - Objective C accessible
// Properties are directly readable and writable using property name. E.g. cust.lastName = "Jones".
class Customer: WrapModel {

	// Property definitions
    private let _lastName     = WPStr("last-name")
    private let _firstName    = WPStr("first-name")
    private let _lastPurchase = WPDate("most-recent-purchase", dateType: .mdySlashes)
    private let _custNumber   = WPInt("cust-no")
    
	// ObjC compatible accessors
	var lastName:String { get { return _lastName.value } set { _lastName.value = newValue } }
	var firstName:String { get { return _firstName.value } set { _firstName.value = newValue } }
	var lastPurchase:Date? { get { return _lastPurchase.value } set { _lastPurchase.value = newValue } }
	var custNumber:Int { get { return _custNumber.value } set { _custNumber.value = newValue } }
}
```

<a name="usage-example-initializing"></a>**Initializing a model object:**

No matter how you're model's properties are defined, you initialize it in the same way.

```swift
// If you have a dictionary, you init from that
let custData: [String:Any] = [
	"last-name": "Smith",
	"first-name": "John",
	"cust-no": 12345,
	"join-date": "5/22/2019"
]
let cust = Customer(data: custData, mutable: false)

// or if you have JSON as a String, you can init from that
// WrapModel uses native JSONSerialization to convert to a dictionary
let custJSON: String = """
{
  "last-name":"Smith",
  "first-name":"John",
  "cust-no":12345,
  "join-date":"5/22/2019"
}
"""
let cust = Customer(json: custJSON, mutable: false)
```

### <a name="thread-safety"></a>Thread safety

WrapModel objects are thread safe after creation. Reading and writing properties goes through a locking mechanism that leverages GCD to allow simultaneous reads and blocking writes. Each model has a lock representing a GCD queue which it shares with any child submodels.


## <a name="model-properties"></a>Model Properties


### <a name="key-paths"></a>Key paths

Each property is defined with a **key path** string. This allows the model to find the relevant property data within its data dictionary. While this data is often found at the top level of the dictionary for this model, it doesn't have to be. The key path can be specified as a period-delimited list of keys to dig deeper into the data dictionary.

### <a name="defaults"></a>Default property values

`WrapModel` properties (and Swift properties in general) have types that are either optional or non-optional. When a property's type is non-optional, a default value is needed in case the model's data dictionary contains no value at the given key path. You can specify a default value for the property in its initializer, but logical default-default values are provided. For example, the default for a non-optional integer property is 0 and the defaults for non-optional collection types is an empty array/dict. The default value of optional types is nil.

Example:
```swift
@IntProperty("return-limit", defaultValue: 12) var returnLimit: Int // specified default
@IntProperty("min-purch-num") var minPurchases: Int // default value is zero
@OptDictProperty("statistics") var stats:[String:Any]? // default value is nil
```

### <a name="property-types"></a>Provided property types:

Almost all provided property types have typealiased short names that correspond to a longer name. Both are listed below.

<a name="pt-basic"></a>**Basic Types**

Note that Int and Float require special handling. Simply typecasting a non-integer (like 1.1) will return nil. Also, when a floating point value will often fail to cast as Float due to floating point imprecision that causes the value to only be containable by a Double, so values have to be cast as Doubles first, then downcast to Floats. For Int values, non-integers are rounded.

*Note - Int? is not Objective C compatible.*

| Short name | Data type | Long name | Default value | Property Wrapper |
|---|---|---|---|---|
| `WPInt` | Int | WrapPropertyInt | 0 | [Mut]IntProperty |
| `WPOptInt` | Int? | WrapPropertyOptInt | nil | [Mut]OptIntProperty |
| `WPFloat` | Float | WrapPropertyFloat | 0.0 | [Mut]FloatProperty |
| `WPDouble` | Double | WrapPropertyDouble | 0.0 | [Mut]DoubleProperty |
| `WPBool` | Bool | WrapPropertyBool | false | [Mut]BoolProperty |

<a name="pt-nsnumber"></a>**NSNumber Types**

| Short name | Data type | Long name | Default value | Property Wrapper |
|---|---|---|---|---|
| `WPNumInt` | NSNumber? | WrapPropertyNSNumberInt | nil | [Mut]NumIntProperty |
| `WPNumFloat` | NSNumber? | WrapPropertyNSNumberFloat | nil | [Mut]NumFloatProperty |

<a name="pt-integer-string"></a>**Integer encoded as string**

Input can be either number or string - output is always string. *Note - Int? is not Objective C compatible.*

| Short name | Data type | Long name | Default value | Property Wrapper |
|---|---|---|---|---|
| `WPIntStr` | Int | WrapPropertyIntFromString | 0 | [Mut]IntStrProperty |
| `WPOptIntStr` | Int? | WrapPropertyOptionalIntFromString | nil | [Mut]OptIntStrProperty |

<a name="pt-dictionaries"></a>**Dictionaries**

| Short name | Data type | Long name | Default value | Property Wrapper |
|---|---|---|---|---|
| `WPDict` | [String:Any] | WrapPropertyDict | [:] | [Mut]DictProperty |
| `WPOptDict` | [String:Any]? | WrapPropertyOptional\<[String:Any]> | nil | [Mut]OptDictProperty |

<a name="pt-strings"></a>**Strings**

| Short name | Data type | Long name | Default value | Property Wrapper |
|---|---|---|---|---|
| `WPStr` | String | WrapPropertyString | "" | [Mut]StrProperty |
| `WPOptStr` | String? | WrapPropertyOptional\<String> | nil | [Mut]OptStrProperty |

<a name="pt-enums"></a>**Enums**

Enums are expected to be string values in the JSON. Provide a `WrapConvertibleEnum`-conforming enum as template parameter.

| Short name | Data type | Long name | Default value | Property Wrapper |
|---|---|---|---|---|
| `WPEnum<T>` | T | WrapPropertyConvertibleEnum | specified default or unknown enum | [Mut]EnumProperty / [Mut]EnumUnkProperty |
| `WPOptEnum<T>` | T | WrapPropertyConvertibleOptionalEnum | nil | [Mut]OptEnumProperty |

<a name="pt-submodels"></a>**Submodels**

for `Wrapmodel` subclass types either alone or in a collection

| Short name | Data type | Long name | Default value | Property Wrapper |
|---|---|---|---|---|
| `WPModel<T>` | T? | WrapPropertyModel | nil | [Mut]ModelProperty |
| `WPModelDict<T>` | [String:T] | WrapPropertyDictionaryOfModel | [:] | [Mut]ModelDictProperty |
| `WPOptModelDict<T>` | [String:T]? | WrapPropertyOptionalDictionaryOfModel | nil | [Mut]OptModelDictProperty |

<a name="pt-arrays-of-submodels"></a>**Arrays of submodels**

| Short name | Data type | Long name | Default value | Property Wrapper |
|---|---|---|---|---|
| `WPModelArray<T>` | [T] | WrapPropertyArrayOfModel | [] | [Mut]ModelArrayProperty |
| `WPOptModelArray<T>` | [T]? | WrapPropertyOptionalArrayOfModel | nil | [Mut]OptModelArrayProperty |
| `WPEmbModelArray<T>` | [T] | WrapPropertyArrayOfEmbeddedModel | [] | [Mut]EmbModelArrayProperty |
| `WPOptEmbModelArray<T>` | [T]? | WrapPropertyOptionalArrayOfEmbeddedModel | nil | [Mut]OptEmbModelArrayProperty |

<a name="pt-groups"></a>**Property Groups**

| Short name | Data type | Long name | Default value | Property Wrapper |
|---|---|---|---|---|
| `WPGroup<T>` | T | WrapPropertyGroup | T (non optional) | GroupProperty |

<a name="pt-dates"></a>**Dates**

WPDate is initialized with an enum describing the date encoding type.

| Short name | Data type | Long name | Default value | Property Wrapper |
|---|---|---|---|---|
| `WPDate` | Date? | WrapPropertyDate | nil | [Mut]DateProperty |

<a name="pt-arrays"></a>**Arrays**

Note that Int and Float arrays require special handling. Simply typecasting an array of values that contains a non-integer (like 1.1) will return nil. Also, when a Float array is wanted, values will often fail to cast as Float due to floating point imprecision that causes the value to only be containable by a Double, so values have to be cast as Doubles first, then downcast to Floats.

| Short name | Data type | Long name | Default value | Property Wrapper |
|---|---|---|---|---|
| `WPIntArray` | [Int] | WrapPropertyIntArray | [] | [Mut]IntArrayProperty |
| `WPFloatArray` | [Float] | WrapPropertyFloatArray | [] | [Mut]FloatArrayProperty |
| `WPDoubleArray` | [Double] | WrapPropertyArray\<Double> | [] | [Mut]DoubleArrayProperty |
| `WPStrArray` | [String] | WrapPropertyArray\<String> | [] | [Mut]StrArrayProperty |
| `WPDictArray` | [[String:Any]] | WrapPropertyArray\<[String:Any]> | [] | [Mut]DictArrayProperty |
| `WPOptIntArray` | [Int]? | WrapPropertyOptionalIntArray | nil | [Mut]OptIntArrayProperty |
| `WPOptFloatArray` | [Float]? | WrapPropertyOptionalFloatArray | nil | [Mut]OptFloatArrayProperty |
| `WPOptDoubleArray` | [Double]? | WrapPropertyOptionalArray\<Double> | nil | [Mut]OptDoubleArrayProperty |
| `WPOptStrArray` | [String]? | WrapPropertyOptionalArray\<String> | nil | [Mut]OptStrArrayProperty |
| `WPOptDictArray` | [[String:Any]]? | WrapPropertyOptionalArray\<[String:Any]> | nil | [Mut]OptDictArrayProperty |

<a name="pt-others"></a>**Others**

You can declare a property as an array of any specified type


```swift
WrapPropertyArray<T>
WrapPropertyOptionalArray<T>
```

## <a name="more-about-properties"></a>More about some property types

### <a name="enums"></a>Enum properties

If you have a property that represents an enum type, `WrapModel` provides a property type `WrapPropertyEnum` (typealiased as `WPEnum`) that will handle the conversions for you provided your enum:

* has a RawValue type of `Int`
* conforms to the `WrapConvertibleEnum` protocol

The only requirement to conform to `WrapConvertibleEnum` is that the enum must implement a `conversionDict` function that returns a dictionary in the form `[String:Enum]` where `Enum` is the enum type of the property.

There are three different property wrappers for `WrapConvertibleEnum` conforming enum properties:
- `[Mut]EnumProperty` is non-optional and will yield a specified `defaultEnum` enum value. The default value will be exported to a dictionary or JSON if no other value is explicitly set.
- `[Mut]EnumUnkProperty` is non-optional and yields a specified `unknown` enum value when the model doesn't contain a value, but this `unknown` enum value is never written to the model, even if explicitly set. Unless the `unknown` value was present in the model originally, it should not be exported to a dictionary or JSON.
- `[Mut]OptEnumProperty` is optional and returns nil when no value is present in the model.

### <a name="dates"></a>Date properties

`WrapPropertyDate` (`WPDate`) handles several different formats of dates specified via an enum. Incoming translation from string attempts to decode from the specified date type first, but then also tries all the other types it knows about. Conversion back to string always uses the specified date type.

Date types currently supported are:
```
        dibs               // 2017-02-05T17:03:13.000-03:00
        secondary          // Tue Jun 3 2008 11:05:30 GMT
        iso8601            // 2016-11-01T21:14:33Z
        yyyymmddSlashes    // 2018/02/15
        yyyymmddDashes     // 2018-02-15
        yyyymmdd           // 20180215
        mdySlashes         // 05/06/2018
        mdyDashes          // 05-06-2018
        dmySlashes         // 30/02/2017
        dmyDashes          // 30-02-2017
```

### <a name="embedded-submodel-arrays"></a>Arrays of Embedded Models

In some cases, submodels in an array are buried inside one or more subdictionaries whose only purpose is to wrap the submodel. This often happens when using GraphQL, where models can come wrapped in a "node" dictionary like this:
```
{
	"customers": [
		{
		    "node": {
		    	"first-name": "Harry",
		    	"last-name": "Jones",
		    	"cust-no": 123
		    }
		},
		{
		    "node": {
		    	"first-name": "George",
		    	"last-name": "Black",
		    	"cust-no": 456
		    }
		}
	]
}
```

Using an `WPEmbModelArray` or `WPOptEmbModelArray`, you can avoid creating model classes for these bare wrappers and instead create a property that simply returns an array of the models themselves. Just specify a period-delimited key path for the `embedPath` argument of the property initializer and the property object will automatically dig the models out from one or more levels of wrappers.

The declaration of the customers array property would look like this:
```swift
@ROProperty( WPEmbModelArray<Customer>("customers", embedPath:"node")) var customers:[Customer]
```

### <a name="property-groups"></a>Property Groups

A property group is defined as a submodel, but doesn't go down a level in the data dictionary. This can be useful for two reasons:

1. If you have a model with a large number of properties, many of which are only used in specific circumstances, then the model is creating a large number of property objects that it may not use. These properties can be grouped and defined in submodels even if they reside at the top of the data dictionary.

2. If you have a "flattened" data model with logical subgroups of properties, defining them as groups makes access more logical.

For example, with a flat data dictionary that looks like this:
```
{
  "id": "9107882",
  "profile-firstName": "Sandy",
  "profile-lastName": "Smith",
  "profile-email": "sandy@yahoo.com",
  "profile-company": "Sandy's Stuff",
  "contact-firstName": "David",
  "contact-lastName": "Smith",
  "contact-email": "david@yahoo.com",
  "pref-currency": "USD",
  "pref-measurementUnit": "IN",
}
```

You can create a model that reflects a more logical hierarchy:
```swift
class CustomerModel: WrapModel {

	class Profile: WrapModel {
		@OptStrProperty("profile-firstName") var firstName:String?
		@OptStrProperty("profile-lastName") var lastName:String?
		@OptStrProperty("profile-email") var email:String?
		@OptStrProperty("profile-company") var company:String?
	}
	
	class Contact: WrapModel {
		@OptStrProperty("contact-firstName") var firstName:String?
		@OptStrProperty("contact-lastName") var lastName:String?
		@OptStrProperty("contact-email") var email:String?
	}
	
	class Prefs: WrapModel {
		@MutEnumProperty("pref-currency", defaultEnum: .usd) var currency:CurrencyEnum
		@MutEnumProperty("pref-measurementUnit", defaultEnum: .inches) var measurementUnit:MeasurementUnitEnum
	}
	
	@OptStrProperty("id") var id:String?
	@GroupProperty() var profile:Profile
	@GroupProperty() var contact:Contact
	@GroupProperty() var pref:Prefs
}
```

Now, accessing the model looks more natural and the property objects inside the groups aren't actually created until a property in the group is accessed.
```swift
var cust: CustomerModel
print("Contact is: \(cust.contact.firstName)")
print("Company is: \(cust.profile.company)")
cust.pref.measurementUnit = .cm
```

### <a name="serialization-modes"></a>Property serialization

Each WrapProperty has a `serializeForOutput` member that determines whether it should be emitted when serializing for output to JSON. By default, this is set to true but you can prevent a property from being emitted when serialized for output by specifying false in the property's declaration/initialization.

### <a name="custom-properties"></a>Custom properties

You can create new subclasses of `WrapProperty` for whatever property types you need. You only need to provide to and from transformation closures:

```swift
// If you want a property of this type based on a data string:
class MyDataType {
	let myStringValue:String
	init(strData:String) {
		myStringValue = strData
	}
}

// Create a WrapProperty subclass that transforms back and forth between String and MyDataType
class MyDataTypeProperty: WrapProperty<MyDataType?> {
	init(_ keyPath: String) {
		super.init(keyPath, defaultValue: nil, serializeForOutput: true)
		self.toModelConverter = { (jsonValue:Any) -> MyDataType? in
			// Convert dictionary/JSON data to custom property type
			guard let str = jsonValue as? String else { return nil }
			return MyDataType(strData: str)
		}
		self.fromModelConverter = { (nativeValue:MyDataType?) -> Any? in {
			// Convert property data to format that goes in dictionary/JSON
			return nativeValue?.myStringValue 
		}
	}
}

// Then use it in a model class:
class MyModel: WrapModel {
	@ROProperty( MyDataTypeProperty("dataString")) var dataProperty:MyDataType?
}
```


## <a name="wrappers-and-modifiers"></a>Property Wrappers & Value Modifiers

### <a name="generic-wrappers"></a>Generic property wrappers

Declaring your properties using property wrappers requires Swift 5.1 or later.

Two generic property wrappers, `ROProperty` and `RWProperty`, are provided which can be used to wrap any WrapProperty type. The WrapProperty instance is passed in as the first argument to the property wrapper like this:

```swift
class MyModel: WrapModel {
	@ROProperty( MyDataTypeProperty("dataString")) var dataProperty:MyDataType?
}
```

`ROProperty` is for immutable (read only) properties and provides no setter. `RWProperty` allows mutation of the property (assuming the model itself is mutable).

### <a name="typed-wrappers"></a>Type-specific property wrappers

Property wrappers are also provided for most all of the WrapProperty subclasses included in the library.
The arguments for each property wrapper can vary by property type; for example, a `defaultValue` argument can be specified for `StrProperty`. For the most part, the type necessary for property wrappers that are generic, like `ModelProperty<T>` can be gleaned by the compiler from the remainder of the declaration, so there's no need to put the type in angle brackets. Type-specific property wrappers don't require a WrapProperty instance to be passed in. They're created inside the wrapper.
```swift
@StrProperty("stringPath") var someString: String
@ModelProperty("modelPath") var submodel: ModelClass // no need to put <ModelClass> after @ModelProperty
```

All provided property wrappers have an immutable and a mutable variant. They follow the naming convention of including `Mut` at the beginning of the name for mutable variants. For example, `StrProperty` is immutable, while `MutStrProperty` allows the property value to be changed (mutable).

### <a name="value-modifiers"></a>Value modifier arguments

Each provided property wrapper, from the more generic `ROProperty` and `RWProperty` to the more type-specific ones like `StrProperty` and `IntProperty`, all take optional closure arguments that can modify the property value when accessed or written.

These arguments all have the signature `(propertyType)->propertyType` where the closure receives the value and returns the same or a modified version of the value.

Immutable property wrappers accept a `modifier` argument that is passed the model's current property value and has a chance to modify it before it is passed along to the caller. This is an optional argument that, by default, passes the value through unmodified.

Mutable property wrappers accept `getModifier` and `setModifier` arguments that are called when getting the model value and setting the model value. These are optional arguments that, by default, pass the value through unmodified.

## <a name="models"></a>Models


### <a name="mutating"></a>Mutating

Most of the model objects we use are immutable, but occasionally the need arises for mutability. A `WrapModel` object can be created in a mutable state, or a mutable copy can be made:

```
// If you need a mutable copy
// You can initialize a model from another (with or without its mutations if it was mutable)
let mutableCust = Customer(asCopyOf: cust, withMutations: true, mutable: true)

// Or by using WrapModel's mutableCopy method which returns an Any?
let mutableCust = cust.mutableCopy() as? Customer
```

### <a name="comparing"></a>Comparing

`WrapModel` conforms to Equatable, so models of the same type can be compared using the `==` operator in Swift or `isEqual:` or `isEqualToModel:` in Objective C. Default implementations of these comparisons create dictionaries using the model properties and current data values, then compare the dictionaries.

These comparison methods may (and probably should) be overridden in specific model subclasses in order to make the comparison more specific to the data involved.

### <a name="copying"></a>Copying models

`WrapModel` conforms to NSCopying, so you can produce copies using `copy()` and `mutableCopy()` but you'll have to typecast the result since those return `Any`.

You can also instantiate a copy using the copy initializer `init(asCopyOf:WrapModel, withMutations:Bool, mutable:Bool)`. This will produce a typed copy of the given model and you can choose whether the created model is mutable and whether it includes any mutations made to the given model.

### <a name="output"></a>Output

If you need the model's current data dictionary to, for example, post to a server endpoint, the model's `currentModelData()` function will build and return it. This returns a dictionary containing only data for the properties defined by the model, even if the dictionary used to initialize the model contained additional data.

`currentModelData()` takes two parameters that alter how the dictionary is built:

1. `withNulls: Bool` - if true, model properties with no value will emit an NSNull into the data dictionary, which will translate into a nil value if converted to JSON.
2. `forOutput: Bool` - if true, only those model properties whose `serializeForOutput` flag is true will be emitted. This parameter defaults to true.

`currentModelDataAsJSON(withNulls:Bool)` is also available and returns a JSON string including only model properties whose `serializeForOutput` flag is true.

### <a name="nscoding"></a>NSCoding

`WrapModel` conforms to `NSCoding` so you can use classes like `NSKeyedArchiver` and `NSKeyedUnarchiver` to archive and unarchive model objects.

## <a name="goals"></a>Goals
(in more depth)

#### <a name="easy-to-declare"></a> Easy to declare in Swift

Property declarations are generally short and require only the `WrapProperty` subclass and key path. The private/public declaration pattern, while more verbose, makes the public interface and types very clear.

#### <a name="easy-to-use"></a> Easy to use with a similar usage model as direct properties

Using a `WrapModel`-based model object is very similar to using direct properties, especially if you use the private/public declaration pattern.

#### <a name="speed"></a> Speed - transformation of data happens lazily

By putting off transformations until data is needed, `WrapModel` avoids a lot of the time usually taken in transforming a data dictionary into a model object. This is especially true for models that are never mutated and models with many transformed properties.

#### <a name="no-duplication"></a> Properties defined once (no second list to maintain)

With Swift 5.1, properties are declared once using a property wrapper (`@ROProperty` or `@RWProperty`). This is the simplest and most straightforward method and provides both Objective C accessibility and compiler enforced immutability of properties when desired.

With usage in Swift only (<5.1), it is possible to define properties once and use them directly via their value member. The property declaration is self-contained and doesn't require a declaration in one place and specification of transformation method somewhere else.

If you can't use Swift 5.1 or later, you may also choose to use the private property definition/public accessor declaration pattern for Objective C compatibility, compiler-enforced immutability, or for other reasons. The two related declarations are closely tied so it's impossible for one to be forgotten and still use the property.

#### <a name="easy-to-transform"></a> Easy to transform data types and enums

The provided `WrapProperty` subclasses cover the vast majority of data types needed for most models. At the same time, it's quite easy to create your own subclasses of `WrapProperty` to use with custom types.

The subclass need only provide a `toModelConverter` closure that converts the data dictionary type into the model type, and a `fromModelConverter` closure that does the opposite.

#### <a name="flexible"></a> Flexible structure

The structure of a `WrapModel`'s properties does not have to be closely tied to the structure of its data dictionary. It's easy for properties to reach down into deeply nested members of the data dictionary, so creation of many submodel types isn't required in many cases unless it serves your purposes.

You can also create property groups to logically group properties into submodels even if they all reside in the same level of the data dictionary.

#### <a name="easy-to-debug"></a> Easy to debug

Debugging is facilitated by `WrapModel`'s separation of the original data dictionary from mutations. The model even holds onto the original JSON string when debugging (if initialized from JSON string or data).

#### <a name="immutability"></a> Enforceable immutability

A model created as not mutable will not allow its values to be changed and will assert when debugging if an attempt is made to mutate an immutable model object.

#### <a name="objc-compatible"></a> Objective C compatibility

With Swift 5.1, property wrappers provide easy Objective C compatibility.

For versions of Swift prior to 5.1, although models must be defined in Swift, it only requires a bit more work to gain complete usability of WrapModel objects from Objective C code using the private property definition/public accessor pattern.


## <a name="integration"></a>Integration

#### CocoaPods (iOS 10+, Swift 4.2+)

You can use [CocoaPods](http://cocoapods.org/) to install `WrapModel` by adding it to your `Podfile`:

```ruby
platform :ios, '10.0'
use_frameworks!

target 'MyApp' do
    pod 'WrapModel', '~> 1.0'
end
```

#### Manual (iOS 10+, Swift 4.2+)

Since `WrapModel` is comprised of just a couple Swift source files, you could download them and compile them into your project manually.

## <a name="finally"></a>Finally


I wrote `WrapModel` to meet all our goals at 1stdibs when we wanted to transition from Objective C Mantle-based models to something Swift-centric. As of March 2019, we've been using `WrapModel` in the 1stdibs production iOS app for about 6-8 months as we gradually make the transition. We have a fairly simple protocol-based system that allows us to use mixed `WrapModel` and Mantle based models together, so we weren't forced to transition everything at once.

Significant contributions to the initial implementation were also made by [Gal Cohen](https://github.com/GalCohen).

Now, the whole mobile engineering team at 1stdibs uses and maintains `WrapModel` and, hopefully, you will too.

Happy Developing!

[Ken Worley](https://github.com/KenWorley)
