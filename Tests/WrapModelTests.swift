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
            @RWProperty(WPInt("commInterval", defaultValue: 7)) var commInterval: Int
            @RWProperty(WPBool("allowSMS")) var allowSMS: Bool
        }
        
        // A submodel
        @objc(WrapModelTestsSampleModelPurchase)
        class Purchase : WrapModel {
            @ROProperty(WPDate("purchaseDate", dateType: .iso8601)) var date: Date?
            @ROProperty(WPFloat("purchasePrice")) var price: Float
            @RWProperty(WPInt("purchaseAdjustment", serializeForOutput: false)) var adjustment: Int
        }
        
        // Properties
        @RWProperty(WPOptStr("firstName")) var firstName: String?
        @RWProperty(WPOptStr("lastName")) var lastName: String?
        @RWProperty(WPStr("salutation", defaultValue: "Hello")) var salutation: String
        @RWProperty(WPDate("joinDate", dateType: .yyyymmdd)) var joinDate: Date?
        @RWProperty(WPDate("sepDate", dateType: .yyyymmddDashes)) var separationDate: Date?
        @RWProperty(WPDate("annivDate", dateType: .yyyymmddSlashes)) var anniversaryDate: Date?
        @RWProperty(WPDate("creationDate", dateType: .iso8601)) var creationDate: Date?
        @RWProperty(WPDate("modDate", dateType: .secondary)) var modificationDate: Date?
        @RWProperty(WPDate("releaseDate", dateType: .dibs)) var releaseDate: Date?
        @ROProperty(WPEnum<RewardLevel>("rewardLevel", defaultEnum: .bronze)) var rewardLevel: RewardLevel
        @ROProperty(WPEnum<RewardLevel>("oldRewardLevel", defaultEnum: .bronze)) var oldRewardLevel: RewardLevel
        @ROProperty(WPOptEnum<RewardLevel>("prevRewardLevel")) var prevRewardLevel: RewardLevel?
        @ROProperty(WPOptEnum<RewardLevel>("tempRewardLevel")) var tempRewardLevel: RewardLevel?
        @ROProperty(WPGroup<CommPrefs>()) var commPrefs: CommPrefs
        @ROProperty(WPModelArray<Purchase>("pastPurchases")) var purchases: [Purchase]
        @ROProperty(WPOptModelArray<Purchase>("negotiations", serializeForOutput: false)) var negotiations: [Purchase]?
        @ROProperty(WPModel<Purchase>("currentPurchase")) var currentPurchase: Purchase?
        @ROProperty(WPModelDict<Purchase>("purchByType")) var purchasesByType: [String:Purchase]
        @ROProperty(WPOptDictModelArray<Purchase>("purchListsByType")) var purchaseListsByType: [String:[Purchase]]?
        @RWProperty(WPDict("statistics")) var stats: [String:Any]
        @RWProperty(WPOptStr("neverOutput", serializeForOutput: false)) var neverOutput: String?
        @RWProperty(WPFloat("conversionRate")) var conversionRate: Float
        @RWProperty(WPDouble("preciseConvRate")) var preciseConversionRate: Double
        @RWProperty(WPInt("numberOfPurchases")) var numPurchases: Int
        @RWProperty(WPOptInt("numberOfReturns")) var numReturns: Int?
        @ROProperty(WPIntStr("score1")) var firstScore: Int
        @ROProperty(WPIntStr("score2")) var secondScore: Int
        @RWProperty(WPOptIntStr("score3")) var thirdScore: Int?
        @RWProperty(WPIntArray("salesFigures")) var salesFigures: [Int]
        @RWProperty(WPFloatArray("salesAmounts")) var salesAmounts: [Float]
        @RWProperty(WPOptIntArray("returnFigures")) var returnFigures: [Int]?
        @RWProperty(WPOptFloatArray("returnAmounts")) var returnAmounts: [Float]?
    }
    
    @objc(WrapModelTestsSampleModelNotForOutput)
    class SampleModelNotForOutput : SampleModel {
        @ROProperty(WPStr("testSerialize", serializeForOutput: false)) var testSerialize: String
    }
    
    @objc(WrapModelTestsSampleModelForOutput)
    class SampleModelForOutput : SampleModel {
        @ROProperty(WPStr("testSerialize", serializeForOutput: true)) var testSerialize: String
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
      "tempRewardLevel": "Platinum",
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
      "purchByType": {
        "old": {
          "purchaseDate": "2016-12-06T05:25:31Z",
          "purchasePrice": 82.19,
          "purchaseAdjustment": 1
        },
        "new": {
          "purchaseDate": "2019-04-21T18:03:22Z",
          "purchasePrice": 12.50,
          "purchaseAdjustment": 4
        },
        "not": null
      },
      "purchListsByType": {
        "old": [
          {
            "purchaseDate": "2016-12-06T05:25:31Z",
            "purchasePrice": 82.19,
            "purchaseAdjustment": 1
          },
          {
            "purchaseDate": "2016-12-06T05:25:31Z",
            "purchasePrice": 82.19,
            "purchaseAdjustment": 1
          }
        ],
        "new": [
          {
            "purchaseDate": "2019-04-21T18:03:22Z",
            "purchasePrice": 12.50,
            "purchaseAdjustment": 4
          },
          {
            "purchaseDate": "2019-04-21T18:03:22Z",
            "purchasePrice": 12.50,
            "purchaseAdjustment": 4
          }
        ],
        "not": null,
        "not2": [ null ]
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
        
        let sparseOutput = mSparse.currentModelData(withNulls: false, forOutput: true)
        let sparseOutputWithNulls = mSparse.currentModelData(withNulls: true, forOutput: true)
        XCTAssertNotEqual(sparseOutput as NSDictionary, sparseOutputWithNulls as NSDictionary)
        
        // Test a few fields for presence of nulls - these are optional properties missing from the original data without default values
        XCTAssertEqual(sparseOutputWithNulls["lastName"] as? NSNull, NSNull())
        XCTAssertEqual(sparseOutputWithNulls["joinDate"] as? NSNull, NSNull())
        
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
        let wyattOutput = mWyatt.currentModelData(withNulls: false, forOutput: true)
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

        let output = mWyatt.currentModelData(withNulls: false, forOutput: true)

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
        let output2 = w2.currentModelData(withNulls: true, forOutput: true)

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
                
                // Make sure with fallbacks we manage to convert string into a valid date
                for dateType2 in WrapPropertyDate.DateOutputType.allCases {
                    XCTAssertNotNil(dateType2.date(from: dateStr, fallbackToOtherFormats: true), "Unable to convert string to date even with fallback output options")
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
        let outJSON = mWyatt.currentModelData(withNulls: false, forOutput: true)

        // Properties that should not serialize for output
        XCTAssertNil(outJSON["neverOutput"])
        XCTAssertNil(outJSON["negotiations"])
        
        // Mutate, then test value and output again
        let changedValue = "Changed string"
        mWyatt.neverOutput = changedValue
        XCTAssertEqual(mWyatt.neverOutput, changedValue)
        let outJSON2 = mWyatt.currentModelData(withNulls: false, forOutput: true)
        XCTAssertNil(outJSON2["neverOutput"])
        
        // Now in a submodel
        if let curPurch = mWyatt.currentPurchase {
            let subData = curPurch.currentModelData(withNulls: false)
            let curPurchAdj = curPurch.adjustment
            XCTAssertEqual(curPurchAdj, intFromKey("purchaseAdjustment", in: subData))
            
            // Mutate in submodel and output parent model
            let newAdjust = 44
            mWyatt.currentPurchase?.adjustment = newAdjust
            let encodedForOutput = mWyatt.currentModelData(withNulls: false, forOutput: true)
            if let subOutput = encodedForOutput["currentPurchase"] as? [String:Any] {
                // Value should NOT be there since it's set to never serialize for output
                XCTAssertNil(subOutput["purchaseAdjustment"])
            } else {
                XCTAssert(false, "Should have current purchase after mutation")
            }
            let encodedNotForOutput = mWyatt.currentModelData(withNulls: false, forOutput: false)
            if let subNotOutput = encodedNotForOutput["currentPurchase"] as? [String:Any] {
                // Value SHOULD be there since this is not for output to JSON
                XCTAssertNotNil(subNotOutput["purchaseAdjustment"])
                let afterVal = intFromKey("purchaseAdjustment", in: subNotOutput)
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
        let output = mWyatt.currentModelData(withNulls: false, forOutput: true)
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
        let output = mWyatt.currentModelData(withNulls: false, forOutput: true)
        let outReturns = intFromKey("numberOfReturns", in: output)
        XCTAssertEqual(outReturns, newReturns)
        
        // Nil and check value and output
        mWyatt.numReturns = nil
        XCTAssertNil(mWyatt.numReturns)
        let output2 = mWyatt.currentModelData(withNulls: false, forOutput: true)
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
        let output = mWyatt.currentModelData(withNulls: false, forOutput: true)
        
        let s1Str = stringFromKey("score1", in: output)
        let s2Str = stringFromKey("score2", in: output)
        let s3Str = stringFromKey("score3", in: output)
        
        // Should always output as strings
        XCTAssertEqual(s1Str, "1")
        XCTAssertEqual(s2Str, "2")
        XCTAssertEqual(s3Str, "3")
        
        // optional nil
        mWyatt.thirdScore = nil
        let output2 = mWyatt.currentModelData(withNulls: false, forOutput: true)
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
        let output = mWyatt.currentModelData(withNulls: false, forOutput: true)
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
        let output = mWyatt.currentModelData(withNulls: false, forOutput: true)
        let outEnumStr = stringFromKey("rewardLevel", in: output)
        XCTAssertEqual(outEnumStr, origEnumStr)
        
        // Test default enum value
        let missingEnumStr = wyattDict["oldRewardLevel"] as? String
        XCTAssertNil(missingEnumStr)
        XCTAssertEqual(mWyatt.oldRewardLevel, RewardLevel.bronze)
        
        // Test missing optional enum value
        let optEnumStr = wyattDict["prevRewardLevel"] as? String
        XCTAssertNil(optEnumStr)
        XCTAssertNil(mWyatt.prevRewardLevel)
        
        // Test present optional enum value
        let tempEnumStr = stringFromKey("tempRewardLevel", in: wyattDict)
        XCTAssertEqual(mWyatt.tempRewardLevel, RewardLevel.platinum)
        let outTempEnumStr = stringFromKey("tempRewardLevel", in: output)
        XCTAssertEqual(outTempEnumStr, tempEnumStr)
    }
    
    func testDictOfModel() throws {
        // Get dict of models from original data
        let origOptDict = wyattDict["purchByType"]
        XCTAssertNotNil(origOptDict)
        if let origDict = origOptDict as? [String:Any] {
            // The "new" and "old" keys should be present
            XCTAssertNotNil(origDict["new"])
            XCTAssertNotNil(origDict["old"])
            // The "not" key should contain null
            XCTAssert(origDict["not"] is NSNull)
            // Now check the dictionary of models - should still have the other non-null keys
            let newModel = mWyatt.purchasesByType["new"]
            XCTAssertNotNil(newModel)
            let oldModel = mWyatt.purchasesByType["old"]
            XCTAssertNotNil(oldModel)
            let missingModel = mWyatt.purchasesByType["not"]
            XCTAssertNil(missingModel)
        } else {
            XCTAssert(false, "Missing purchByType dict in data")
        }
    }
    
    func testDictOfArrayOfModel() throws {
        // Get dict of array of models from original data
        let origOptDict = wyattDict["purchListsByType"]
        XCTAssertNotNil(origOptDict)
        if let origDict = origOptDict as? [String:Any] {
            // The "not2", "new" and "old" keys should be present and have arrays
            XCTAssertNotNil(origDict["not2"] as? [Any]) // [NSNull]
            XCTAssertNotNil(origDict["new"] as? [Any])
            XCTAssertNotNil(origDict["old"] as? [Any])
            // The "not" key should contain null
            XCTAssert(origDict["not"] is NSNull)
            // The "not2" key should be an array containing an NSNull
            XCTAssert(origDict["not2"] is [NSNull])
            // Check the model property
            if let modelDict:[String:[WrapModelTests.SampleModel.Purchase]] = mWyatt.purchaseListsByType {
                // These two should be present
                XCTAssertNotNil(modelDict["old"])
                XCTAssertNotNil(modelDict["new"])
                // These two should be nil since they were the wrong type in the json
                XCTAssertNil(modelDict["not"])
                XCTAssertNil(modelDict["not2"])
            } else {
                XCTAssert(false, "Missing purchaseListsByType property dictionary")
            }
        } else {
            XCTAssert(false, "Missing purchListsByType dict in data")
        }
    }
    
    func testArrayOfEmbeddedModels() throws {
        let json = """
            {
              "names": [
                {
                  "node": {
                    "info": {
                      "last-name": "Jones",
                      "first-name": "Harry"
                    }
                  }
                },
                {
                  "node": {
                    "info": {
                      "last-name": "Black",
                      "first-name": "Jenny"
                    }
                  }
                }
              ]
            }
        """
        
        class NameModel: WrapModel {
            @ROProperty( WPStr("last-name")) var lastName:String
            @ROProperty( WPStr("first-name")) var firstName:String
        }
        class NamesModel: WrapModel {
            @ROProperty( WPEmbModelArray<NameModel>("names", embedPath: "node.info")) var names:[NameModel]
        }

        guard let namesModel = NamesModel(json: json) else {
            XCTAssert(false, "Couldn't create NamesModel")
            return
        }
        XCTAssert(namesModel.names.first!.lastName == "Jones")
        XCTAssert(namesModel.names.last!.lastName == "Black")
        XCTAssert(namesModel.names.first!.firstName == "Harry")
        XCTAssert(namesModel.names.last!.firstName == "Jenny")
        
        // Convert back to dictionary
        let namesDict = namesModel.currentModelData(withNulls: false)
        guard let namesArray = namesDict["names"] as? [[String:Any]] else {
            XCTAssert(false, "Couldn't extract names array of dictionaries")
            return
        }
        var wrapperDict = namesArray.first!
        var nodeDict = wrapperDict["node"]! as! [String:Any]
        var infoDict = nodeDict["info"]! as! [String:Any]
        var firstName = infoDict["first-name"] as! String
        var lastName = infoDict["last-name"] as! String
        XCTAssert(lastName == "Jones", "Incorrect last name in first output dict")
        XCTAssert(firstName == "Harry", "Incorrect first name in first output dict")
        
        wrapperDict = namesArray.last!
        nodeDict = wrapperDict["node"]! as! [String:Any]
        infoDict = nodeDict["info"]! as! [String:Any]
        firstName = infoDict["first-name"] as! String
        lastName = infoDict["last-name"] as! String
        XCTAssert(lastName == "Black", "Incorrect last name in first output dict")
        XCTAssert(firstName == "Jenny", "Incorrect first name in first output dict")
    }
    
    func testEquality_isnt_broken_by_serializationMode() throws {
        
        if let always = SampleModelForOutput(json: wyattJSON),
            let never = SampleModelNotForOutput(json: wyattJSON) {
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
        var phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: false, forOutput: true)
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
        phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: true, forOutput: true)
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
        phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: false, forOutput: true)
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
        phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: true, forOutput: true)
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
        phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: false, forOutput: true)
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
        phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: true, forOutput: true)
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
        phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: false, forOutput: true)
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
        phoneNumberModelJSON = phoneNumberModel.currentModelData(withNulls: true, forOutput: true)
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
        
        let origData = mWyatt.currentModelData(withNulls: false, forOutput: true) as NSDictionary
        let origFirstName = stringFromKey("firstName", in:wyattDict)
        let origLastName = stringFromKey("lastName", in:wyattDict)
        
        // mutate, then export dict again
        mWyatt.firstName = "Ted"
        mWyatt.lastName = "Dunson"
        let modData = mWyatt.currentModelData(withNulls: false, forOutput: true) as NSDictionary
        
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
        let clearedData = mWyatt.currentModelData(withNulls: false, forOutput: true) as NSDictionary
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
        
        // Access a submodel that we'll check for mutability
        // submodel of mutable copy should also be mutable
        let _ = wyatt.currentPurchase
        let wyattMutableCopy = wyatt.mutableCopy() as! SampleModel
        XCTAssertTrue(wyattMutableCopy.currentPurchase?.isMutable ?? false)
        
        // Now check that a submodel in an immutable copy of a mutable model is immutable
        let _ = mWyatt.currentPurchase
        let wyattImmutableCopy = mWyatt.copy() as! SampleModel
        XCTAssertFalse(wyattImmutableCopy.currentPurchase?.isMutable ?? true)
        
        // Check the same things creating copies using initializer
        let wyattMutableCopy2 = SampleModel(asCopyOf: wyatt, withMutations: true, mutable: true)
        XCTAssertTrue(wyattMutableCopy2.currentPurchase?.isMutable ?? false)
        let wyattImmutableCopy2 = SampleModel(asCopyOf: mWyatt, withMutations: true, mutable: false)
        XCTAssertFalse(wyattImmutableCopy2.currentPurchase?.isMutable ?? true)

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
    
    
    func testWrapPropertyInheritance() {
        
        class User: WrapModel {
            let _id = WPOptInt("id")
            let _token = WPOptStr("token")
            
            var id: Int? { return _id.value }
            var token: String? { return _token.value }
        }
        
        class Seller: User {
            let _logoPath = WPOptStr("logoPath")
            
            var logoPath: String? { return _logoPath.value }
        }
        
        let sellerFromDict = Seller(data: [
            "id": 5,
            "token": "abcde",
            "logoPath": "/stuff.jpg"
        ], mutable: false)
        
        
        // Seller subclass should initialize WrapProperties from its super class correctly:
        XCTAssertEqual(sellerFromDict.id, 5)
        XCTAssertEqual(sellerFromDict.token, "abcde")
        XCTAssertEqual(sellerFromDict.logoPath, "/stuff.jpg")

        
        let sellerCopy = sellerFromDict.copy() as! Seller
        XCTAssertEqual(sellerCopy.id, 5)
        XCTAssertEqual(sellerCopy.token, "abcde")
        XCTAssertEqual(sellerCopy.logoPath, "/stuff.jpg")
        
        let sellerMutableCopy = sellerFromDict.mutableCopy() as! Seller
        XCTAssertEqual(sellerMutableCopy.id, 5)
        XCTAssertEqual(sellerMutableCopy.token, "abcde")
        XCTAssertEqual(sellerMutableCopy.logoPath, "/stuff.jpg")
        
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

