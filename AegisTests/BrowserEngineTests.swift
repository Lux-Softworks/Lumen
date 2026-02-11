import XCTest
import WebKit
@testable import Aegis

final class BrowserEngineTests: XCTestCase {
    func testMakeRequest_CachePolicy() {
        let url = URL(string: "https://example.com")!
        let request = BrowserEngine.makeRequest(url: url)

        XCTAssertEqual(request.cachePolicy, .useProtocolCachePolicy)
    }

    func testMakeRequest_TimeoutInterval() {
        let url = URL(string: "https://example.com")!
        let request = BrowserEngine.makeRequest(url: url)

        XCTAssertEqual(request.timeoutInterval, 30)
    }

    func testMakeRequest_URL() {
        let url = URL(string: "https://example.com/path?query=value")!
        let request = BrowserEngine.makeRequest(url: url)

        XCTAssertEqual(request.url, url)
    }

    func testMakeConfiguration_NonPersistentDataStore() {
        let policy = PrivacyPolicy()
        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertFalse(config.websiteDataStore.isPersistent)
    }

    func testMakeConfiguration_InlineMediaPlayback_Disabled() {
        var policy = PrivacyPolicy()
        policy.allowsInlineMediaPlayback = false
        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertFalse(config.allowsInlineMediaPlayback)
    }

    func testMakeConfiguration_InlineMediaPlayback_Enabled() {
        var policy = PrivacyPolicy()
        policy.allowsInlineMediaPlayback = true
        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertTrue(config.allowsInlineMediaPlayback)
    }

    func testMakeConfiguration_AutoPlayDisabled() {
        var policy = PrivacyPolicy()
        policy.allowsMediaAutoPlay = false
        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertEqual(config.mediaTypesRequiringUserActionForPlayback, .all)
    }

    func testMakeConfiguration_AutoPlayEnabled() {
        var policy = PrivacyPolicy()
        policy.allowsMediaAutoPlay = true
        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertEqual(config.mediaTypesRequiringUserActionForPlayback, [])
    }

    func testMakeConfiguration_SuppressesIncrementalRendering() {
        var policy = PrivacyPolicy()
        policy.suppressesIncrementalRendering = true
        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertTrue(config.suppressesIncrementalRendering)
    }

    func testMakeConfiguration_FileAccessRestrictions() {
        let policy = PrivacyPolicy()
        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertFalse(config.preferences.allowFileAccessFromFileURLs)
        XCTAssertFalse(config.preferences.allowUniversalAccessFromFileURLs)
    }

    func testMakeConfiguration_JavaScriptCanOpenWindowsAutomatically_Disabled() {
        var policy = PrivacyPolicy()
        policy.javaScriptCanOpenWindowsAutomatically = false
        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertFalse(config.preferences.javaScriptCanOpenWindowsAutomatically)
    }

    func testMakeConfiguration_CustomUserAgent() {
        var policy = PrivacyPolicy()
        policy.customUserAgent = "AegisBot/1.0"
        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertEqual(config.applicationNameForUserAgent, "AegisBot/1.0")
    }

    func testMakeWebView_HasNavigationDelegate() {
        let policy = PrivacyPolicy()
        let webView = BrowserEngine.makeWebView(policy: policy)

        XCTAssertNotNil(webView.navigationDelegate)
    }

    func testMakeWebView_LinkPreviewDisabled() {
        let policy = PrivacyPolicy()
        let webView = BrowserEngine.makeWebView(policy: policy)

        XCTAssertFalse(webView.allowsLinkPreview)
    }

    func testDefaultPolicy_IsPrivacyFocused() {
        let policy = PrivacyPolicy()

        XCTAssertTrue(policy.blocksThirdPartyCookies)
        XCTAssertTrue(policy.allowsJavaScript)
        XCTAssertFalse(policy.allowsInlineMediaPlayback)
        XCTAssertFalse(policy.allowsPictureInPictureMediaPlayback)
        XCTAssertFalse(policy.allowsAirPlayForMediaPlayback)
        XCTAssertFalse(policy.allowsMediaAutoPlay)
        XCTAssertFalse(policy.javaScriptCanOpenWindowsAutomatically)
        XCTAssertTrue(policy.suppressesIncrementalRendering)
        XCTAssertTrue(policy.limitsNavigationToHTTPS)
        XCTAssertNil(policy.customUserAgent)
    }
}
