

<p align="center">
<img src="https://img.shields.io/cocoapods/p/WrapModel.svg" alt="Platform">
<img src="https://img.shields.io/github/license/1stdibs/WrapModel.svg" alt="License">
<img src="https://img.shields.io/cocoapods/v/WrapModel.svg" alt="Version">	
</p>

# WrapModel
WrapModel wraps JSON format data in string or Dictionary form with a model interface.

1. [Description](#description)
1. [Requirements](#requirements)
1. [Communication](#communication)
1. [Why not Codable?](#codable)
1. [Usage](#usage)
	- [usage example](#usage-example)
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
	    1. [Property Groups](#pt-groups)
	    1. [Dates](#pt-dates)
	    1. [Arrays](#pt-arrays)
	    1. [Others](#pt-others)
    - [More about some property types](#more-about-properties)
	    - [Enum properties](#enums)
	    - [Date properties](#dates)
	    - [Property Groups](#property-groups)
    - [Accessing property data](#accessing-properties)
    - [Property serialization](#serialization-modes)
    - [Custom properties](#custom-properties)
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


### <a name="description"></a>Description

`WrapModel` is a data modeling class written in Swift whose main purpose is to provide structured access to data models received in the form of JSON. Models can be initialized with the JSON string (or Data) directly, or with a data Dictionary. There are a number of solutions out there that provide this sort of functionality, but `WrapModel` was created with several specific goals in mind:

* Easy to declare in Swift
* Easy to use with a similar usage model as direct properties
* Speed - transformation of data happens lazily
* Properties defined once (no second list to maintain)
* Easy to transform data types and enums
* Flexible structure
* Easy to debug
* Enforceable immutability
* Objective C compatibility

I’ll go over these goals in a little more detail below, after the usage description, but some of the main ways `WrapModel` meets its goals is by:

* retaining the original data dictionary
* transforming property data lazily on access
* caching transformed (or mutated) properties to prevent multiple transformations

### <a name="requirements"></a>Requirements

Swift 4.2+ | iOS 10+

### <a name="communication"></a>Communication

- To report bugs or request features, please open an issue.
- If you'd like to contribute changes, please submit a pull request.

### <a name="codable"></a>Why not Codable?

Why write a new solution when Swift itself includes `Codable`? `Codable` is a neat way to convert data to/from model objects by conforming to a protocol. This works well for small, well-defined and consistent data, but the main disadvantages that caused me to overlook it are:

* If one property requires custom decoding, you have to manually define all keys - now you’re basically defining properties in two places
* All transformation of data happens up front - slow transformations happen every time regardless of whether you use that property
* Codable objects are a fairly strict reflection of the structure of the encoded data where I was looking for more flexibility in the structure

### <a name="usage"></a>Usage

Your model class derives from `WrapModel`. Each property is a subclass of `WrapProperty` which provides typing and transformation. A number of `WrapProperty` subclasses are provided representing all the basic data types including integers, floating point values, booleans, strings, enums, dates, dictionaries, arrays and submodels (see below).

New property types can be defined by subclassing `WrapProperty` and providing translation to/from closures so data can be transformed into any type.

<a name="usage-example"></a>**Here’s a basic example:**

```swift
class Customer: WrapModel {
	let lastName = WPOptStr("last_name")
	let firstName = WPOptStr("first_name")
	let custNumber = WPInt("customer_identifier")
	let joinDate = WPDate("date_joined", dateType: .iso8601)
}

// If you have a dictionary, you init from that
let custData: [String:Any]
let cust = Customer(data: custData, mutable: false)

// or if you have JSON as a String, you can init from that
// WrapModel uses native JSONSerialization to convert to a dictionary
let custJSON: String
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
let returnLimit:Int = WPInt("return-limit", defaultValue: 12)
let minPurchases:Int = WPInt("min-purch-num") // default value is zero
let stats:[String:Any]? = WPOptDict("statistics") // default value is nil
```

### <a name="property-types"></a>Provided property types:

Almost all provided property types have typealiased short names that correspond to a longer name. Both are listed below.

<a name="pt-basic"></a>**Basic Types**

Note that Int and Float require special handling. Simply typecasting a non-integer (like 1.1) will return nil. Also, when a floating point value will often fail to cast as Float due to floating point imprecision that causes the value to only be containable by a Double, so values have to be cast as Doubles first, then downcast to Floats. For Int values, non-integers are rounded.

*Note - Int? is not Objective C compatible.*

| Short name | Data type | Long name | Default value |
|---|---|---|---|
| `WPInt` | Int | WrapPropertyInt | 0 |
| `WPOptInt` | Int? | WrapPropertyOptInt | nil |
| `WPFloat` | Float | WrapPropertyFloat | 0.0 |
| `WPDouble` | Double | WrapPropertyDouble | 0.0 |
| `WPBool` | Bool | WrapPropertyBool | false |

<a name="pt-nsnumber"></a>**NSNumber Types**

| Short name | Data type | Long name | Default value |
|---|---|---|---|
| `WPNumInt` | NSNumber? | WrapPropertyNSNumberInt | nil |
| `WPNumFloat` | NSNumber? | WrapPropertyNSNumberFloat | nil |

<a name="pt-integer-string"></a>**Integer encoded as string**

Input can be either number or string - output is always string. *Note - Int? is not Objective C compatible.*

| Short name | Data type | Long name | Default value |
|---|---|---|---|
| `WPIntStr` | Int | WrapPropertyIntFromString | 0 |
| `WPOptIntStr` | Int? | WrapPropertyOptionalIntFromString | nil |

<a name="pt-dictionaries"></a>**Dictionaries**

| Short name | Data type | Long name | Default value |
|---|---|---|---|
| `WPDict` | [String:Any] | WrapPropertyDict | [:] |
| `WPOptDict` | [String:Any]? | WrapPropertyOptional\<[String:Any]> | nil |

<a name="pt-strings"></a>**Strings**

| Short name | Data type | Long name | Default value |
|---|---|---|---|
| `WPStr` | String | WrapPropertyString | "" |
| `WPOptStr` | String? | WrapPropertyOptional\<String> | nil |

<a name="pt-enums"></a>**Enums**

Enums are expected to be string values in the JSON. Provide a `WrapConvertibleEnum`-conforming enum as template parameter.

| Short name | Data type | Long name | Default value |
|---|---|---|---|
| `WPEnum<T>` | T | WrapPropertyConvertibleEnum | specified default enum |

<a name="pt-submodels"></a>**Submodels**

for `Wrapmodel` subclass types either alone or in a collection

| Short name | Data type | Long name | Default value |
|---|---|---|---|
| `WPModel<T>` | T? | WrapPropertyModel | nil |
| `WPModelArray<T>` | [T] | WrapPropertyArrayOfModel | [] |
| `WPOptModelArray<T>` | [T]? | WrapPropertyOptionalArrayOfModel | nil |
| `WPModelDict<T>` | [String:T] | WrapPropertyDictionaryOfModel | [:] |
| `WPOptModelDict<T>` | [String:T]? | WrapPropertyOptionalDictionaryOfModel | nil |

<a name="pt-groups"></a>**Property Groups**

| Short name | Data type | Long name | Default value |
|---|---|---|---|
| `WPGroup<T>` | T | WrapPropertyGroup | T (non optional) |

<a name="pt-dates"></a>**Dates**

WPDate is initialized with an enum describing the date encoding type.

| Short name | Data type | Long name | Default value |
|---|---|---|---|
| `WPDate` | Date? | WrapPropertyDate | nil |

<a name="pt-arrays"></a>**Arrays**

Note that Int and Float arrays require special handling. Simply typecasting an array of values that contains a non-integer (like 1.1) will return nil. Also, when a Float array is wanted, values will often fail to cast as Float due to floating point imprecision that causes the value to only be containable by a Double, so values have to be cast as Doubles first, then downcast to Floats.

| Short name | Data type | Long name | Default value |
|---|---|---|---|
| `WPIntArray` | [Int] | WrapPropertyIntArray | [] |
| `WPFloatArray` | [Float] | WrapPropertyFloatArray | [] |
| `WPDoubleArray` | [Double] | WrapPropertyArray\<Double> | [] |
| `WPStrArray` | [String] | WrapPropertyArray\<String> | [] |
| `WPDictArray` | [[String:Any]] | WrapPropertyArray\<[String:Any]> | [] |
| `WPOptIntArray` | [Int]? | WrapPropertyOptionalIntArray | nil |
| `WPOptFloatArray` | [Float]? | WrapPropertyOptionalFloatArray | nil |
| `WPOptDoubleArray` | [Double]? | WrapPropertyOptionalArray\<Double> | nil |
| `WPOptStrArray` | [String]? | WrapPropertyOptionalArray\<String> | nil |
| `WPOptDictArray` | [[String:Any]]? | WrapPropertyOptionalArray\<[String:Any]> | nil |

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
		let firstName = WPOptStr("profile-firstName")
		let lastName = WPOptStr("profile-lastName")
		let email = WPOptStr("profile-email")
		let company = WPOptStr("profile-company")
	}
	
	class Contact: WrapModel {
		let firstName = WPOptStr("contact-firstName")
		let lastName = WPOptStr("contact-lastName")
		let email = WPOptStr("contact-email")
	}
	
	class Prefs: WrapModel {
		let currency = WPEnum<CurrencyEnum>("pref-currency", defaultEnum: .usd)
		let measurementUnit = WPEnum<MeasurementUnitEnum>("pref-measurementUnit", defaultEnum: .inches)
	}
	
	let id = WPOptStr("id")
	let profile = WPGroup<Profile>()
	let contact = WPGroup<Contact>()
	let pref = WPGroup<Prefs>()
}
```

Now, accessing the model looks more natural and the property objects inside the groups aren't actually created until a property in the group is accessed.
```swift
var cust: CustomerModel
print("Contact is: \(cust.contact.firstName)")
print("Company is: \(cust.profile.company)")
cust.pref.measurementUnit = .cm
```

### <a name="accessing-properties"></a>Accessing property data

```swift
// To access a property, read its value member
if let lname = cust.lastName.value, let fname = cust.firstName.value {
	let wholeName = fname + " " + lname
}

// To modify a property (assuming the model is mutable)
// modify its value member
cust.firstName.value = "Fred"
```

Accessing properties via a nested value member is slightly awkward and, you might have noticed, incompatible with Objective C since `WrapProperty` is a templated type. A private/public declaration pattern can be used to address both of these issues where an internal private `WrapProperty` is declared and a public accessor is provided.

```swift
class Customer: WrapModel {
	private let _lastName = WPOptStr("last_name")
	private let _firstName = WPOptStr("first_name")
	private let _custNumber = WPInt("customer_identifier")
	private let _joinDate = WPDate("date_joined", dateType: .iso8601)
	
	// Mutable properties
	var lastName: String { get { return _lastName.value } set { _lastName.value = newValue } }
	var firstName: String { get { return _firstName.value } set { _firstName.value = newValue } }
	
	// Immutable properties
	var custNumber: Int { return _custNumber.value }
	var joinDate: Date? { return _joinDate.value }
}
```


This pattern has the added advantages of providing compiler-level immutability for properties that should never be changed and more explicit surfacing of the actual data type. While it does require you to “double-define” properties, it’s done in a way that’s more difficult to screw up than some other schemes.

In addition, smaller on-the-fly transformations, aggregation, or other logic can occur in these public accessors. For example:

```swift
	var formattedName: String {
		if let lname = self.lastName {
			return (self.firstName ?? "Mr/Mrs") + " " + lname
		} else {
			return self.firstName ?? "none"
		}
	}
```

And, these public accessors are, of course, **Objective C** compatible.

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
	let dataProperty = MyDataTypeProperty("dataString")
}
```

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

With usage in Swift, it is possible to define properties once and use them directly via their value member. The property declaration is self-contained and doesn't require a declaration in one place and specification of transformation method somewhere else.

Even if you choose to use the private/public declaration pattern for Objective C compatibility, compiler-enforced immutability, or for other reasons, the two related declarations are closely tied so it's impossible for one to be forgotten and still use the property.

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

Although models must be defined in Swift, it only requires a bit more work to gain complete  usability of WrapModel objects from Objective C code.


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
