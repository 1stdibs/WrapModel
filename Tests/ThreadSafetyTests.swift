import XCTest
import WrapModel

// MARK: - Test Model with properties to widen the sort window

private class StressTestModel: WrapModel {
    let firstName    = WrapProperty<String>("first_name", defaultValue: "")
    let lastName     = WrapProperty<String>("last_name", defaultValue: "")
    let email        = WrapProperty<String>("email", defaultValue: "")
    let phone        = WrapProperty<String>("phone_number", defaultValue: "")
    let age          = WrapProperty<Int>("age", defaultValue: 0)
    let score        = WrapProperty<Float>("score", defaultValue: 0.0)
    let isActive     = WrapProperty<Bool>("is_active", defaultValue: false)
    let rating       = WrapProperty<Float>("rating", defaultValue: 0.0)
    let bio          = WrapProperty<String>("biography", defaultValue: "")
    let username     = WrapProperty<String>("username", defaultValue: "")
    let city         = WrapProperty<String>("address.city", defaultValue: "")
    let street       = WrapProperty<String>("address.street", defaultValue: "")
    let zip          = WrapProperty<String>("address.zip_code", defaultValue: "")
    let state        = WrapProperty<String>("address.state", defaultValue: "")
    let country      = WrapProperty<String>("address.country", defaultValue: "")
    let lat          = WrapProperty<Float>("address.coordinates.latitude", defaultValue: 0.0)
    let lon          = WrapProperty<Float>("address.coordinates.longitude", defaultValue: 0.0)
    let tagline      = WrapProperty<String>("profile.tagline", defaultValue: "")
    let website      = WrapProperty<String>("profile.website", defaultValue: "")
    let followerCount = WrapProperty<Int>("profile.stats.followers", defaultValue: 0)
}

// MARK: - Test data

private let sampleData: [String: Any] = [
    "first_name": "John",
    "last_name": "Appleseed",
    "email": "john@apple.com",
    "phone_number": "1-800-MY-APPLE",
    "age": 69,
    "score": 9001.0,
    "is_active": true,
    "rating": 5.0,
    "biography": "Sent from my iPhone",
    "username": "john.appleseed",
    "address": [
        "city": "Cupertino",
        "street": "1 Apple Park Way",
        "zip_code": "95014",
        "state": "CA",
        "country": "US",
        "coordinates": [
            "latitude": 37.3349,
            "longitude": -122.0090
        ]
    ],
    "profile": [
        "tagline": "Think different",
        "website": "https://apple.com",
        "stats": [
            "followers": 1000000000
        ]
    ]
]

// MARK: - Thread Safety Tests

final class ThreadSafetyTests: XCTestCase {

    // MARK: - Test 1: Concurrent currentModelData()

    /// Races currentModelData() on fresh instances across 16 threads.
    /// Each iteration creates a NEW instance so sortedProperties lazy var is uninitialized.
    func testConcurrentCurrentModelData() {
        let iterations = 1000
        let threads = 16
        let group = DispatchGroup()

        for _ in 0..<iterations {
            let model = StressTestModel(data: sampleData, mutable: false)
            for _ in 0..<threads {
                group.enter()
                DispatchQueue.global().async {
                    _ = model.currentModelData(withNulls: false)
                    group.leave()
                }
            }
            group.wait()
        }
    }

    // MARK: - Test 2: Concurrent equality

    /// Races == on two fresh instances (races sortedProperties on both).
    func testConcurrentEquality() {
        let iterations = 1000
        let threads = 12
        let group = DispatchGroup()

        for _ in 0..<iterations {
            let model1 = StressTestModel(data: sampleData, mutable: false)
            let model2 = StressTestModel(data: sampleData, mutable: false)
            for _ in 0..<threads {
                group.enter()
                DispatchQueue.global().async {
                    _ = model1 == model2
                    group.leave()
                }
            }
            group.wait()
        }
    }

    // MARK: - Test 3: Concurrent copy

    /// Races copy() on fresh mutable instance. copy() calls currentModelData() internally.
    func testConcurrentCopy() {
        let iterations = 1000
        let threads = 16
        let group = DispatchGroup()

        for _ in 0..<iterations {
            let model = StressTestModel(data: sampleData, mutable: true)
            for _ in 0..<threads {
                group.enter()
                DispatchQueue.global().async {
                    _ = model.copy() as! StressTestModel
                    group.leave()
                }
            }
            group.wait()
        }
    }

    // MARK: - Test 4: Concurrent mixed operations

    /// Mixes currentModelData, equality, copy, and JSON serialization on a fresh instance.
    func testConcurrentMixedOps() {
        let iterations = 1000
        let threads = 16
        let group = DispatchGroup()

        for _ in 0..<iterations {
            let model = StressTestModel(data: sampleData, mutable: true)
            let model2 = StressTestModel(data: sampleData, mutable: false)
            for t in 0..<threads {
                group.enter()
                DispatchQueue.global().async {
                    switch t % 4 {
                    case 0:
                        _ = model.currentModelData(withNulls: false)
                    case 1:
                        _ = model == model2
                    case 2:
                        _ = model.copy() as! StressTestModel
                    case 3:
                        _ = model.currentModelDataAsJSON(withNulls: false)
                    default:
                        break
                    }
                    group.leave()
                }
            }
            group.wait()
        }
    }

    // MARK: - Test 5: Rapid-fire fresh instances

    /// Rapid create + access cycle — each thread creates its own fresh instance.
    /// Maximizes the chance of hitting the lazy var initialization race.
    func testRapidFireFreshInstances() {
        let iterations = 2000
        let threads = 8
        let group = DispatchGroup()

        for _ in 0..<iterations {
            for _ in 0..<threads {
                group.enter()
                DispatchQueue.global().async {
                    let model = StressTestModel(data: sampleData, mutable: false)
                    _ = model.currentModelData(withNulls: false)
                    group.leave()
                }
            }
        }
        group.wait()
    }

    // MARK: - Performance Tests

    /// Single-threaded currentModelData on fresh instances.
    /// Safe on all branches (master included — no concurrency = no crash).
    /// Shows uncontended lock overhead.
    func testPerformanceSingleThreadCurrentModelData() {
        measure {
            for _ in 0..<5000 {
                let model = StressTestModel(data: sampleData, mutable: false)
                _ = model.currentModelData(withNulls: false)
            }
        }
    }

    /// Single-threaded copy() on fresh mutable instances.
    /// Safe on all branches.
    func testPerformanceSingleThreadCopy() {
        measure {
            for _ in 0..<5000 {
                let model = StressTestModel(data: sampleData, mutable: true)
                _ = model.copy() as! StressTestModel
            }
        }
    }

    /// Concurrent currentModelData throughput under lock contention.
    /// Crashes on master (expected). Compare PR fix vs our fix.
    func testPerformanceConcurrentCurrentModelData() {
        let threads = 8
        let group = DispatchGroup()
        measure {
            for _ in 0..<1000 {
                let model = StressTestModel(data: sampleData, mutable: false)
                for _ in 0..<threads {
                    group.enter()
                    DispatchQueue.global().async {
                        _ = model.currentModelData(withNulls: false)
                        group.leave()
                    }
                }
                group.wait()
            }
        }
    }

    /// Full lifecycle: create → sort → access → dealloc.
    /// Single-threaded, safe on all branches.
    func testPerformanceFreshInstanceCycle() {
        measure {
            for _ in 0..<5000 {
                let model = StressTestModel(data: sampleData, mutable: false)
                _ = model.currentModelData(withNulls: false)
                _ = model.currentModelDataAsJSON(withNulls: false)
            }
        }
    }
    
    /// Single-threaded, safe on all branches.
    func testCreationOnly() {
        measure {
            for _ in 0..<10000 {
                _ = StressTestModel(data: sampleData, mutable: false)
            }
        }
    }    
}
