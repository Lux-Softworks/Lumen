import XCTest
@testable import Aegis

final class ThreatDetectorTests: XCTestCase {

    var detector: ThreatDetector!

    override func setUp() {
        super.setUp()
        
        detector = ThreatDetector()
        detector.loadTrackerDatabase([
            "doubleclick.net": ThreatDetector.TrackerInfo(
                entityName: "Google LLC",
                category: .advertising,
                domains: ["doubleclick.net", "google-analytics.com"]
            ),
            "facebook.net": ThreatDetector.TrackerInfo(
                entityName: "Meta Platforms",
                category: .social,
                domains: ["facebook.net", "facebook.com"]
            ),
            "analytics.example.com": ThreatDetector.TrackerInfo(
                entityName: "Example Analytics",
                category: .analytics,
                domains: ["analytics.example.com"]
            )
        ])
    }

    override func tearDown() {
        detector = nil
        super.tearDown()
    }

    func testClassifyRequest_ThirdParty() {
        let requestURL = URL(string: "https://tracker.doubleclick.net/pixel")!
        let pageURL = URL(string: "https://www.nytimes.com/article")!
        XCTAssertTrue(detector.classifyRequest(requestURL: requestURL, pageURL: pageURL))
    }

    func testClassifyRequest_FirstParty() {
        let requestURL = URL(string: "https://cdn.nytimes.com/style.css")!
        let pageURL = URL(string: "https://www.nytimes.com/article")!
        XCTAssertFalse(detector.classifyRequest(requestURL: requestURL, pageURL: pageURL))
    }

    func testExtractRegistrableDomain_Subdomain() {
        XCTAssertEqual(detector.extractRegistrableDomain(from: "sub.tracker.doubleclick.net"), "doubleclick.net")
    }

    func testExtractRegistrableDomain_BareDomain() {
        XCTAssertEqual(detector.extractRegistrableDomain(from: "example.com"), "example.com")
    }

    func testDetectTracker_KnownDomain() {
        let request = InterceptedRequest(
            url: URL(string: "https://ad.doubleclick.net/pixel?cb=123")!,
            pageURL: URL(string: "https://www.nytimes.com")!,
            headers: [:],
            isThirdParty: true,
            resourceType: .image,
            timestamp: Date()
        )

        let events = detector.analyze(request)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.type, .tracker)
        XCTAssertEqual(events.first?.entity?.name, "Google LLC")
        XCTAssertEqual(events.first?.severity, .high)
    }

    func testDetectTracker_FirstParty_NoDetection() {
        let request = InterceptedRequest(
            url: URL(string: "https://www.nytimes.com/api/data")!,
            pageURL: URL(string: "https://www.nytimes.com")!,
            headers: [:],
            isThirdParty: false,
            resourceType: .xhr,
            timestamp: Date()
        )

        let events = detector.analyze(request)
        XCTAssertTrue(events.isEmpty)
    }

    func testDetectTracker_UnknownDomain_NoDetection() {
        let request = InterceptedRequest(
            url: URL(string: "https://cdn.someunknown.com/lib.js")!,
            pageURL: URL(string: "https://www.nytimes.com")!,
            headers: [:],
            isThirdParty: true,
            resourceType: .script,
            timestamp: Date()
        )

        let events = detector.analyze(request)
        let trackerEvents = events.filter { $0.type == .tracker }
        XCTAssertTrue(trackerEvents.isEmpty)
    }

    func testDetectFingerprinting_KnownScript() {
        let request = InterceptedRequest(
            url: URL(string: "https://cdn.example.com/fingerprintjs/v3.js")!,
            pageURL: URL(string: "https://www.shop.com")!,
            headers: [:],
            isThirdParty: true,
            resourceType: .script,
            timestamp: Date()
        )

        let events = detector.analyze(request)
        let fpEvents = events.filter { $0.type == .fingerprinter }
        XCTAssertEqual(fpEvents.count, 1)
        XCTAssertEqual(fpEvents.first?.severity, .critical)
    }

    func testDetectFingerprinting_NonScript_NoDetection() {
        let request = InterceptedRequest(
            url: URL(string: "https://cdn.example.com/fingerprintjs/logo.png")!,
            pageURL: URL(string: "https://www.shop.com")!,
            headers: [:],
            isThirdParty: true,
            resourceType: .image,
            timestamp: Date()
        )

        let events = detector.analyze(request)
        let fpEvents = events.filter { $0.type == .fingerprinter }
        XCTAssertTrue(fpEvents.isEmpty)
    }

    func testDetectDataExfiltration_SuspiciousParams() {
        let request = InterceptedRequest(
            url: URL(string: "https://tracker.ad.com/collect?email=test@mail.com&device_id=abc123&uid=xyz")!,
            pageURL: URL(string: "https://www.shop.com")!,
            headers: [:],
            isThirdParty: true,
            resourceType: .xhr,
            timestamp: Date()
        )

        let events = detector.analyze(request)
        let exfilEvents = events.filter { $0.type == .dataExfiltration }
        XCTAssertEqual(exfilEvents.count, 1)
        XCTAssertEqual(exfilEvents.first?.severity, .critical)
    }

    func testDetectDataExfiltration_NoSuspiciousParams_NoDetection() {
        let request = InterceptedRequest(
            url: URL(string: "https://tracker.ad.com/collect?page=home&ref=google")!,
            pageURL: URL(string: "https://www.shop.com")!,
            headers: [:],
            isThirdParty: true,
            resourceType: .xhr,
            timestamp: Date()
        )

        let events = detector.analyze(request)
        let exfilEvents = events.filter { $0.type == .dataExfiltration }
        XCTAssertTrue(exfilEvents.isEmpty)
    }

    func testDetectCookieAbuse_SyncIndicators() {
        let request = InterceptedRequest(
            url: URL(string: "https://sync.ad-network.com/match?partner_id=abc&sync=1")!,
            pageURL: URL(string: "https://www.news.com")!,
            headers: [:],
            isThirdParty: true,
            resourceType: .image,
            timestamp: Date()
        )

        let events = detector.analyze(request)
        let cookieEvents = events.filter { $0.type == .cookieAbuse }
        XCTAssertEqual(cookieEvents.count, 1)
        XCTAssertEqual(cookieEvents.first?.severity, .high)
    }

    func testDetectCryptominer_KnownDomain() {
        let request = InterceptedRequest(
            url: URL(string: "https://coinhive.com/lib/coinhive.min.js")!,
            pageURL: URL(string: "https://www.sketchy-site.com")!,
            headers: [:],
            isThirdParty: true,
            resourceType: .script,
            timestamp: Date()
        )

        let events = detector.analyze(request)
        let minerEvents = events.filter { $0.type == .cryptominer }
        XCTAssertEqual(minerEvents.count, 1)
        XCTAssertEqual(minerEvents.first?.severity, .critical)
    }

    func testDetectCryptominer_UnknownDomain_NoDetection() {
        let request = InterceptedRequest(
            url: URL(string: "https://legit-cdn.com/app.js")!,
            pageURL: URL(string: "https://www.shop.com")!,
            headers: [:],
            isThirdParty: true,
            resourceType: .script,
            timestamp: Date()
        )

        let events = detector.analyze(request)
        let minerEvents = events.filter { $0.type == .cryptominer }
        XCTAssertTrue(minerEvents.isEmpty)
    }

    func testMultipleThreatsFromSingleRequest() {
        let request = InterceptedRequest(
            url: URL(string: "https://ad.doubleclick.net/collect?email=test@mail.com&uid=abc&partner_id=xyz&sync=1")!,
            pageURL: URL(string: "https://www.nytimes.com")!,
            headers: [:],
            isThirdParty: true,
            resourceType: .xhr,
            timestamp: Date()
        )

        let events = detector.analyze(request)
        XCTAssertGreaterThanOrEqual(events.count, 2)

        let types = Set(events.map { $0.type })
        XCTAssertTrue(types.contains(.tracker))
        XCTAssertTrue(types.contains(.dataExfiltration) || types.contains(.cookieAbuse))
    }

    func testDelegateCalledOnDetection() {
        let expectation = self.expectation(description: "Delegate called")
        let mockDelegate = MockThreatDetectorDelegate()
        mockDelegate.onDetect = { _ in expectation.fulfill() }
        detector.delegate = mockDelegate

        let request = InterceptedRequest(
            url: URL(string: "https://ad.doubleclick.net/pixel")!,
            pageURL: URL(string: "https://www.nytimes.com")!,
            headers: [:],
            isThirdParty: true,
            resourceType: .image,
            timestamp: Date()
        )

        _ = detector.analyze(request)
        waitForExpectations(timeout: 1.0)
    }

    func testThreatSeverityComparable() {
        XCTAssertTrue(ThreatSeverity.low < ThreatSeverity.medium)
        XCTAssertTrue(ThreatSeverity.medium < ThreatSeverity.high)
        XCTAssertTrue(ThreatSeverity.high < ThreatSeverity.critical)
        XCTAssertFalse(ThreatSeverity.critical < ThreatSeverity.low)
    }

    func testThreatEventCodable() throws {
        let event = ThreatEvent(
            id: UUID(),
            timestamp: Date(),
            type: .tracker,
            severity: .high,
            sourceURL: URL(string: "https://tracker.com/p")!,
            sourceDomain: "tracker.com",
            pageURL: URL(string: "https://example.com")!,
            entity: ThreatEntity(
                name: "Tracker Inc",
                domains: ["tracker.com"],
                category: .advertising,
                privacyPolicyURL: nil,
                abuseContactEmail: "abuse@tracker.com"
            ),
            details: "Test event",
            dataAtRisk: [.browsingHistory]
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(ThreatEvent.self, from: data)

        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.type, event.type)
        XCTAssertEqual(decoded.severity, event.severity)
        XCTAssertEqual(decoded.entity?.name, event.entity?.name)
    }
}

private final class MockThreatDetectorDelegate: ThreatDetectorDelegate {
    var onDetect: ((ThreatEvent) -> Void)?

    func threatDetector(_ detector: ThreatDetector, didDetect event: ThreatEvent) {
        onDetect?(event)
    }
}
