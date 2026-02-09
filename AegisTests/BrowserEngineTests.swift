import XCTest
import WebKit
@testable import Aegis

final class BrowserEngineTests: XCTestCase {

    func testWebViewInspectionDisabled() {
        if #available(iOS 16.4, *) {
            let policy = PrivacyPolicy()
            let webView = BrowserEngine.makeWebView(policy: policy)
            XCTAssertFalse(webView.isInspectable, "WebView should not be inspectable by default")
        }
    }
}
