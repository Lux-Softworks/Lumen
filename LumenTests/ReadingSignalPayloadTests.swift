import XCTest
@testable import Lumen

final class ReadingSignalPayloadTests: XCTestCase {

    func testDecodesValidPayload() throws {
        let json = """
        {
            "url": "https://example.com/article",
            "title": "Test Article",
            "readingTime": 45,
            "scrollDepth": 0.75,
            "triggered": true
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(ReadingSignalPayload.self, from: json)

        XCTAssertEqual(payload.url, "https://example.com/article")
        XCTAssertEqual(payload.title, "Test Article")
        XCTAssertEqual(payload.readingTime, 45)
        XCTAssertEqual(payload.scrollDepth, 0.75, accuracy: 0.001)
        XCTAssertTrue(payload.triggered)
    }

    func testDecodesUnTriggeredPayload() throws {
        let json = """
        {
            "url": "https://example.com",
            "title": "Test Page",
            "readingTime": 10,
            "scrollDepth": 0.2,
            "triggered": false
        }
        """.data(using: .utf8)!

        let payload = try JSONDecoder().decode(ReadingSignalPayload.self, from: json)
        XCTAssertFalse(payload.triggered)
    }

    func testThrowsOnMissingRequiredField() {
        let json = """
        {
            "url": "https://example.com",
            "title": "Test Page"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(
            try JSONDecoder().decode(ReadingSignalPayload.self, from: json)
        )
    }
}
