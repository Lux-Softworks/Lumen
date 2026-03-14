import XCTest
import WebKit
@testable import Lumen

final class ReadingSignalHandlerTests: XCTestCase {

    var handler: ReadingSignalHandler!

    override func setUp() {
        super.setUp()
        handler = ReadingSignalHandler(config: .default)
    }

    func testExcludesBankingKeywordInHost() {
        XCTAssertTrue(handler.isExcluded(urlString: "https://mybank.com/dashboard"))
    }

    func testExcludesBankingKeywordInSubdomain() {
        XCTAssertTrue(handler.isExcluded(urlString: "https://online.banking.example.com"))
    }

    func testExcludesAccountKeywordInHost() {
        XCTAssertTrue(handler.isExcluded(urlString: "https://myaccount.google.com"))
    }

    func testExcludesHealthKeywordInHost() {
        XCTAssertTrue(handler.isExcluded(urlString: "https://patient.healthportal.com"))
    }

    func testExcludesGmailExactHost() {
        XCTAssertTrue(handler.isExcluded(urlString: "https://mail.google.com/mail/u/0/#inbox"))
    }

    func testExcludesOutlookExactHost() {
        XCTAssertTrue(handler.isExcluded(urlString: "https://outlook.com/mail/inbox"))
    }

    func testAllowsNormalArticle() {
        XCTAssertFalse(handler.isExcluded(urlString: "https://example.com/article"))
    }

    func testAllowsNewsArticle() {
        XCTAssertFalse(
            handler.isExcluded(urlString: "https://www.nytimes.com/2026/01/01/tech/story.html")
        )
    }

    func testExcludesInvalidURL() {
        XCTAssertTrue(handler.isExcluded(urlString: "not-a-url"))
    }

    func testCustomConfigExclusionKeywordIsRespected() {
        var custom = ReadingSignalConfig.default
        custom.excludedHostKeywords = ["secret"]
        let customHandler = ReadingSignalHandler(config: custom)
        XCTAssertTrue(customHandler.isExcluded(urlString: "https://secret.example.com"))
        XCTAssertFalse(customHandler.isExcluded(urlString: "https://example.com"))
    }

    func testCustomConfigExcludedHostIsRespected() {
        var custom = ReadingSignalConfig.default
        custom.excludedHosts = ["private.company.com"]
        let customHandler = ReadingSignalHandler(config: custom)
        XCTAssertTrue(customHandler.isExcluded(urlString: "https://private.company.com/dashboard"))
    }

    func testCallbackFiredForValidPayload() {
        let expectation = expectation(description: "callback fired")
        handler.onReadingSignalTriggered = { payload in
            XCTAssertEqual(payload.url, "https://example.com/article")
            XCTAssertEqual(payload.readingTime, 35)
            expectation.fulfill()
        }

        handler.process(body: [
            "url": "https://example.com/article",
            "title": "Test",
            "readingTime": 35,
            "scrollDepth": 0.6,
            "triggered": true
        ])

        waitForExpectations(timeout: 1)
    }

    func testCallbackNotFiredWhenTriggeredFalse() {
        var called = false
        handler.onReadingSignalTriggered = { _ in called = true }

        handler.process(body: [
            "url": "https://example.com/article",
            "title": "Test",
            "readingTime": 35,
            "scrollDepth": 0.6,
            "triggered": false
        ])

        XCTAssertFalse(called)
    }

    func testCallbackNotFiredForExcludedURL() {
        var called = false
        handler.onReadingSignalTriggered = { _ in called = true }

        handler.process(body: [
            "url": "https://mybank.com/dashboard",
            "title": "Bank",
            "readingTime": 60,
            "scrollDepth": 0.9,
            "triggered": true
        ])

        XCTAssertFalse(called)
    }

    func testCallbackNotFiredForMalformedBody() {
        var called = false
        handler.onReadingSignalTriggered = { _ in called = true }

        handler.process(body: ["garbage": "data"])

        XCTAssertFalse(called)
    }
}
