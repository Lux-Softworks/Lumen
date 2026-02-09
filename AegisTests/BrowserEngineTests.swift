final class BrowserEngineTests: XCTestCase {
    func testMakeConfiguration_DefaultPolicy() {
        let policy = PrivacyPolicy()

        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertFalse(config.websiteDataStore.isPersistent, "WebsiteDataStore should be non-persistent")

        XCTAssertNotNil(config.userContentController, "UserContentController should be set")

        XCTAssertEqual(config.allowsInlineMediaPlayback, policy.allowsInlineMediaPlayback, "allowsInlineMediaPlayback should match policy")

        if #available(iOS 16.0, *) {
            XCTAssertEqual(config.mediaTypesRequiringUserActionForPlayback, [], "mediaTypesRequiringUserActionForPlayback should be empty on iOS 16+")
        } else {
            XCTAssertTrue(config.requiresUserActionForMediaPlayback, "requiresUserActionForMediaPlayback should be true on < iOS 16")
        }

        if #available(iOS 14.0, *) {
            XCTAssertEqual(config.defaultWebpagePreferences.allowsContentJavaScript, policy.allowsJavaScript, "allowsContentJavaScript should match policy on iOS 14+")
        } else {
            XCTAssertEqual(config.preferences.javaScriptEnabled, policy.allowsJavaScript, "javaScriptEnabled should match policy on < iOS 14")
        }

        XCTAssertEqual(config.preferences.javaScriptCanOpenWindowsAutomatically, policy.javaScriptCanOpenWindowsAutomatically, "javaScriptCanOpenWindowsAutomatically should match policy")
        XCTAssertEqual(config.suppressesIncrementalRendering, policy.suppressesIncrementalRendering, "suppressesIncrementalRendering should match policy")

        XCTAssertNil(config.applicationNameForUserAgent, "applicationNameForUserAgent should be nil by default")
    }

    func testMakeConfiguration_CustomPolicy() {
        var policy = PrivacyPolicy()
      
        // set to opposites
        policy.allowsJavaScript = false
        policy.allowsInlineMediaPlayback = true
        policy.javaScriptCanOpenWindowsAutomatically = true
        policy.suppressesIncrementalRendering = false
        policy.customUserAgent = "CustomUserAgentString"

        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertTrue(config.allowsInlineMediaPlayback, "allowsInlineMediaPlayback should be true")

        if #available(iOS 14.0, *) {
            XCTAssertFalse(config.defaultWebpagePreferences.allowsContentJavaScript, "allowsContentJavaScript should be false")
        } else {
            XCTAssertFalse(config.preferences.javaScriptEnabled, "javaScriptEnabled should be false")
        }

        XCTAssertTrue(config.preferences.javaScriptCanOpenWindowsAutomatically, "javaScriptCanOpenWindowsAutomatically should be true")
        XCTAssertFalse(config.suppressesIncrementalRendering, "suppressesIncrementalRendering should be false")

        XCTAssertEqual(config.applicationNameForUserAgent, "CustomUserAgentString", "applicationNameForUserAgent should match custom user agent")
    }
  
    func testCustomUserAgentApplication() {
        var policy = PrivacyPolicy()
        let customUA = "CustomUserAgent/1.0"
        policy.customUserAgent = customUA

        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertEqual(config.applicationNameForUserAgent, customUA, "The custom user agent suffix should be applied.")
    }

    func testDefaultUserAgent() {
        var policy = PrivacyPolicy()
        policy.customUserAgent = nil

        let config = BrowserEngine.makeConfiguration(policy: policy)

        XCTAssertNil(config.applicationNameForUserAgent)
    }

    func testPrivacyPolicyDefaults() {
        let policy = PrivacyPolicy()

        XCTAssertTrue(policy.blocksThirdPartyCookies)
        XCTAssertTrue(policy.allowsJavaScript)
        XCTAssertFalse(policy.allowsInlineMediaPlayback)
        XCTAssertFalse(policy.allowsPictureInPictureMediaPlayback)
        XCTAssertFalse(policy.allowsAirPlayForMediaPlayback)
        XCTAssertFalse(policy.javaScriptCanOpenWindowsAutomatically)
        XCTAssertTrue(policy.suppressesIncrementalRendering)
        XCTAssertTrue(policy.limitsNavigationToHTTPS)
        XCTAssertNil(policy.customUserAgent)
    }
  
    func testWebViewInspectionDisabled() {
        if #available(iOS 16.4, *) {
            let policy = PrivacyPolicy()
            let webView = BrowserEngine.makeWebView(policy: policy)
          
            XCTAssertFalse(webView.isInspectable, "WebView should not be inspectable by default for privacy.")
        }
    }

    func testPolicyDecision_AllowedSchemes() {
        let httpsURL = URL(string: "https://example.com")!
        let aboutURL = URL(string: "about:blank")!

        XCTAssertEqual(HTTPSOnlyNavigationDelegate.policyDecision(for: httpsURL, isHTTPSOnly: true), .allow)
        XCTAssertEqual(HTTPSOnlyNavigationDelegate.policyDecision(for: aboutURL, isHTTPSOnly: true), .allow)
    }

    func testPolicyDecision_BlockedSchemes() {
        let ftpURL = URL(string: "ftp://example.com")!
        let fileURL = URL(string: "file:///etc/passwd")!

        XCTAssertEqual(HTTPSOnlyNavigationDelegate.policyDecision(for: ftpURL, isHTTPSOnly: true), .cancel)
        XCTAssertEqual(HTTPSOnlyNavigationDelegate.policyDecision(for: fileURL, isHTTPSOnly: true), .cancel)
    }

    func testPolicyDecision_HTTP_Upgrades() {
        let httpURL = URL(string: "http://example.com/foo")!
        let expectedHTTPSURL = URL(string: "https://example.com/foo")!

        let decision = HTTPSOnlyNavigationDelegate.policyDecision(for: httpURL, isHTTPSOnly: true)

        if case .upgradeToHTTPS(let url) = decision {
            XCTAssertEqual(url, expectedHTTPSURL)
        } else {
            XCTFail("Expected .upgradeToHTTPS but got \(decision)")
        }
    }

    func testPolicyDecision_HTTPSOnlyDisabled() {
        let httpURL = URL(string: "http://example.com")!
        XCTAssertEqual(HTTPSOnlyNavigationDelegate.policyDecision(for: httpURL, isHTTPSOnly: false), .allow)
    }
}
