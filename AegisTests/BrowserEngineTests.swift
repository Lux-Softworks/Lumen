import XCTest
@testable import Aegis

final class BrowserEngineTests: XCTestCase {

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
