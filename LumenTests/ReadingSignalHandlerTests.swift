import XCTest
import WebKit
@testable import Lumen

final class ReadingSignalHandlerTests: XCTestCase {

    var handler: ReadingSignalHandler!

    override func setUp() {
        super.setUp()
        handler = ReadingSignalHandler(config: .default)
    }

    func test_excludesBankingKeywordInHost() {
        XCTAssertTrue(handler.isExcluded(urlString: "https://mybank.com/dashboard"))
    }

    func test_excludesBankingKeywordInSubdomain() {
        XCTAssertTrue(handler.isExcluded(urlString: "https://online.banking.example.com"))
    }

    func test_excludesAccountKeywordInHost() {
        XCTAssertTrue(handler.isExcluded(urlString: "https://myaccount.google.com"))
    }

    func test_excludesHealthKeywordInHost() {
        XCTAssertTrue(handler.isExcluded(urlString: "https://patient.healthportal.com"))
    }

    func test_excludesGmailExactHost() {
        XCTAssertTrue(handler.isExcluded(urlString: "https://mail.google.com/mail/u/0/#inbox"))
    }

    func test_excludesOutlookExactHost() {
        XCTAssertTrue(handler.isExcluded(urlString: "https://outlook.com/mail/inbox"))
    }

    func test_allowsNormalArticle() {
        XCTAssertFalse(handler.isExcluded(urlString: "https://example.com/article"))
    }

    func test_allowsNewsArticle() {
        XCTAssertFalse(
            handler.isExcluded(urlString: "https://www.nytimes.com/2026/01/01/tech/story.html")
        )
    }

    func test_excludesInvalidURL() {
        XCTAssertTrue(handler.isExcluded(urlString: "not-a-url"))
    }

    func test_customConfigExclusionKeywordIsRespected() {
        var custom = ReadingSignalConfig.default
        custom.excludedHostKeywords = ["secret"]
        let customHandler = ReadingSignalHandler(config: custom)
        XCTAssertTrue(customHandler.isExcluded(urlString: "https://secret.example.com"))
        XCTAssertFalse(customHandler.isExcluded(urlString: "https://example.com"))
    }

    func test_customConfigExcludedHostIsRespected() {
        var custom = ReadingSignalConfig.default
        custom.excludedHosts = ["private.company.com"]
        let customHandler = ReadingSignalHandler(config: custom)
        XCTAssertTrue(customHandler.isExcluded(urlString: "https://private.company.com/dashboard"))
    }

    func test_callbackFiredForValidPayload() {
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

    func test_callbackNotFiredWhenTriggeredFalse() {
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

    func test_callbackNotFiredForExcludedURL() {
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

    func test_callbackNotFiredForMalformedBody() {
        var called = false
        handler.onReadingSignalTriggered = { _ in called = true }

        handler.process(body: ["garbage": "data"])

        XCTAssertFalse(called)
    }
}
