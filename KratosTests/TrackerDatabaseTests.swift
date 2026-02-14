import XCTest

@testable import Kratos

final class TrackerDatabaseTests: XCTestCase {

    func testParseDisconnectJSON_ValidData() {
        let db = TrackerDatabase.shared
        let json = """
            {
                "categories": {
                    "Advertising": [
                        {
                            "TestTracker": {
                                "https://testtracker.com/": ["testtracker.com", "testtracker.net"]
                            }
                        }
                    ],
                    "Analytics": [
                        {
                            "TestAnalytics": {
                                "https://testanalytics.io/": ["testanalytics.io"]
                            }
                        }
                    ]
                }
            }
            """.data(using: .utf8)!

        db.parseDisconnectJSON(json)

        let result = db.lookup(domain: "testtracker.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.entityName, "TestTracker")
        XCTAssertEqual(result?.category, .advertising)
        XCTAssertTrue(result?.domains.contains("testtracker.net") ?? false)
    }

    func testParseDisconnectJSON_AnalyticsCategory() {
        let db = TrackerDatabase.shared

        let result = db.lookup(domain: "testanalytics.io")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.entityName, "TestAnalytics")
        XCTAssertEqual(result?.category, .analytics)
    }

    func testLookupSubdomain() {
        let db = TrackerDatabase.shared
        let json = """
            {
                "categories": {
                    "Advertising": [
                        {
                            "SubTest": {
                                "https://subtest.com/": ["subtest.com"]
                            }
                        }
                    ]
                }
            }
            """.data(using: .utf8)!

        db.parseDisconnectJSON(json)

        let result = db.lookup(domain: "ad.subtest.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.entityName, "SubTest")
    }

    func testLookupUnknownDomain() {
        let db = TrackerDatabase.shared
        let result = db.lookup(domain: "totally-unknown-domain-xyz123.com")

        XCTAssertNil(result)
    }

    func testMergeAddsNewEntries() {
        let db = TrackerDatabase.shared
        let before = db.allEntries().count

        db.merge([
            "custom-tracker-test.com": ThreatDetector.TrackerInfo(
                entityName: "Custom Test",
                category: .advertising,
                domains: ["custom-tracker-test.com"]
            )
        ])

        XCTAssertGreaterThan(db.allEntries().count, before)
        XCTAssertNotNil(db.lookup(domain: "custom-tracker-test.com"))
    }

    func testParseDisconnectJSON_CryptominingCategory() {
        let db = TrackerDatabase.shared
        let json = """
            {
                "categories": {
                    "Cryptomining": [
                        {
                            "TestMiner": {
                                "https://testminer.com/": ["testminer.com", "testminer.io"]
                            }
                        }
                    ]
                }
            }
            """.data(using: .utf8)!

        db.parseDisconnectJSON(json)

        let result = db.lookup(domain: "testminer.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.category, .cryptomining)
    }

    func testParseDisconnectJSON_SocialCategory() {
        let db = TrackerDatabase.shared
        let json = """
            {
                "categories": {
                    "Social": [
                        {
                            "TestSocial": {
                                "https://testsocial.com/": ["testsocial.com"]
                            }
                        }
                    ]
                }
            }
            """.data(using: .utf8)!

        db.parseDisconnectJSON(json)

        let result = db.lookup(domain: "testsocial.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.category, .social)
    }

    func testParseDisconnectJSON_InvalidData() {
        let db = TrackerDatabase.shared
        let before = db.allEntries().count
        let badData = "not json".data(using: .utf8)!

        db.parseDisconnectJSON(badData)

        XCTAssertEqual(db.allEntries().count, before)
    }

    func testDomainCountUpdated() {
        let db = TrackerDatabase.shared
        let json = """
            {
                "categories": {
                    "Advertising": [
                        {
                            "CountTest": {
                                "https://counttest.com/": ["counttest.com", "counttest.net", "counttest.org"]
                            }
                        }
                    ]
                }
            }
            """.data(using: .utf8)!

        db.parseDisconnectJSON(json)

        XCTAssertGreaterThan(db.domainCount, 0)
        XCTAssertGreaterThan(db.entityCount, 0)
    }
}
