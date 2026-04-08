import XCTest

@testable import Lumen

@MainActor
final class TrackerDatabaseTests: XCTestCase {

    func testParseDisconnectJSON_ValidData() async {
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

        await db.parseDisconnectJSON(json)

        let result = await db.lookup(domain: "testtracker.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.entityName, "TestTracker")
        XCTAssertEqual(result?.category, .advertising)
        XCTAssertTrue(result?.domains.contains("testtracker.net") ?? false)
    }

    func testParseDisconnectJSON_AnalyticsCategory() async {
        let db = TrackerDatabase.shared

        let result = await db.lookup(domain: "testanalytics.io")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.entityName, "TestAnalytics")
        XCTAssertEqual(result?.category, .analytics)
    }

    func testLookupSubdomain() async {
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

        await db.parseDisconnectJSON(json)

        let result = await db.lookup(domain: "ad.subtest.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.entityName, "SubTest")
    }

    func testLookupUnknownDomain() async {
        let db = TrackerDatabase.shared
        let result = await db.lookup(domain: "totally-unknown-domain-xyz123.com")

        XCTAssertNil(result)
    }

    func testMergeAddsNewEntries() async {
        let db = TrackerDatabase.shared
        let before = await db.allEntries().count

        await db.merge([
            "custom-tracker-test.com": ThreatDetector.TrackerInfo(
                entityName: "Custom Test",
                category: .advertising,
                domains: ["custom-tracker-test.com"]
            )
        ])

        let afterCount = await db.allEntries().count
        XCTAssertGreaterThan(afterCount, before)
        
        let result = await db.lookup(domain: "custom-tracker-test.com")
        XCTAssertNotNil(result)
    }

    func testParseDisconnectJSON_CryptominingCategory() async {
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

        await db.parseDisconnectJSON(json)

        let result = await db.lookup(domain: "testminer.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.category, .cryptomining)
    }

    func testParseDisconnectJSON_SocialCategory() async {
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

        await db.parseDisconnectJSON(json)

        let result = await db.lookup(domain: "testsocial.com")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.category, .social)
    }

    func testParseDisconnectJSON_InvalidData() async {
        let db = TrackerDatabase.shared
        let before = await db.allEntries().count
        let badData = "not json".data(using: .utf8)!

        await db.parseDisconnectJSON(badData)

        let afterCount = await db.allEntries().count
        XCTAssertEqual(afterCount, before)
    }

    func testDomainCountUpdated() async {
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

        await db.parseDisconnectJSON(json)

        let domainCount = await db.domainCount
        let entityCount = await db.entityCount
        XCTAssertGreaterThan(domainCount, 0)
        XCTAssertGreaterThan(entityCount, 0)
    }
}
