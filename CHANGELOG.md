# WrapModel change log

 

Changes in reverse chronological order
<hr>

### Version 1.0.9 - 13 Aug 2019

- Fixed a thread contention issue caused by sorting the properties array in place
- Added thread protection around creation and access of date formatters
- Made copying behavior a little more explicit in the code

### Version 1.0.8 - 24 Jun 2019

- Fixed a bug around copying mutable models where submodels in the cache could have an incorrect mutable status
- Fixed an issue with float values not properly decoding in some cases

### Version 1.0.7 - 16 May 2019

- Added property classes for a dictionary of arrays of models
- Made dictionary of model properties more resilient to keys that contain a "null" value in JSON (an NSNull) - those keys are discarded rather than the entire dictionary being ignored due to a type check failure.
- Fixed an issue where a model derives from a parent class WrapModel in which the parent class' properties weren't gathered and initialized properly.

### Version 1.0.6 - 17 Apr 2019

- Overrides of rawValue weren't obeying serializeForOutput flag
- Added additional boolean output mode for "Y" & "N" in addition to "yes" and "no"
- Added optional enum property type WrapPropertyOptionalEnum/WrapPropertyConvertibleOptionalEnum (WPOptEnum)

### Version 1.0.5 - 23 Mar 2019

- Corrected some misnamed date format enums

### Version 1.0.4 - 19 Mar 2019

- More funcs/vars in WrapModel and WrapModelProperty are open rather than public so they can be overridden.

### Version 1.0.3 - 19 Mar 2019

- dictionary key tokens used for property groups made publicly accessible
- made WrapPropertyBoolean's string test for boolean value public

### Version 1.0.2 - 17 Mar 2019

- fixed WrapPropertyOptionalInt which could return Int??
- added the same special-cased numeric conversion to collections of numeric values that were present in single numeric property classes
- added tests for numeric arrays
- added new date formats and simplified the way date formatters are created/stored
- added WrapPropertyOptionalIntFromString
- fixed serialization parameters not being obeyed in submodels when serializing parent model
- replaced serializationMode with serializeForOutput flag which, I think, is a lot easier to understand

### Version 1.0.1 - 16 Mar 2019

- Removed nonessentials leaving only the basic WrapModel mechanism.
- Added CocoaPods podspec

### Version 1.0 - 13 Mar 2019

- Initial Release
    
