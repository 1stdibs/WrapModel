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
    - [More about some property types](#more-about-properties)
	    - [Enum properties](#enums)
	    - [Date properties](#dates)
	    - [Property Groups](#property-groups)
    - [Accessing property data](#accessing-properties)
    - [Property serialization modes](#serialization-modes)
1. [Models](#models)
    - [Mutating models](#mutating)
    - [Comparing models](#comparing)
    - [Output](#output)
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
1. [Finally](#finally)


##### <a name="description"></a>Description

`WrapModel` is a data modeling class written in Swift whose main purpose is to provide structured access to data models received in the form of JSON. Models can be initialized with the JSON string (or Data) directly, or with a data Dictionary. There are a number of solutions out there that provide this sort of functionality, but I wrote `WrapModel` with several specific goals in mind:

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

##### <a name="requirements"></a>Requirements

Swift 4.2+ | iOS 10+

##### <a name="communication"></a>Communication

- To report bugs or request features, please open an issue.
- If you'd like to contribute changes, please submit a pull request.

##### <a name="codable"></a>Why not Codable?

Why write a new solution when Swift itself includes `Codable`? `Codable` is a neat way to convert data to/from model objects by conforming to a protocol. This works well for small, well-defined and consistent data, but the main disadvantages that caused me to overlook it are:

* If one property requires custom decoding, you have to manually define all keys - now you’re basically defining properties in two places
* All transformation of data happens up front - slow transformations happen every time regardless of whether you use that property
* Codable objects are a fairly strict reflection of the structure of the encoded data where I was looking for more flexibility in the structure

##### <a name="usage"></a>Usage

Your model class derives from `WrapModel`. Each property is a subclass of `WrapProperty` which provides typing and transformation. A number of `WrapProperty` subclasses are provided representing all the basic data types including integers, floating point values, booleans, strings, enums, dates, dictionaries, arrays and submodels (see below).

New property types can be defined by subclassing `WrapProperty` and providing translation to/from closures so data can be transformed into any type.

<a name="usage-example"></a>**Here’s a basic example:**

```
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

#### <a name="thread-safety"></a>Thread safety

WrapModel objects are thread safe after creation. Reading and writing properties goes through a locking mechanism that leverages GCD to allow simultaneous reads and blocking writes. Each model has a lock representing a GCD queue which it shares with any child submodels.


## <a name="model-properties"></a>Model Properties


#### <a name="key-paths"></a>Key paths

Each property is defined with a **key path** string. This allows the model to find the relevant property data within its data dictionary. While this data is often found at the top level of the dictionary for this model, it doesn't have to be. The key path can be specified as a period-delimited list of keys to dig deeper into the data dictionary.

#### <a name="defaults"></a>Default property values

`WrapModel` properties (and Swift properties in general) have types that are either optional or non-optional. When a property's type is non-optional, a default value is needed in case the model's data dictionary contains no value at the given key path. You can specify a default value for the property in its initializer, but logical default-default values are provided. For example, the default for a non-optional integer property is 0 and the defaults for non-optional collection types is an empty array/dict. The default value of optional types is nil.

Example:
```
let returnLimit = WPInt("return-limit", defaultValue: 12)
let minPurchases = WPInt("min-purch-num") // default value is zero
```

#### <a name="property-types"></a>Provided property types:

These are typealiased shorter names that represent more verbose actual property class names.

<a name="pt-basic"></a>**Basic types** - nonoptional with default values
```
WPInt      Int with default value of 0 (aka WrapPropertyInt)
WPOptInt   Int? (not ObjC compatible) (aka WrapPropertyOptionalInt)
WPFloat    Float with default value of 0.0 (aka WrapPropertyFloat)
WPDouble   Double with default value of 0.0 (aka WrapPropertyDouble)
WPBool     Boolean with default value of false (aka WrapPropertyBool)
WPOptBool  WPBoolean enum - default value .notSet (aka WrapPropertyOptionalBool)
```

<a name="pt-nsnumber"></a>**NSNumber types**
```
WPNumInt   NSNumber? (outputs as Int to JSON) (aka WrapPropertyNSNumberInt)
WPNumFloat NSNumber? (outputs as Float to JSON) (aka WrapPropertyNSNumberFloat)
```

<a name="pt-integer-string"></a>**Integer** encoded as string - nonoptional
```
WPIntStr   Int with default value of 0 (aka WrapPropertyIntFromString)
```

<a name="pt-dictionaries"></a>**Dictionaries** - both optional and nonoptional
```
WPDict     [String:Any] with default value of empty dictionary (aka WrapPropertyDict)
WPOptDict  [String:Any]? (aka WrapPropertyOptional<[String:Any]>
```

<a name="pt-strings"></a>**Strings** - both optional and nonoptional
```
WPStr      String with default value of empty string (aka WrapPropertyString)
WPOptStr   String? (aka WrapPropertyOptional<String>)
```

<a name="pt-enums"></a>**Enums** encoded as string - provide WrapConvertibleEnum-conforming enum as template parameter
```
WPEnum<T> (aka WrapPropertyConvertibleEnum)
```

<a name="pt-submodels"></a>**Submodels** - for `WrapModel` subclass types either alone or in an array or dictionary
```
WPModel<T>          submodel of type T - always optional (aka WrapPropertyModel)
WPModelArray<T>     [T] - specify model type - default value empty array (aka WrapPropertyArrayOfModel)
WPOptModelArray<T>  [T]? - specify model type (aka WrapPropertyOptionalArrayOfModel)
WPModelDict<T>      [String:T] - default value [:] (aka WrapPropertyDictionaryOfModel)
WPOptModelDict<T>   [String:T]? (aka WrapPropertyOptionalDictionaryOfModel)
```

<a name="pt-groups"></a>**Property Groups**
```
WPGroup<T>       group properties using a submodel of type T (see below) (aka WrapPropertyGroup)
```

<a name="pt-dates"></a>**Dates**
```
WPDate    Date? (aka WrapPropertyDate)
```

<a name="pt-arrays"></a>**Arrays** of basic types - optional or nonoptional with default value of empty array
```
WPIntArray       [Int]           (aka WrapPropertyArray<Int>)
WPFloatArray     [Float]         (aka WrapPropertyArray<Float>)
WPStrArray       [String]        (aka WrapPropertyArray<String>)
WPDictArray      [[String:Any]   (aka WrapPropertyArray<[String:Any]>
```

```
WPOptIntArray    [Int]?          (aka WrapPropertyOptionalArray<Int>)
WPOptFloatArray  [Float]?        (aka WrapPropertyOptionalArray<Float>)
WPOptStrArray    [String]?       (aka WrapPropertyOptionalArray<String>)
WPOptDictArray   [[String:Any]]? (aka WrapPropertyOptionalArray<[String:Any]>)
```

And, of course, you can declare a property as an array of any specified type:
```
WrapPropertyArray<T>
WrapPropertyOptionalArray<T>
```

### <a name="more-about-properties"></a>More about some property types

#### <a name="enums"></a>Enum properties

If you have a property that represents an enum type, `WrapModel` provides a property type `WrapPropertyEnum` (typealiased as `WPEnum`) that will handle the conversions for you provided your enum:

* has a RawValue type of `Int`
* conforms to the `WrapConvertibleEnum` protocol

The only requirement to conform to `WrapConvertibleEnum` is that the enum must implement a `conversionDict` function that returns a dictionary in the form `[String:Enum]` where `Enum` is the enum type of the property.

#### <a name="dates"></a>Date properties

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

#### <a name="property-groups"></a>Property Groups

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
```
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
```
var cust: CustomerModel
print("Contact is: \(cust.contact.firstName)")
print("Company is: \(cust.profile.company)")
cust.pref.measurementUnit = .cm
```

#### <a name="accessing-properties"></a>Accessing property data

```
// To access a property, read its value member
if let lname = cust.lastName.value, let fname = cust.firstName.value {
	let wholeName = fname + " " + lname
}

// To modify a property (assuming the model is mutable)
// modify its value member
cust.firstName.value = "Fred"
```

Accessing properties via a nested value member is slightly awkward and, you might have noticed, incompatible with Objective C since `WrapProperty` is a templated type. A private/public declaration pattern can be used to address both of these issues where an internal private `WrapProperty` is declared and a public accessor is provided.

```
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

```
	var formattedName: String {
		if let lname = self.lastName {
			return (self.firstName ?? "Mr/Mrs") + " " + lname
		} else {
			return self.firstName ?? "none"
		}
	}
```

And, these public accessors are, of course, **Objective C** compatible.

#### <a name="serialization-modes"></a>Property serialization modes

Each WrapProperty has a `serialize` member that describes its serialization mode. This indicates whether the property's value should be emitted when serializing the model back into a dictionary or JSON string. By default, this is set to `.always` but you can prevent a property from being emitted when serialized for output by specifying `.never` in the property's declaration/initialization.


## <a name="models"></a>Models


#### <a name="mutating"></a>Mutating

Most of the model objects we use are immutable, but occasionally the need arises for mutability. A `WrapModel` object can be created in a mutable state, or a mutable copy can be made:

```
// If you need a mutable copy
// You can initialize a model from another (with or without its mutations if it was mutable)
let mutableCust = Customer(asCopyOf: cust, withMutations: true, mutable: true)

// Or by using WrapModel's mutableCopy method which returns an Any?
let mutableCust = cust.mutableCopy as? Customer
```

#### <a name="comparing"></a>Comparing

`WrapModel` conforms to Equatable, so models of the same type can be compared using the `==` operator in Swift or `isEqual:` or `isEqualToModel:` in Objective C. Default implementations of these comparisons create dictionaries using the model properties and current data values, then compare the dictionaries.

These comparison methods may (and probably should) be overridden in specific model subclasses in order to make the comparison more specific to the data involved.

#### <a name="output"></a>Output

If you need the model's current data dictionary to, for example, post to a server endpoint, the model's `currentModelData()` function will build and return it. This returns a dictionary containing only data for the properties defined by the model, even if the dictionary used to initialize the model contained additional data.

`currentModelData()` takes two parameters that alter how the dictionary is built:

1. `withNulls: Bool` - if true, model properties with no value will emit an NSNull into the data dictionary, which will translate into a nil value if converted to JSON.
2. `forSerialization: Bool` - if true, only those model properties whose serialization mode is `.always`

`currentModelDataAsJSON(withNulls:Bool)` is also available and returns a JSON string including only model properties whose serialization mode is `.always`

If you'd like the current data as a JSON string, `currentModelDataAsJSON` will return that.

The `jsonDictionaryWithoutNulls()` function provides the same functionality, calling through to `currentModelData()` and assuming the output is for serialization.

## <a name="goals"></a>Goals
(in more depth)

##### <a name="easy-to-declare"></a> Easy to declare in Swift

Property declarations are generally short and require only the `WrapProperty` subclass and key path. The private/public declaration pattern, while more verbose, makes the public interface and types very clear.

##### <a name="easy-to-use"></a> Easy to use with a similar usage model as direct properties

Using a `WrapModel`-based model object is very similar to using direct properties, especially if you use the private/public declaration pattern.

##### <a name="speed"></a> Speed - transformation of data happens lazily

By putting off transformations until data is needed, `WrapModel` avoids a lot of the time usually taken in transforming a data dictionary into a model object. This is especially true for models that are never mutated and models with many transformed properties.

##### <a name="no-duplication"></a> Properties defined once (no second list to maintain)

With usage in Swift, it is possible to define properties once and use them directly via their value member. The property declaration is self-contained and doesn't require a declaration in one place and specification of transformation method somewhere else.

Even if you choose to use the private/public declaration pattern for Objective C compatibility, compiler-enforced immutability, or for other reasons, the two related declarations are closely tied so it's impossible for one to be forgotten and still use the property.

##### <a name="easy-to-transform"></a> Easy to transform data types and enums

The provided `WrapProperty` subclasses cover the vast majority of data types needed for most models. At the same time, it's quite easy to create your own subclasses of `WrapProperty` to use with custom types.

The subclass need only provide a `toModelConverter` closure that converts the data dictionary type into the model type, and a `fromModelConverter` closure that does the opposite.

##### <a name="flexible"></a> Flexible structure

The structure of a `WrapModel`'s properties does not have to be closely tied to the structure of its data dictionary. It's easy for properties to reach down into deeply nested members of the data dictionary, so creation of many submodel types isn't required in many cases unless it serves your purposes.

You can also create property groups to logically group properties into submodels even if they all reside in the same level of the data dictionary.

##### <a name="easy-to-debug"></a> Easy to debug

Debugging is facilitated by `WrapModel`'s separation of the original data dictionary from mutations. The model even holds onto the original JSON string when debugging (if initialized from JSON string or data).

##### <a name="immutability"></a> Enforceable immutability

A model created as not mutable will not allow its values to be changed and will assert when debugging if an attempt is made to mutate an immutable model object.

##### <a name="objc-compatible"></a> Objective C compatibility

Although models must be defined in Swift, it only requires a bit more work to gain complete  usability of WrapModel objects from Objective C code.


## <a name="finally"></a>Finally


I wrote `WrapModel` to meet all our goals at 1stdibs when we wanted to transition from Objective C Mantle-based models to something Swift-centric. As of March 2019, we've been using `WrapModel` in the 1stdibs production iOS app for about 6-8 months as we gradually make the transition. We have a fairly simple protocol-based system that allows us to use mixed `WrapModel` and Mantle based models together, so we weren't forced to transition everything at once.

Significant contributions to the initial implementation were also made by [Gal Cohen](https://github.com/GalCohen).

Now, the whole mobile engineering team at 1stdibs uses and maintains `WrapModel` and, hopefully, you will too.

Happy Developing!

[Ken Worley](https://github.com/KenWorley)