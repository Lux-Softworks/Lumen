import WebKit
import XCTest

@testable import Lumen

@MainActor
final class NetworkInterceptorTests: XCTestCase {

    var detector: ThreatDetector!
    var interceptor: NetworkInterceptor!

    override func setUp() async throws {
        try await super.setUp()
        detector = ThreatDetector()
        let entries = await TrackerDatabase.shared.allEntries()
        detector.loadTrackerDatabase(entries)
        interceptor = NetworkInterceptor(detector: detector, httpsOnly: true)
    }

    override func tearDown() {
        interceptor = nil
        detector = nil
        super.tearDown()
    }

    func testInitialState_Empty() {
        XCTAssertTrue(interceptor.requestLog.isEmpty)
        XCTAssertTrue(interceptor.detectedThreats.isEmpty)
        XCTAssertNil(interceptor.currentPageURL)
    }

    func testClearSession() {
        interceptor.clearSession()
        XCTAssertTrue(interceptor.requestLog.isEmpty)
        XCTAssertTrue(interceptor.detectedThreats.isEmpty)
        XCTAssertNil(interceptor.currentPageURL)
    }

    func testThreatCallbackFires() {
        let expectation = self.expectation(description: "Threat callback")

        interceptor.onThreatDetected = { event in
            XCTAssertEqual(event.type, .tracker)
            expectation.fulfill()
        }

        let request = InterceptedRequest(
            url: URL(string: "https://ad.doubleclick.net/pixel")!,
            pageURL: URL(string: "https://www.example.com")!,
            headers: [:],
            isThirdParty: true,
            resourceType: .image,
            timestamp: Date()
        )

        let _ = detector.analyze(request)
        waitForExpectations(timeout: 1.0)
    }

    func testThreatDetectedAppendedToList() {
        let request = InterceptedRequest(
            url: URL(string: "https://ad.doubleclick.net/pixel")!,
            pageURL: URL(string: "https://www.example.com")!,
            headers: [:],
            isThirdParty: true,
            resourceType: .image,
            timestamp: Date()
        )

        let _ = detector.analyze(request)
        XCTAssertFalse(interceptor.detectedThreats.isEmpty)
        XCTAssertEqual(interceptor.detectedThreats.first?.entity?.name, "Google")
    }

    func testMultipleThreatsAccumulate() {
        let urls = [
            "https://ad.doubleclick.net/pixel",
            "https://connect.facebook.net/sdk.js",
            "https://cdn.hotjar.com/track.js",
        ]

        for urlString in urls {
            let request = InterceptedRequest(
                url: URL(string: urlString)!,
                pageURL: URL(string: "https://www.example.com")!,
                headers: [:],
                isThirdParty: true,
                resourceType: .script,
                timestamp: Date()
            )
            let _ = detector.analyze(request)
        }

        XCTAssertGreaterThanOrEqual(interceptor.detectedThreats.count, 3)
    }

    func testClearSessionResetsThreats() {
        let request = InterceptedRequest(
            url: URL(string: "https://ad.doubleclick.net/pixel")!,
            pageURL: URL(string: "https://www.example.com")!,
            headers: [:],
            isThirdParty: true,
            resourceType: .image,
            timestamp: Date()
        )

        let _ = detector.analyze(request)
        XCTAssertFalse(interceptor.detectedThreats.isEmpty)

        interceptor.clearSession()
        XCTAssertTrue(interceptor.detectedThreats.isEmpty)
    }
}
