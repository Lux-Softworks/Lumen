import XCTest

@testable import Kratos

final class HTTPSUpgradeLogicTests: XCTestCase {

    // MARK: - HTTPS Only Disabled

    func testHTTPSOnlyDisabled_AllowsHTTP() {
        let url = URL(string: "http://example.com")!
        let action = HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: false)
        XCTAssertEqual(action, .allow)
    }

    func testHTTPSOnlyDisabled_AllowsHTTPS() {
        let url = URL(string: "https://example.com")!
        let action = HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: false)
        XCTAssertEqual(action, .allow)
    }

    // MARK: - HTTPS Only Enabled

    func testHTTPSOnlyEnabled_UpgradesHTTP() {
        let url = URL(string: "http://example.com")!
        let action = HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: true)

        if case .upgrade(let newURL) = action {
            XCTAssertEqual(newURL.absoluteString, "https://example.com")
        } else {
            XCTFail("Expected upgrade, got \(action)")
        }
    }

    func testHTTPSOnlyEnabled_AllowsHTTPS() {
        let url = URL(string: "https://example.com")!
        let action = HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: true)
        XCTAssertEqual(action, .allow)
    }

    func testHTTPSOnlyEnabled_AllowsOtherSchemes() {
        let aboutURL = URL(string: "about:blank")!
        XCTAssertEqual(HTTPSUpgradeLogic.decidePolicy(for: aboutURL, httpsOnly: true), .allow)

        let fileURL = URL(string: "file:///path/to/file")!
        XCTAssertEqual(HTTPSUpgradeLogic.decidePolicy(for: fileURL, httpsOnly: true), .allow)
    }

    func testHTTPSOnlyEnabled_BlocksUnsafeSchemes() {
        let ftpURL = URL(string: "ftp://example.com/file")!
        XCTAssertEqual(HTTPSUpgradeLogic.decidePolicy(for: ftpURL, httpsOnly: true), .cancel)

        let javascriptURL = URL(string: "javascript:alert(1)")!
        XCTAssertEqual(HTTPSUpgradeLogic.decidePolicy(for: javascriptURL, httpsOnly: true), .cancel)

        let dataURL = URL(string: "data:text/html,<html></html>")!
        XCTAssertEqual(HTTPSUpgradeLogic.decidePolicy(for: dataURL, httpsOnly: true), .cancel)
    }

    func testHTTPSOnlyDisabled_BlocksDangerousSchemes() {
        let ftpURL = URL(string: "ftp://example.com/file")!
        XCTAssertEqual(HTTPSUpgradeLogic.decidePolicy(for: ftpURL, httpsOnly: false), .cancel)

        let javascriptURL = URL(string: "javascript:alert(1)")!
        XCTAssertEqual(HTTPSUpgradeLogic.decidePolicy(for: javascriptURL, httpsOnly: false), .cancel)

        let dataURL = URL(string: "data:text/html,<html></html>")!
        XCTAssertEqual(HTTPSUpgradeLogic.decidePolicy(for: dataURL, httpsOnly: false), .cancel)
    }

    func testUpgradePreservesPathAndQuery() {
        let url = URL(string: "http://example.com/foo/bar?q=baz&id=123")!
        let action = HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: true)

        if case .upgrade(let newURL) = action {
            XCTAssertEqual(newURL.absoluteString, "https://example.com/foo/bar?q=baz&id=123")
        } else {
            XCTFail("Expected upgrade, got \(action)")
        }
    }

    func testUpgradeHandlesCaseInsensitiveScheme() {
        let url = URL(string: "HTTP://example.com")!
        let action = HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: true)

        if case .upgrade(let newURL) = action {
            XCTAssertEqual(newURL.absoluteString, "https://example.com")
        } else {
            XCTFail("Expected upgrade, got \(action)")
        }
    }

    func testURLWithoutScheme_Cancels() {
        if let url = URL(string: "example.com") {
            // scheme is nil
            let action = HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: true)
            XCTAssertEqual(action, .cancel)
        }
    }
}
