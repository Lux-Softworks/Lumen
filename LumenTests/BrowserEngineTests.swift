import WebKit
import XCTest

@testable import Lumen

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

    func testMakeConfiguration_AirPlayForMediaPlayback_Disabled() {
        var policy = PrivacyPolicy()
        policy.allowsAirPlayForMediaPlayback = false
        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertFalse(config.allowsAirPlayForMediaPlayback)
    }

    func testMakeConfiguration_AirPlayForMediaPlayback_Enabled() {
        var policy = PrivacyPolicy()
        policy.allowsAirPlayForMediaPlayback = true
        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertTrue(config.allowsAirPlayForMediaPlayback)
    }

    func testMakeConfiguration_PictureInPictureMediaPlayback_Disabled() {
        var policy = PrivacyPolicy()
        policy.allowsPictureInPictureMediaPlayback = false
        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertFalse(config.allowsPictureInPictureMediaPlayback)
    }

    func testMakeConfiguration_PictureInPictureMediaPlayback_Enabled() {
        var policy = PrivacyPolicy()
        policy.allowsPictureInPictureMediaPlayback = true
        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertTrue(config.allowsPictureInPictureMediaPlayback)
    }

    func testMakeConfiguration_FileAccess_Disabled() {
        let policy = PrivacyPolicy()
        let config = BrowserEngine.makeConfiguration(policy: policy)

        // Using KVC to check the value as it's not a direct property in some versions
        let fileAccess = config.preferences.value(forKey: "allowFileAccessFromFileURLs") as? Bool
        let universalAccess =
            config.preferences.value(forKey: "allowUniversalAccessFromFileURLs") as? Bool

        XCTAssertEqual(fileAccess, false)
        XCTAssertEqual(universalAccess, false)
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
        policy.customUserAgent = "LumenBot/1.0"
        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertEqual(config.applicationNameForUserAgent, "LumenBot/1.0")
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

    func testMakeWebView_IsInspectableDisabled() {
        if #available(iOS 16.4, *) {
            let policy = PrivacyPolicy()
            let webView = BrowserEngine.makeWebView(policy: policy)

            XCTAssertFalse(webView.isInspectable)
        }
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

    func testMakeConfiguration_RegistersReadingSignalScript() {
        let policy = PrivacyPolicy()
        let config = BrowserEngine.makeConfiguration(policy: policy)

        let script = config.userContentController.userScripts.first {
            $0.source.contains("lumenReadingSignalInstalled")
        }
        XCTAssertNotNil(script)

        let defaultConfig = ReadingSignalConfig.default
        XCTAssertTrue(script!.source.contains("DWELL_THRESHOLD = \(defaultConfig.dwellThresholdSeconds)"))
        XCTAssertTrue(script!.source.contains("SCROLL_THRESHOLD = \(defaultConfig.scrollDepthThreshold)"))
        XCTAssertTrue(script!.source.contains("POLL_INTERVAL_MS = \(defaultConfig.pollIntervalMs)"))
    }
}
