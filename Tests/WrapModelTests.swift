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
            private let _allowSMS = WPBool("allowSMS")
            
            // Property accessors
            var commInterval: Int { set { _commInterval.value = newValue } get { return _commInterval.value } }
            var allowSMS: Bool { set { _allowSMS.value = newValue } get { return _allowSMS.value } }
        }
        
        // A submodel
        @objc(WrapModelTestsSampleModelPurchase)
        class Purchase : WrapModel {
            private let _date = WPDate("purchaseDate", dateType: .iso8601)
            private let _price = WPFloat("purchasePrice")
            private let _adjustment = WPInt("purchaseAdjustment", serialize: .never)
            
            var date: Date? { return _date.value }
            var price: Float { return _price.value }
            var adjustment: Int { set { _adjustment.value = newValue } get { return _adjustment.value } }
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
        private let _numReturns = WPOptInt("numberOfReturns")
        private let _firstScore = WPIntStr("score1")
        private let _secondScore = WPIntStr("score2")
        private let _thirdScore = WPOptIntStr("score3")
        private let _salesFigures = WPIntArray("salesFigures")
        private let _salesAmounts = WPFloatArray("salesAmounts")
        private let _returnFigures = WPOptIntArray("returnFigures")
        private let _returnAmounts = WPOptFloatArray("returnAmounts")
        
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
        var numReturns: Int?            { set { _numReturns.value = newValue } get { return _numReturns.value } }
        var firstScore: Int             { return _firstScore.value }
        var secondScore: Int            { return _secondScore.value }
        var thirdScore: Int?            { set { _thirdScore.value = newValue } get { return _thirdScore.value } }
        var salesFigures: [Int]         { set { _salesFigures.value = newValue } get { return _salesFigures.value } }
        var salesAmounts: [Float]       { set { _salesAmounts.value = newValue } get { return _salesAmounts.value } }
        var returnFigures: [Int]?       { set { _returnFigures.value = newValue } get { return _returnFigures.value } }
        var returnAmounts: [Float]?     { set { _returnAmounts.value = newValue } get { return _returnAmounts.value } }
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
        "purchasePrice": 37.72,
        "purchaseAdjustment": 12
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
      "numberOfReturns": 1,
      "testSerialize": "might or might not serialize",
      "score1": "1",
      "score2": 2,
      "score3": "3",
      "salesFigures": [1, 2, 3, 4, 5],
      "salesAmounts": [1.2, 1.3, 1.4, 1.5, 2],
      "returnFigures": [8, 9, 10],
      "returnAmounts": [8.66, 8.77, 8.88]
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
        
        let sparseOutput = mSparse.currentModelData(withNulls: false, forSerialization: true)
        let sparseOutputWithNulls = mSparse.currentModelData(withNulls: true, forSerialization: true)
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
        XCTAssertEqual(mWyatt.commPrefs.allowSMS, expectedAllowSMS)
        
        // Test mutation
        let newCommInterval = 8
        let newAllowSMS = false
        mWyatt.commPrefs.commInterval = newCommInterval
        mWyatt.commPrefs.allowSMS = newAllowSMS
        XCTAssertEqual(mWyatt.commPrefs.commInterval, newCommInterval)
        XCTAssertEqual(mWyatt.commPrefs.allowSMS, newAllowSMS)
        
        // Mutations exported correctly?
        let wyattOutput = mWyatt.currentModelData(withNulls: false, forSerialization: true)
        XCTAssertEqual(intFromKey("commInterval", in:wyattOutput), newCommInterval)
        XCTAssertEqual(boolFromKey("allowSMS", in:wyattOutput), newAllowSMS)
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

        let output = mWyatt.currentModelData(withNulls: false, forSerialization: true)

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
        let output2 = w2.currentModelData(withNulls: true, forSerialization: true)

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
        for dateType in WrapPropertyDate.DateOutputType.allCases {
            if let dateStr = dateType.string(from: testDate) {
                if let convDate = dateType.date(from: dateStr, fallbackToOtherFormats: false) {
                    let convDateStr = dateType.string(from: convDate)
                    XCTAssertEqual(dateStr, convDateStr)
                } else {
                    XCTAssert(false, "Unable to convert string to date with type \(dateType) and string \(dateStr)")
                }
                
                // All other date types should be able to convert back with fallback allowed
                for dateType2 in WrapPropertyDate.DateOutputType.allCases {
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
        let outJSON = mWyatt.currentModelData(withNulls: false, forSerialization: true)
        XCTAssertNil(outJSON["neverOutput"])
        
        // Mutate, then test value and output again
        let changedValue = "Changed string"
        mWyatt.neverOutput = changedValue
        XCTAssertEqual(mWyatt.neverOutput, changedValue)
        let outJSON2 = mWyatt.currentModelData(withNulls: false, forSerialization: true)
        XCTAssertNil(outJSON2["neverOutput"])
        
        // Now in a submodel
        if let curPurch = mWyatt.currentPurchase {
            let subData = curPurch.currentModelData(withNulls: false)
            let curPurchAdj = curPurch.adjustment
            XCTAssertEqual(curPurchAdj, intFromKey("purchaseAdjustment", in: subData))
            
            // Mutate in submodel and output parent model
            let newAdjust = 44
            mWyatt.currentPurchase?.adjustment = newAdjust
            let outputToSerialize = mWyatt.currentModelData(withNulls: false, forSerialization: true)
            if let subOutput = outputToSerialize["currentPurchase"] as? [String:Any] {
                // Value should NOT be there since it's set to never serialize
                XCTAssertNil(subOutput["purchaseAdjustment"])
            } else {
                XCTAssert(false, "Should have current purchase after mutation")
            }
            let outputNotToSerialize = mWyatt.currentModelData(withNulls: false, forSerialization: false)
            if let subOutputNS = outputNotToSerialize["currentPurchase"] as? [String:Any] {
                // Value SHOULD be there since we're not outputting for serialization
                XCTAssertNotNil(subOutputNS["purchaseAdjustment"])
                let afterVal = intFromKey("purchaseAdjustment", in: subOutputNS)
                XCTAssertEqual(afterVal, newAdjust)
            } else {
                XCTAssert(false, "Should have current purchase after mutation")
            }
        } else {
            XCTAssert(false, "Should have current purchase")
        }
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
        let output = mWyatt.currentModelData(withNulls: false, forSerialization: true)
        let outConvRate = doubleFromKey("conversionRate", in:output)
        let outPreciseRate = doubleFromKey("preciseConvRate", in: output)
        let outNumPurch = intFromKey("numberOfPurchases", in:output)
        XCTAssert(floatEqual(outConvRate, Double(newFloat)), "Float value doesn't match expected on output")
        XCTAssert(floatEqual(outPreciseRate, newDouble), "Double value doesn't match expected on output")
        XCTAssert(newInt == outNumPurch, "Int value doesn't match expected on output")
    }
    
    func testOptionalInt() throws {
        let expectedReturns = intFromKey("numberOfReturns", in: wyattDict)
        if let modelReturns = mWyatt.numReturns {
            XCTAssertEqual(modelReturns, expectedReturns)
        } else {
            XCTAssert(false, "Expected numberOfReturns value in model")
        }
        
        // Mutate and check value and output
        let newReturns = 8
        mWyatt.numReturns = newReturns
        XCTAssertEqual(mWyatt.numReturns, newReturns)
        let output = mWyatt.currentModelData(withNulls: false, forSerialization: true)
        let outReturns = intFromKey("numberOfReturns", in: output)
        XCTAssertEqual(outReturns, newReturns)
        
        // Nil and check value and output
        mWyatt.numReturns = nil
        XCTAssertNil(mWyatt.numReturns)
        let output2 = mWyatt.currentModelData(withNulls: false, forSerialization: true)
        XCTAssertNil(output2["numberOfReturns"])
    }
    
    func testIntAsString() throws {
        
        // Test original values in data
        let s1Orig = stringFromKey("score1", in: wyattDict)
        let s2Orig = intFromKey("score2", in: wyattDict)
        XCTAssertNotNil(wyattDict["score3"])
        let s3Orig = stringFromKey("score3", in: wyattDict)
        
        XCTAssertEqual(s1Orig, "1") // val in original data encoded as string
        XCTAssertEqual(s2Orig, 2) // val in original data encoded as int
        XCTAssertEqual(s3Orig, "3") // val in original data encoded as string
        
        let s1 = mWyatt.firstScore
        let s2 = mWyatt.secondScore
        let s3 = mWyatt.thirdScore
        
        // Values in model are always integers
        XCTAssertEqual(s1, 1)
        XCTAssertEqual(s2, 2)
        XCTAssertEqual(s3, 3)
        
        // Output to dictionary
        let output = mWyatt.currentModelData(withNulls: false, forSerialization: true)
        
        let s1Str = stringFromKey("score1", in: output)
        let s2Str = stringFromKey("score2", in: output)
        let s3Str = stringFromKey("score3", in: output)
        
        // Should always output as strings
        XCTAssertEqual(s1Str, "1")
        XCTAssertEqual(s2Str, "2")
        XCTAssertEqual(s3Str, "3")
        
        // optional nil
        mWyatt.thirdScore = nil
        let output2 = mWyatt.currentModelData(withNulls: false, forSerialization: true)
        XCTAssertNil(output2["score3"])
    }
    
    func testNumericArrays() throws {
        
        // Get original values in data
        let origSalesFiguresOpt = wyattDict["salesFigures"] as? [Int]
        let origSalesAmountsOpt = wyattDict["salesAmounts"] as? [Double]
        let origReturnFiguresOpt = wyattDict["returnFigures"] as? [Int]
        let origReturnAmountsOpt = wyattDict["returnAmounts"] as? [Double]
        
        XCTAssertNotNil(origReturnFiguresOpt)
        XCTAssertNotNil(origReturnAmountsOpt)
        
        let origSalesFigures = origSalesFiguresOpt ?? []
        let origSalesAmounts = (origSalesAmountsOpt ?? []).map { Float($0) }
        let origReturnFigures = origReturnFiguresOpt ?? []
        let origReturnAmounts = (origReturnAmountsOpt ?? []).map { Float($0) }

        XCTAssertEqual(mWyatt.salesFigures.count, origSalesFigures.count)
        XCTAssertEqual(mWyatt.salesAmounts.count, origSalesAmounts.count)
        XCTAssertEqual(mWyatt.returnFigures?.count ?? 0, origReturnFigures.count)
        XCTAssertEqual(mWyatt.returnAmounts?.count ?? 0, origReturnAmounts.count)
        
        XCTAssertEqual(mWyatt.salesFigures, origSalesFigures)
        XCTAssertEqual(mWyatt.salesAmounts, origSalesAmounts)
        let mReturnFigures = mWyatt.returnFigures ?? []
        var mReturnAmounts = mWyatt.returnAmounts ?? []
        XCTAssertEqual(mReturnFigures, origReturnFigures)
        for amt in origReturnAmounts {
            XCTAssertEqual(amt, mReturnAmounts[0])
            mReturnAmounts.remove(at: 0)
        }
        
        // Mutate and check output
        let newSalesFigures = [7, 8, 9]
        let newSalesAmounts:[Float] = [7.7, 8.8, 9.9]
        mWyatt.salesFigures = newSalesFigures
        mWyatt.salesAmounts = newSalesAmounts
        mWyatt.returnFigures = nil
        mWyatt.returnAmounts = nil
        let output = mWyatt.currentModelData(withNulls: false, forSerialization: true)
        let outSalesFigures = (output["salesFigures"] as? [Int]) ?? []
        var outSalesAmounts = (output["salesAmounts"] as? [Float] ?? [])
        XCTAssertEqual(outSalesFigures, newSalesFigures)
        for amt in newSalesAmounts {
            XCTAssertEqual(amt, outSalesAmounts[0])
            outSalesAmounts.remove(at: 0)
        }

        // Check sparse model for nils
        XCTAssertNil(mSparse.returnFigures)
        XCTAssertNil(mSparse.returnAmounts)
    }
    
    func testEnum() throws {
        
        // Get original value in data
        let origEnumStr = stringFromKey("rewardLevel", in: wyattDict)
        XCTAssertEqual(mWyatt.rewardLevel, RewardLevel.gold)
        let output = mWyatt.currentModelData(withNulls: false, forSerialization: true)
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

    func testCurrentDataDictionary() throws {
        
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
        
        // withNulls = false, model has no nils
        var rawJSON = """
        {
            "phoneNumber": "2019137955",
            "countryCode": "+1"
        }
        """
        // map to model
        var phoneNumberModel = try assertNotNilAndUnwrap(PhoneNumberModel(json: rawJSON))
        // back to json dictionary
        var phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: false, forSerialization: true)
        XCTAssertEqual(phoneNumberModelJSON["phoneNumber"] as? String, "2019137955")
        XCTAssertEqual(phoneNumberModelJSON["countryCode"] as? String, "+1")
        
        
        
        // withNulls = true, model has no nils
        rawJSON = """
        {
        "phoneNumber": "2019137955",
        "countryCode": "+1"
        }
        """
        // map to model
        phoneNumberModel = try assertNotNilAndUnwrap(PhoneNumberModel(json: rawJSON))
        // back to json dictionary
        phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: true, forSerialization: true)
        XCTAssertEqual(phoneNumberModelJSON["phoneNumber"] as? String, "2019137955")
        XCTAssertEqual(phoneNumberModelJSON["countryCode"] as? String, "+1")
        
        
        
        // withNulls = false, json is missing keys
        rawJSON = """
        {
        "phoneNumber": "2019137955"
        }
        """
        // map to model
        phoneNumberModel = try assertNotNilAndUnwrap(PhoneNumberModel(json: rawJSON))
        // back to json dictionary
        phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: false, forSerialization: true)
        XCTAssertEqual(phoneNumberModelJSON["phoneNumber"] as? String, "2019137955")
        XCTAssertNil(phoneNumberModelJSON["countryCode"])
        
        
        
        // withNulls = true, json is missing keys
        rawJSON = """
        {
        "phoneNumber": "2019137955"
        }
        """
        // map to model
        phoneNumberModel = try assertNotNilAndUnwrap(PhoneNumberModel(json: rawJSON))
        // back to json dictionary
        phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: true, forSerialization: true)
        XCTAssertEqual(phoneNumberModelJSON["phoneNumber"] as? String, "2019137955")
        XCTAssertEqual(phoneNumberModelJSON["countryCode"] as? NSNull, NSNull())
        
        
        // withNulls = false, json has nulls
        rawJSON = """
        {
        "phoneNumber": "2019137955",
        "countryCode": null
        }
        """
        // map to model
        phoneNumberModel = try assertNotNilAndUnwrap(PhoneNumberModel(json: rawJSON))
        // back to json dictionary
        phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: false, forSerialization: true)
        XCTAssertEqual(phoneNumberModelJSON["phoneNumber"] as? String, "2019137955")
        XCTAssertNil(phoneNumberModelJSON["countryCode"])
        
        
        
        // withNulls = true, json has nulls
        rawJSON = """
        {
        "phoneNumber": "2019137955",
        "countryCode": null
        }
        """
        // map to model
        phoneNumberModel = try assertNotNilAndUnwrap(PhoneNumberModel(json: rawJSON))
        // back to json dictionary
        phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: true, forSerialization: true)
        XCTAssertEqual(phoneNumberModelJSON["phoneNumber"] as? String, "2019137955")
        XCTAssertEqual(phoneNumberModelJSON["countryCode"] as? NSNull, NSNull())
        
        
        
        // withNulls = false, model has nils
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
        phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: false, forSerialization: true)
        XCTAssertEqual(phoneNumberModelJSON["phoneNumber"] as? String, "2019137955")
        XCTAssertNil(phoneNumberModelJSON["countryCode"])
        
        
        
        // withNulls = true,  model has nils
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
        phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: true, forSerialization: true)
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
        
        let origData = mWyatt.currentModelData(withNulls: false, forSerialization: true) as NSDictionary
        let origFirstName = stringFromKey("firstName", in:wyattDict)
        let origLastName = stringFromKey("lastName", in:wyattDict)
        
        // mutate, then export dict again
        mWyatt.firstName = "Ted"
        mWyatt.lastName = "Dunson"
        let modData = mWyatt.currentModelData(withNulls: false, forSerialization: true) as NSDictionary
        
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
        let clearedData = mWyatt.currentModelData(withNulls: false, forSerialization: true) as NSDictionary
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

