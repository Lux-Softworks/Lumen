import XCTest
import WebKit
@testable import Aegis

final class BrowserEngineTests: XCTestCase {

    func testPrivacyPolicyDefaults() {
        let policy = PrivacyPolicy()

        XCTAssertTrue(policy.blocksThirdPartyCookies, "Default blocksThirdPartyCookies should be true")
        XCTAssertTrue(policy.allowsJavaScript, "Default allowsJavaScript should be true")
        XCTAssertFalse(policy.allowsInlineMediaPlayback, "Default allowsInlineMediaPlayback should be false")
        XCTAssertFalse(policy.allowsPictureInPictureMediaPlayback, "Default allowsPictureInPictureMediaPlayback should be false")
        XCTAssertFalse(policy.allowsAirPlayForMediaPlayback, "Default allowsAirPlayForMediaPlayback should be false")
        XCTAssertFalse(policy.javaScriptCanOpenWindowsAutomatically, "Default javaScriptCanOpenWindowsAutomatically should be false")
        XCTAssertTrue(policy.suppressesIncrementalRendering, "Default suppressesIncrementalRendering should be true")
        XCTAssertTrue(policy.limitsNavigationToHTTPS, "Default limitsNavigationToHTTPS should be true")
        XCTAssertNil(policy.customUserAgent, "Default customUserAgent should be nil")
      
    func testWebViewInspectionDisabled() {
        if #available(iOS 16.4, *) {
            let policy = PrivacyPolicy()
            let webView = BrowserEngine.makeWebView(policy: policy)
          
            XCTAssertFalse(webView.isInspectable, "WebView should not be inspectable by default")
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
        let dataURL = URL(string: "data:text/html,Hello")!

        XCTAssertEqual(HTTPSOnlyNavigationDelegate.policyDecision(for: ftpURL, isHTTPSOnly: true), .cancel)
        XCTAssertEqual(HTTPSOnlyNavigationDelegate.policyDecision(for: fileURL, isHTTPSOnly: true), .cancel)
        XCTAssertEqual(HTTPSOnlyNavigationDelegate.policyDecision(for: dataURL, isHTTPSOnly: true), .cancel)
    }

    func testPolicyDecision_HTTP_Upgrades() {
        let httpURL = URL(string: "http://example.com/foo")!
        let expectedHTTPSURL = URL(string: "https://example.com/foo")!

        let decision = HTTPSOnlyNavigationDelegate.policyDecision(for: httpURL, isHTTPSOnly: true)

        if case .upgradeToHTTPS(let url) = decision {
            XCTAssertEqual(url, expectedHTTPSURL)
        } else {
            XCTFail("Expected upgradeToHTTPS, got \(decision)")
        }
    }

    func testPolicyDecision_HTTPSOnlyDisabled() {
        let httpURL = URL(string: "http://example.com")!
        XCTAssertEqual(HTTPSOnlyNavigationDelegate.policyDecision(for: httpURL, isHTTPSOnly: false), .allow)
    }
}
