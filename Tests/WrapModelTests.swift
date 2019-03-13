//
//  WrapModelSampleTests.swift
//  WrapModelSampleTests
//
//  Created by Ken on 3/12/19.
//  Copyright © 2019 1stdibs. All rights reserved.
//

import XCTest
@testable import WrapModelSample

/// A model with an enum member
@objc enum RewardLevel: Int {
    case bronze
    case gold
    case platinum
}

extension RewardLevel: WrapConvertibleEnum {
    
    static func conversionDict() -> [String : RewardLevel] {
        return ["Bronze": .bronze, "Gold": .gold, "Platinum": .platinum]
    }
    
}

class WrapModelTests: XCTestCase {

    
    //MARK: - SAMPLE MODEL -
    
    /// Sample model class
    @objc(WrapModelTestsSampleModel)
    class SampleModel : WrapModel {
        
        // Comm prefs property group
        @objc(WrapModelTestsSampleModelCommPrefs)
        class CommPrefs : WrapModel {
            // Property definitions
            private let _commInterval = WPInt("commInterval", defaultValue: 7)
            private let _allowSMS = WPOptBool("allowSMS")
            
            // Property accessors
            var commInterval: Int { set { _commInterval.value = newValue } get { return _commInterval.value } }
            var allowSMS: WPBoolean { set { _allowSMS.value = newValue } get { return _allowSMS.value } }
        }
        
        // A submodel
        @objc(WrapModelTestsSampleModelPurchase)
        class Purchase : WrapModel {
            private let _purchaseDate = WPDate("purchaseDate", dateType: .iso8601)
            private let _purchasePrice = WPFloat("purchasePrice")
            
            var date: Date? { return _purchaseDate.value }
            var price: Float { return _purchasePrice.value }
        }
        
        // Property definitions
        private let _firstName = WPOptStr("firstName")
        private let _lastName = WPOptStr("lastName")
        private let _salutation = WPStr("salutation", defaultValue: "Hello")
        private let _joinDate = WPDate("joinDate", dateType: .yyyymmdd)
        private let _separationDate = WPDate("sepDate", dateType: .yyyymmddDashes)
        private let _anniversaryDate = WPDate("annivDate", dateType: .yyyymmddSlashes)
        private let _creationDate = WPDate("creationDate", dateType: .iso8601)
        private let _modificationDate = WPDate("modDate", dateType: .secondary)
        private let _releaseDate = WPDate("releaseDate", dateType: .dibs)
        private let _rewardLevel = WPEnum<RewardLevel>("rewardLevel", defaultEnum: .bronze)
        private let _oldRewardLevel = WPEnum<RewardLevel>("oldRewardLevel", defaultEnum: .bronze)
        private let _commPrefs = WPGroup<CommPrefs>()
        private let _purchases = WPModelArray<Purchase>("pastPurchases")
        private let _negotiations = WPOptModelArray<Purchase>("negotiations")
        private let _currentPurchase = WPModel<Purchase>("currentPurchase")
        private let _stats = WPDict("statistics")
        private let _neverOutput = WPOptStr("neverOutput", serialize: .never)
        private let _conversionRate = WPFloat("conversionRate")
        private let _preciseConversionRate = WPDouble("preciseConvRate")
        private let _numPurchases = WPInt("numberOfPurchases")
        private let _firstScore = WPIntStr("score1")
        private let _secondScore = WPIntStr("score2")
        
        // Property accessors
        var firstName: String?          { set { _firstName.value = newValue } get { return _firstName.value } }
        var lastName: String?           { set { _lastName.value = newValue } get { return _lastName.value } }
        var salutation: String          { set { _salutation.value = newValue } get { return _salutation.value } }
        var joinDate: Date?             { set { _joinDate.value = newValue } get { return _joinDate.value } }
        var separationDate: Date?       { set { _separationDate.value = newValue } get { return _separationDate.value } }
        var anniversaryDate: Date?      { set { _anniversaryDate.value = newValue } get { return _anniversaryDate.value } }
        var creationDate: Date?         { set { _creationDate.value = newValue } get { return _creationDate.value } }
        var modificationDate: Date?     { set { _modificationDate.value = newValue } get { return _modificationDate.value } }
        var releaseDate: Date?          { set { _releaseDate.value = newValue } get { return _releaseDate.value } }
        var rewardLevel: RewardLevel    { return _rewardLevel.value }
        var oldRewardLevel: RewardLevel { return _oldRewardLevel.value }
        var commPrefs: CommPrefs        { return _commPrefs.value }
        var purchases: [Purchase]       { return _purchases.value }
        var negotiations: [Purchase]?   { return _negotiations.value }
        var currentPurchase: Purchase?  { return _currentPurchase.value }
        var stats: [String:Any]         { set { _stats.value = newValue} get { return _stats.value } }
        var neverOutput: String?        { set { _neverOutput.value = newValue } get { return _neverOutput.value } }
        var conversionRate: Float       { set { _conversionRate.value = newValue } get { return _conversionRate.value } }
        var preciseConversionRate: Double { set { _preciseConversionRate.value = newValue } get { return _preciseConversionRate.value } }
        var numPurchases: Int           { set { _numPurchases.value = newValue } get { return _numPurchases.value } }
        var firstScore: Int             { return _firstScore.value }
        var secondScore: Int            { return _secondScore.value }
    }
    
    @objc(WrapModelTestsSampleModelNever)
    class SampleModelNever : SampleModel {
        private let _testSerialize = WPStr("testSerialize", serialize: .never)
        var testSerialize: String? { return _testSerialize.value }
    }
    
    @objc(WrapModelTestsSampleModelAlways)
    class SampleModelAlways : SampleModel {
        private let _testSerialize = WPStr("testSerialize", serialize: .always)
        var testSerialize: String? { return _testSerialize.value }
    }

    
    //MARK: - DATA -
    
    let wyattJSON = """
    {
      "firstName": "Wyatt",
      "lastName": "Earp",
      "salutation": "Greetings",
      "joinDate": "20130114",
      "sepDate": "2013-01-14",
      "annivDate": "2013/01/14",
      "creationDate": "2016-11-01T21:14:33Z",
      "modDate": "Tue Jun 3 2008 11:05:30 GMT",
      "releaseDate": "2017-02-05T17:03:13.000-03:00",
      "rewardLevel": "Gold",
      "commInterval": 4,
      "allowSMS": true,
      "pastPurchases": [
        {
          "purchaseDate": "2016-11-01T21:14:33Z",
          "purchasePrice": 12.5
        },
        {
          "purchaseDate": "2017-01-19T11:27:01Z",
          "purchasePrice": 177.23
        },
        {
          "purchaseDate": "2018-07-03T02:55:12Z",
          "purchasePrice": 89.75
        }
      ],
      "negotiations": [
        {
          "purchaseDate": "2017-09-09T12:35:44Z",
          "purchasePrice": 1999.99
        }
      ],
      "currentPurchase": {
        "purchaseDate": "2019-03-06T15:05:51Z",
        "purchasePrice": 37.72
      },
      "stats": {
        "conversionRate": 0.02,
        "adherenceFactor": 8
      },
      "additionalInfo": {
        "junk1": "junk"
      },
      "additionalJunk": 12,
      "neverOutput": "shouldn't see this string in output JSON",
      "conversionRate": 1.23,
      "preciseConvRate": 3.45,
      "numberOfPurchases": 3,
      "testSerialize": "might or might not serialize",
      "score1": "1",
      "score2": 2
    }
    """
    
    let sparseJSON = """
    {
      "firstName": "Sparse",
    }
    """
    
    let emptyModel = SampleModel(data: [:], mutable: false)
    
    var wyattDict = [String: Any]()
    var sparseDict = [String: Any]()
    
    var wyatt: SampleModel!
    var sparse: SampleModel!
    var mWyatt: SampleModel! // mutable
    var mSparse: SampleModel! // mutable

    
    //MARK: - TESTS -
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        if let wyattData = wyattJSON.data(using: .utf8) {
            wyattDict = try! JSONSerialization.jsonObject(with: wyattData) as! [String:Any]
        } else {
            XCTAssert(false, "Failure to create data object from wyattJSON string")
        }
        if let sparseData = sparseJSON.data(using: .utf8) {
            sparseDict = try! JSONSerialization.jsonObject(with: sparseData) as! [String:Any]
        } else {
            XCTAssert(false, "Failure to create data object from sparseJSON string")
        }
        
        wyatt = SampleModel(json: wyattJSON, mutable: false) ?? emptyModel
        sparse = SampleModel(json: sparseJSON, mutable: false) ?? emptyModel
        
        mWyatt = SampleModel(asCopyOf: wyatt, withMutations: false, mutable: true)
        mSparse = SampleModel(asCopyOf: sparse, withMutations: false, mutable: true)
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testModelCreation() throws {
        XCTAssert(wyatt != emptyModel, "wyatt model didn't decode json successfully")
        XCTAssert(sparse != emptyModel, "sparse model didn't decode json successfully")
    }
    
    func testSparseOutput() throws {
        
        let sparseOutput = mSparse.jsonDictionaryWithoutNulls(true)
        let sparseOutputWithNulls = mSparse.jsonDictionaryWithoutNulls(false)
        XCTAssertNotEqual(sparseOutput as NSDictionary, sparseOutputWithNulls as NSDictionary)
        
        // Test a few fields for presence of nulls - these are optional properties missing from the original data without default values
        XCTAssertEqual(sparseOutputWithNulls["lastName"] as? NSNull, NSNull())
        XCTAssertEqual(sparseOutputWithNulls["joinDate"] as? NSNull, NSNull())
        XCTAssertEqual(sparseOutputWithNulls["negotiations"] as? NSNull, NSNull())
        
        // Should be missing regardless of output with nulls
        XCTAssertNil(sparseOutputWithNulls["neverOutput"])
    }
    
    func testPropertyGroup() throws {
        
        // Test initial values
        if let expectedInterval = wyattDict["commInterval"] as? Int {
            XCTAssertEqual(mWyatt.commPrefs.commInterval, expectedInterval)
        } else {
            XCTAssert(false, "commInterval value expected but missing")
        }
        let expectedAllowSMS: Bool = boolFromKey("allowSMS", in:wyattDict)
        XCTAssertEqual(mWyatt.commPrefs.allowSMS, WPBooleanFrom(expectedAllowSMS))
        
        // Test mutation
        let newCommInterval = 8
        let newAllowSMS = WPBoolean(boolVal: false)
        mWyatt.commPrefs.commInterval = newCommInterval
        mWyatt.commPrefs.allowSMS = newAllowSMS
        XCTAssertEqual(mWyatt.commPrefs.commInterval, newCommInterval)
        XCTAssertEqual(mWyatt.commPrefs.allowSMS, newAllowSMS)
        
        // Mutations exported correctly?
        let wyattOutput = mWyatt.jsonDictionaryWithoutNulls(true)
        XCTAssertEqual(intFromKey("commInterval", in:wyattOutput), newCommInterval)
        XCTAssertEqual(intFromKey("commInterval", in:wyattOutput), newCommInterval)
        XCTAssertEqual(boolFromKey("allowSMS", in:wyattOutput), newAllowSMS.isTrue())
    }
    
    func testDates() throws {
        
        // Ensure input -> Date -> JSON -> Date matches
        let joinDate = mWyatt.joinDate
        let sepDate = mWyatt.separationDate
        let annivDate = mWyatt.anniversaryDate
        let creationDate = mWyatt.creationDate
        let modDate = mWyatt.modificationDate
        let releaseDate = mWyatt.releaseDate
        
        XCTAssertNotNil(joinDate)
        XCTAssertNotNil(sepDate)
        XCTAssertNotNil(annivDate)
        XCTAssertNotNil(creationDate)
        XCTAssertNotNil(modDate)
        XCTAssertNotNil(releaseDate)

        let output = mWyatt.jsonDictionaryWithoutNulls(true)

        let joinStrOut = stringFromKey("joinDate", in: output)
        let sepStrOut = stringFromKey("sepDate", in: output)
        let annivStrOut = stringFromKey("annivDate", in: output)
        let creationStrOut = stringFromKey("creationDate", in: output)
        let modStrOut = stringFromKey("modDate", in: output)
        let releaseStrOut = stringFromKey("releaseDate", in: output)
        
        var wyattDictCopy = wyattDict
        wyattDictCopy["joinDate"] = joinStrOut
        wyattDictCopy["sepDate"] = sepStrOut
        wyattDictCopy["annivDate"] = annivStrOut
        wyattDictCopy["creationDate"] = creationStrOut
        wyattDictCopy["modDate"] = modStrOut
        wyattDictCopy["releaseDate"] = releaseStrOut
        
        let w2 = SampleModel(data: wyattDictCopy, mutable: false)
        let output2 = w2.jsonDictionaryWithoutNulls(false)

        let joinStrOut2 = stringFromKey("joinDate", in: output2)
        let sepStrOut2 = stringFromKey("sepDate", in: output2)
        let annivStrOut2 = stringFromKey("annivDate", in: output2)
        let creationStrOut2 = stringFromKey("creationDate", in: output2)
        let modStrOut2 = stringFromKey("modDate", in: output2)
        let releaseStrOut2 = stringFromKey("releaseDate", in: output2)

        XCTAssertEqual(joinStrOut2, joinStrOut)
        XCTAssertEqual(sepStrOut2, sepStrOut)
        XCTAssertEqual(annivStrOut2, annivStrOut)
        XCTAssertEqual(creationStrOut2, creationStrOut)
        XCTAssertEqual(modStrOut2, modStrOut)
        XCTAssertEqual(releaseStrOut2, releaseStrOut)

        XCTAssertEqual(joinDate, w2.joinDate)
        XCTAssertEqual(sepDate, w2.separationDate)
        XCTAssertEqual(annivDate, w2.anniversaryDate)
        XCTAssertEqual(creationDate, w2.creationDate)
        XCTAssertEqual(modDate, w2.modificationDate)
        XCTAssertEqual(releaseDate, w2.releaseDate)
        
        // Test date conversions using DateOutputType more directly
        let testDate = Date()
        for dateType in WrapPropertyDate.DateOutputType.all() {
            if let dateStr = dateType.string(from: testDate) {
                if let convDate = dateType.date(from: dateStr, fallbackToOtherFormats: false) {
                    let convDateStr = dateType.string(from: convDate)
                    XCTAssertEqual(dateStr, convDateStr)
                } else {
                    XCTAssert(false, "Unable to convert string to date with type \(dateType) and string \(dateStr)")
                }
                
                // All other date types should be able to convert back with fallback allowed
                for dateType2 in WrapPropertyDate.DateOutputType.all() {
                    if let convDate2 = dateType2.date(from: dateStr, fallbackToOtherFormats: true) {
                        let convDateStr2 = dateType.string(from: convDate2) // orig date type to convert back to string
                        XCTAssertEqual(dateStr, convDateStr2)
                    } else {
                        XCTAssert(false, "Unable to convert string to date with type \(dateType2) and string \(dateStr)")
                    }
                }
            } else {
                XCTAssert(false, "Unable to convert date to string with type \(dateType)")
            }
        }
    }

    func testSerializationMode() throws {
        
        // Test initial value
        if let expectedVal = wyattDict["neverOutput"] as? String {
            XCTAssertEqual(mWyatt.neverOutput, expectedVal)
        } else {
            XCTAssert(false, "neverOutput value expected but missing")
        }
        
        // Test output
        let outJSON = mWyatt.jsonDictionaryWithoutNulls(true)
        XCTAssertNil(outJSON["neverOutput"])
        
        // Mutate, then test value and output again
        let changedValue = "Changed string"
        mWyatt.neverOutput = changedValue
        XCTAssertEqual(mWyatt.neverOutput, changedValue)
        let outJSON2 = mWyatt.jsonDictionaryWithoutNulls(true)
        XCTAssertNil(outJSON2["neverOutput"])
    }

    func floatEqual(_ a:Double?, _ b:Double?) -> Bool {
        guard let a = a, let b = b else { return false }
        return round(a*100.0) == round(b*100.0)
    }
    
    func testNumberProperties() throws {
        
        // Test initial values
        let expectedRate = doubleFromKey("conversionRate", in:wyattDict)
        XCTAssert(floatEqual(expectedRate, Double(mWyatt.conversionRate)), "Float value mismatch")
        let expectedPreciseRate = doubleFromKey("preciseConvRate", in:wyattDict)
        XCTAssert(floatEqual(expectedPreciseRate, mWyatt.preciseConversionRate), "Double value mismatch")
        let expectedNumPurchases = intFromKey("numberOfPurchases", in:wyattDict)
        XCTAssert(expectedNumPurchases == mWyatt.numPurchases, "Int value mismatch")
        
        // Mutate values and test
        let newFloat: Float = 123.45
        mWyatt.conversionRate = newFloat
        let newDouble: Double = 345.67
        mWyatt.preciseConversionRate = newDouble
        let newInt: Int = 12345
        mWyatt.numPurchases = newInt
        XCTAssertEqual(mWyatt.conversionRate, newFloat)
        XCTAssertEqual(mWyatt.preciseConversionRate, newDouble)
        XCTAssertEqual(mWyatt.numPurchases, newInt)
        
        // Serialize and check
        let output = mWyatt.jsonDictionaryWithoutNulls(true)
        let outConvRate = doubleFromKey("conversionRate", in:output)
        let outPreciseRate = doubleFromKey("preciseConvRate", in: output)
        let outNumPurch = intFromKey("numberOfPurchases", in:output)
        XCTAssert(floatEqual(outConvRate, Double(newFloat)), "Float value doesn't match expected on output")
        XCTAssert(floatEqual(outPreciseRate, newDouble), "Double value doesn't match expected on output")
        XCTAssert(newInt == outNumPurch, "Int value doesn't match expected on output")
    }
    
    func testIntAsString() throws {
        
        // Test original values in data
        let s1Orig = stringFromKey("score1", in: wyattDict)
        let s2Orig = intFromKey("score2", in: wyattDict)
        
        XCTAssertEqual(s1Orig, "1") // val in original data encoded as string
        XCTAssertEqual(s2Orig, 2) // val in original data encoded as int
        
        let s1 = mWyatt.firstScore
        let s2 = mWyatt.secondScore
        
        // Values in model are always integers
        XCTAssertEqual(s1, 1)
        XCTAssertEqual(s2, 2)
        
        // Output to dictionary
        let output = mWyatt.jsonDictionaryWithoutNulls(true)
        
        let s1Str = stringFromKey("score1", in: output)
        let s2Str = stringFromKey("score2", in: output)
        
        // Should always output as strings
        XCTAssertEqual(s1Str, "1")
        XCTAssertEqual(s2Str, "2")
    }
    
    func testEnum() throws {
        
        // Get original value in data
        let origEnumStr = stringFromKey("rewardLevel", in: wyattDict)
        XCTAssertEqual(mWyatt.rewardLevel, RewardLevel.gold)
        let output = mWyatt.jsonDictionaryWithoutNulls(true)
        let outEnumStr = stringFromKey("rewardLevel", in: output)
        XCTAssertEqual(outEnumStr, origEnumStr)
        
        // Test default enum value
        let missingEnumStr = wyattDict["oldRewardLevel"] as? String
        XCTAssertNil(missingEnumStr)
        XCTAssertEqual(mWyatt.oldRewardLevel, RewardLevel.bronze)
    }
    
    func testEquality_isnt_broken_by_serializationMode() throws {
        
        if let always = SampleModelAlways(json: wyattJSON),
            let never = SampleModelNever(json: wyattJSON) {
            XCTAssert(always.isEqualToModel(model: never), "Serialization mode shouldn't affect equality check")
        } else {
            XCTAssert(false, "Unable to create SampleModelAlways or SampleModelNever model")
        }
    }

    func testNSCoding() throws {
        
        // Encode
        let data = NSKeyedArchiver.archivedData(withRootObject: wyatt)
        
        // Decode
        let decodedWyatt = try! NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? SampleModel
        
        XCTAssertNotNil(decodedWyatt)
        if let decodedWyatt = decodedWyatt {
            XCTAssert(decodedWyatt.isEqualToModel(model: wyatt), "Models not equal after archiving/unarchiving")
        }
    }

    func testJsonDictionaryWithoutNulls() throws {
        
        final class PhoneNumberModel: WrapModel {
            
            // MARK: Model Property definitions
            
            private let _phoneNumber = WPOptStr("phoneNumber")
            private let _countryCode = WPOptStr("countryCode")
            
            
            // MARK: Property accessors
            
            var phoneNumber: String? { return _phoneNumber.value }
            var countryCode: String? {
                get { return _countryCode.value }
                set { _countryCode.value = newValue }
            }
        }
        
        // jsonDictionaryWithoutNulls = true, model has no nils
        var rawJSON = """
        {
            "phoneNumber": "2019137955",
            "countryCode": "+1"
        }
        """
        // map to model
        var phoneNumberModel = try assertNotNilAndUnwrap(PhoneNumberModel(json: rawJSON))
        // back to json dictionary
        var phoneNumberModelJSON = phoneNumberModel.jsonDictionaryWithoutNulls(true)
        XCTAssertEqual(phoneNumberModelJSON["phoneNumber"] as? String, "2019137955")
        XCTAssertEqual(phoneNumberModelJSON["countryCode"] as? String, "+1")
        
        
        
        // jsonDictionaryWithoutNulls = false, model has no nils
        rawJSON = """
        {
        "phoneNumber": "2019137955",
        "countryCode": "+1"
        }
        """
        // map to model
        phoneNumberModel = try assertNotNilAndUnwrap(PhoneNumberModel(json: rawJSON))
        // back to json dictionary
        phoneNumberModelJSON = phoneNumberModel.jsonDictionaryWithoutNulls(false)
        XCTAssertEqual(phoneNumberModelJSON["phoneNumber"] as? String, "2019137955")
        XCTAssertEqual(phoneNumberModelJSON["countryCode"] as? String, "+1")
        
        
        
        // jsonDictionaryWithoutNulls = true, json is missing keys
        rawJSON = """
        {
        "phoneNumber": "2019137955"
        }
        """
        // map to model
        phoneNumberModel = try assertNotNilAndUnwrap(PhoneNumberModel(json: rawJSON))
        // back to json dictionary
        phoneNumberModelJSON = phoneNumberModel.jsonDictionaryWithoutNulls(true)
        XCTAssertEqual(phoneNumberModelJSON["phoneNumber"] as? String, "2019137955")
        XCTAssertNil(phoneNumberModelJSON["countryCode"])
        
        
        
        // jsonDictionaryWithoutNulls = false, json is missing keys
        rawJSON = """
        {
        "phoneNumber": "2019137955"
        }
        """
        // map to model
        phoneNumberModel = try assertNotNilAndUnwrap(PhoneNumberModel(json: rawJSON))
        // back to json dictionary
        phoneNumberModelJSON = phoneNumberModel.jsonDictionaryWithoutNulls(false)
        XCTAssertEqual(phoneNumberModelJSON["phoneNumber"] as? String, "2019137955")
        XCTAssertEqual(phoneNumberModelJSON["countryCode"] as? NSNull, NSNull())
        
        
        // jsonDictionaryWithoutNulls = true, json has nulls
        rawJSON = """
        {
        "phoneNumber": "2019137955",
        "countryCode": null
        }
        """
        // map to model
        phoneNumberModel = try assertNotNilAndUnwrap(PhoneNumberModel(json: rawJSON))
        // back to json dictionary
        phoneNumberModelJSON = phoneNumberModel.jsonDictionaryWithoutNulls(true)
        XCTAssertEqual(phoneNumberModelJSON["phoneNumber"] as? String, "2019137955")
        XCTAssertNil(phoneNumberModelJSON["countryCode"])
        
        
        
        // jsonDictionaryWithoutNulls = false, json has nulls
        rawJSON = """
        {
        "phoneNumber": "2019137955",
        "countryCode": null
        }
        """
        // map to model
        phoneNumberModel = try assertNotNilAndUnwrap(PhoneNumberModel(json: rawJSON))
        // back to json dictionary
        phoneNumberModelJSON = phoneNumberModel.jsonDictionaryWithoutNulls(false)
        XCTAssertEqual(phoneNumberModelJSON["phoneNumber"] as? String, "2019137955")
        XCTAssertEqual(phoneNumberModelJSON["countryCode"] as? NSNull, NSNull())
        
        
        
        // jsonDictionaryWithoutNulls = true, model has nils
        rawJSON = """
        {
        "phoneNumber": "2019137955",
        "countryCode": "+1"
        }
        """
        // map to model
        phoneNumberModel = try assertNotNilAndUnwrap(PhoneNumberModel(json: rawJSON, mutable: true))
        phoneNumberModel.countryCode = nil
        
        // back to json dictionary
        phoneNumberModelJSON = phoneNumberModel.jsonDictionaryWithoutNulls(true)
        XCTAssertEqual(phoneNumberModelJSON["phoneNumber"] as? String, "2019137955")
        XCTAssertNil(phoneNumberModelJSON["countryCode"])
        
        
        
        // jsonDictionaryWithoutNulls = false,  model has nils
        rawJSON = """
        {
        "phoneNumber": "2019137955",
        "countryCode": "+1"
        }
        """
        // map to model
        phoneNumberModel = try assertNotNilAndUnwrap(PhoneNumberModel(json: rawJSON, mutable: true))
        phoneNumberModel.countryCode = nil
        
        // back to json dictionary
        phoneNumberModelJSON = phoneNumberModel.jsonDictionaryWithoutNulls(false)
        XCTAssertEqual(phoneNumberModelJSON["phoneNumber"] as? String, "2019137955")
        XCTAssertEqual(phoneNumberModelJSON["countryCode"] as? NSNull, NSNull())
    }
    
    
    func testOriginalModelData() throws {
        
        // Test initial values
        let expectedFirstName = stringFromKey("firstName", in:wyattDict)
        XCTAssertEqual(expectedFirstName, mWyatt.firstName)
        let expectedLastName = stringFromKey("lastName", in:wyattDict)
        XCTAssertEqual(expectedLastName, mWyatt.lastName)
        let expectedRewardLevelStr = stringFromKey("rewardLevel", in:wyattDict)
        if let expectedRewardLevel = RewardLevel.conversionDict()[expectedRewardLevelStr] {
            XCTAssertEqual(expectedRewardLevel, mWyatt.rewardLevel)
        } else {
            XCTAssert(false, "Reward level string doesn't match enum")
        }
        let expectedRate = doubleFromKey("conversionRate", in:wyattDict)
        XCTAssert(floatEqual(expectedRate, Double(mWyatt.conversionRate)), "Float value mismatch")
        let expectedNumPurchases = intFromKey("numberOfPurchases", in:wyattDict)
        XCTAssert(expectedNumPurchases == mWyatt.numPurchases, "Int value mismatch")
        
        // mutate the model and check that original model data remained unchanged
        mWyatt.firstName = "Ted"
        mWyatt.lastName = "Dunson"
        let origDict = mWyatt.originalModelData as NSDictionary
        XCTAssertEqual(origDict, wyattDict as NSDictionary)
    }
    
    
    func testClearMutations() throws {
        
        let origData = mWyatt.jsonDictionaryWithoutNulls(true) as NSDictionary
        let origFirstName = stringFromKey("firstName", in:wyattDict)
        let origLastName = stringFromKey("lastName", in:wyattDict)
        
        // mutate, then export dict again
        mWyatt.firstName = "Ted"
        mWyatt.lastName = "Dunson"
        let modData = mWyatt.jsonDictionaryWithoutNulls(true) as NSDictionary
        
        // Check mutations
        XCTAssertEqual(mWyatt.firstName, "Ted")
        XCTAssertEqual(mWyatt.lastName, "Dunson")
        
        // Should not be equal
        XCTAssertNotEqual(origData, modData)
        
        // Clear mutations
        mWyatt.clearMutations()
        
        // Should again be equal to original data
        XCTAssertEqual(mWyatt.firstName, origFirstName)
        XCTAssertEqual(mWyatt.lastName, origLastName)
        let clearedData = mWyatt.jsonDictionaryWithoutNulls(true) as NSDictionary
        XCTAssertEqual(clearedData, origData)
    }
    
    
    func testCopy() throws {
        
        // copy the model and test that it is the same as the original
        let wyattCopy = mWyatt.copy() as! SampleModel
        XCTAssertEqual(mWyatt, wyattCopy)
        XCTAssertTrue(wyattCopy.isEqualToModel(model:mWyatt))
        
        // mutate original model and ensure it does not affect copy
        mWyatt.firstName = "Ted"
        mWyatt.lastName = "Dunson"
        XCTAssertNotEqual(mWyatt, wyattCopy)
        XCTAssertFalse(wyattCopy.isEqualToModel(model:mWyatt))
    }
    
    
    func testMutableCopy() throws {
        
        // copy the model and test that it is the same as the original
        let wyattCopy = SampleModel(asCopyOf: mWyatt, withMutations: false, mutable: true)
        XCTAssertEqual(mWyatt, wyattCopy)
        XCTAssertTrue(wyattCopy.isEqualToModel(model:mWyatt))
        
        // mutate original model and ensure it does not affect copy
        mWyatt.firstName = "Ted"
        mWyatt.lastName = "Dunson"
        XCTAssertNotEqual(mWyatt, wyattCopy)
        XCTAssertFalse(wyattCopy.isEqualToModel(model:mWyatt))
        
        // reset original, now mutate copy (it should be mutable)
        mWyatt.clearMutations()
        wyattCopy.firstName = "Ted"
        wyattCopy.lastName = "Dunson"
        XCTAssertNotEqual(mWyatt, wyattCopy)
        XCTAssertFalse(wyattCopy.isEqualToModel(model:mWyatt))
        
        // clear mutations - they should be equal again
        wyattCopy.clearMutations()
        XCTAssertEqual(mWyatt, wyattCopy)
        XCTAssertTrue(wyattCopy.isEqualToModel(model:mWyatt))
    }

}


//MARK: - UTILITIES -


struct WrapModelUnexpectedNilError: Error {}

///
/// https://www.raizlabs.com/dev/2017/02/xctest-optional-unwrapping/
///
func assertNotNilAndUnwrap<T>(_ variable: T?, message: String = "Unexpected nil variable", file: StaticString = #file, line: UInt = #line) throws -> T {
    guard let variable = variable else {
        XCTFail(message, file: file, line: line)
        throw WrapModelUnexpectedNilError()
    }
    return variable
}

func valFromKey<T>(_ key:String, in dict:[AnyHashable:Any], file: StaticString = #file, line: UInt = #line) -> T? {
    if let val = dict[key] {
        if let dval = val as? T {
            return dval
        } else {
            XCTFail("Expected value in dictionary is not of expected type", file: file, line: line)
        }
    } else {
        XCTFail("Expected value missing in dictionary", file: file, line: line)
    }
    return nil
}
func intFromKey(_ key:String, in dict:[AnyHashable:Any], file: StaticString = #file, line: UInt = #line) -> Int {
    return valFromKey(key, in:dict, file: file, line: line) ?? 0
}
func doubleFromKey(_ key:String, in dict:[AnyHashable:Any], file: StaticString = #file, line: UInt = #line) -> Double {
    return valFromKey(key, in:dict, file: file, line: line) ?? 0
}
func boolFromKey(_ key:String, in dict:[AnyHashable:Any], file: StaticString = #file, line: UInt = #line) -> Bool {
    return valFromKey(key, in:dict, file: file, line: line) ?? false
}
func stringFromKey(_ key:String, in dict:[AnyHashable:Any], file: StaticString = #file, line: UInt = #line) -> String {
    return valFromKey(key, in:dict, file: file, line: line) ?? ""
}

