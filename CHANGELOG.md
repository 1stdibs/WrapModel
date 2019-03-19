# WrapModel change log

 

Changes in reverse chronological order
<hr>

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
    
