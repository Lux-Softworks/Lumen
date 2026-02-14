import WebKit
import XCTest

@testable import Kratos

final class BrowserViewModelTests: XCTestCase {

    var viewModel: BrowserViewModel!

    override func setUp() {
        super.setUp()
        viewModel = BrowserViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(viewModel.urlString, "")
        XCTAssertNil(viewModel.currentURL)
        XCTAssertEqual(viewModel.pageTitle, "")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.canGoBack)
        XCTAssertFalse(viewModel.canGoForward)
        XCTAssertEqual(viewModel.estimatedProgress, 0.0)
        XCTAssertFalse(viewModel.isSecure)
        XCTAssertTrue(viewModel.threatEvents.isEmpty)
        XCTAssertEqual(viewModel.blockedTrackersCount, 0)
        XCTAssertNil(viewModel.webView)
    }

    func testClassifyInput_FullURL() {
        let url = BrowserViewModel.classifyInput("https://www.apple.com")
        XCTAssertEqual(url.absoluteString, "https://www.apple.com")
    }

    func testClassifyInput_HTTPUrl() {
        let url = BrowserViewModel.classifyInput("http://example.com")
        XCTAssertEqual(url.absoluteString, "http://example.com")
    }

    func testClassifyInput_BareDomain() {
        let url = BrowserViewModel.classifyInput("apple.com")
        XCTAssertEqual(url.absoluteString, "https://apple.com")
    }

    func testClassifyInput_DomainWithSubdomain() {
        let url = BrowserViewModel.classifyInput("www.github.com")
        XCTAssertEqual(url.absoluteString, "https://www.github.com")
    }

    func testClassifyInput_DomainWithPath() {
        let url = BrowserViewModel.classifyInput("github.com/user/repo")
        XCTAssertEqual(url.absoluteString, "https://github.com/user/repo")
    }

    func testClassifyInput_SearchQuery() {
        let url = BrowserViewModel.classifyInput("swift programming")
        XCTAssertTrue(url.absoluteString.contains("duckduckgo.com"))
        XCTAssertTrue(url.absoluteString.contains("swift"))
    }

    func testClassifyInput_SingleWordSearch() {
        let url = BrowserViewModel.classifyInput("weather")
        XCTAssertTrue(url.absoluteString.contains("duckduckgo.com"))
    }

    func testClassifyInput_EmptyString() {
        let url = BrowserViewModel.classifyInput("")
        XCTAssertEqual(url, BrowserViewModel.defaultURL)
    }

    func testClassifyInput_WhitespaceOnly() {
        let url = BrowserViewModel.classifyInput("   ")
        XCTAssertEqual(url, BrowserViewModel.defaultURL)
    }

    func testClassifyInput_AboutBlank() {
        let url = BrowserViewModel.classifyInput("about:blank")
        XCTAssertEqual(url.absoluteString, "about:blank")
    }

    func testClearPageState() {
        let event = ThreatEvent(
            id: UUID(),
            timestamp: Date(),
            type: .tracker,
            severity: .medium,
            sourceURL: URL(string: "https://tracker.com")!,
            sourceDomain: "tracker.com",
            pageURL: URL(string: "https://example.com")!,
            entity: nil,
            details: "Test",
            dataAtRisk: [.browsingHistory]
        )

        viewModel.threatEvents.append(event)
        viewModel.blockedTrackersCount = 1

        viewModel.clearPageState()

        XCTAssertTrue(viewModel.threatEvents.isEmpty)
        XCTAssertEqual(viewModel.blockedTrackersCount, 0)
    }

    func testPrivacySummary_NoThreats() {
        XCTAssertEqual(viewModel.privacySummary, "No threats detected")
    }

    func testPrivacySummary_SingleTracker() {
        viewModel.threatEvents.append(makeThreatEvent(type: .tracker))
        XCTAssertEqual(viewModel.privacySummary, "1 tracker")
    }

    func testPrivacySummary_MultipleTypes() {
        viewModel.threatEvents.append(makeThreatEvent(type: .tracker))
        viewModel.threatEvents.append(makeThreatEvent(type: .tracker))
        viewModel.threatEvents.append(makeThreatEvent(type: .fingerprinter))
        viewModel.threatEvents.append(makeThreatEvent(type: .cryptominer))

        let summary = viewModel.privacySummary
        XCTAssertTrue(summary.contains("2 trackers"))
        XCTAssertTrue(summary.contains("1 fingerprinter"))
        XCTAssertTrue(summary.contains("1 miner"))
    }

    func testAttachWebView_SetsWebView() {
        let webView = BrowserEngine.makeWebView(policy: PrivacyPolicy())
        viewModel.attachWebView(webView)

        XCTAssertNotNil(viewModel.webView)
        XCTAssertTrue(viewModel.webView === webView)
    }

    func testAttachWebView_ConnectsInterceptor() {
        let webView = BrowserEngine.makeWebView(policy: PrivacyPolicy())
        viewModel.attachWebView(webView)

        XCTAssertNotNil(webView.navigationDelegate)
    }

    func testNavigate_SetsURLString() {
        let webView = BrowserEngine.makeWebView(policy: PrivacyPolicy())
        viewModel.attachWebView(webView)

        viewModel.navigate(to: "https://example.com")
        XCTAssertEqual(viewModel.urlString, "https://example.com")
    }

    func testNavigate_BareDomain() {
        let webView = BrowserEngine.makeWebView(policy: PrivacyPolicy())
        viewModel.attachWebView(webView)

        viewModel.navigate(to: "example.com")
        XCTAssertEqual(viewModel.urlString, "https://example.com")
    }

    func testNavigate_SearchQuery() {
        let webView = BrowserEngine.makeWebView(policy: PrivacyPolicy())
        viewModel.attachWebView(webView)

        viewModel.navigate(to: "hello world")
        XCTAssertTrue(viewModel.urlString.contains("duckduckgo.com"))
    }

    func testLoadHomePage() {
        let webView = BrowserEngine.makeWebView(policy: PrivacyPolicy())
        viewModel.attachWebView(webView)

        viewModel.loadHomePage()
        XCTAssertEqual(viewModel.urlString, BrowserViewModel.defaultURL.absoluteString)
    }

    private func makeThreatEvent(type: ThreatType) -> ThreatEvent {
        ThreatEvent(
            id: UUID(),
            timestamp: Date(),
            type: type,
            severity: .medium,
            sourceURL: URL(string: "https://threat.example.com")!,
            sourceDomain: "threat.example.com",
            pageURL: URL(string: "https://example.com")!,
            entity: nil,
            details: "Test \(type.rawValue) event",
            dataAtRisk: [.browsingHistory]
        )
    }
}
