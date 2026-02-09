//
//  AegisTests.swift
//  AegisTests
//
//  Created by Daniel Kosukhin on 12/22/25.
//

import XCTest
import WebKit
@testable import Aegis

// Mock classes for testing
class MockNavigationAction: WKNavigationAction {
    let _request: URLRequest

    init(url: URL) {
        self._request = URLRequest(url: url)
        super.init() // This might fail at runtime if init is not available/public, but serves for static verification logic
    }

    override var request: URLRequest {
        return _request
    }
}

class MockWebView: WKWebView {
    var lastLoadedRequest: URLRequest?

    override func load(_ request: URLRequest) -> WKNavigation? {
        lastLoadedRequest = request
        return nil
    }
}

final class AegisTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testHTTPSOnlyNavigationDelegate() {
        let delegate = HTTPSOnlyNavigationDelegate(enabled: true)
        let webView = MockWebView()

        // 1. Allowed HTTPS
        let httpsURL = URL(string: "https://example.com")!
        let actionHTTPS = MockNavigationAction(url: httpsURL)
        var expectation = self.expectation(description: "HTTPS Allowed")

        delegate.webView(webView, decidePolicyFor: actionHTTPS) { policy in
            XCTAssertEqual(policy, .allow)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // 2. HTTP Upgrade
        let httpURL = URL(string: "http://example.com")!
        let actionHTTP = MockNavigationAction(url: httpURL)
        expectation = self.expectation(description: "HTTP Upgraded")

        delegate.webView(webView, decidePolicyFor: actionHTTP) { policy in
            XCTAssertEqual(policy, .cancel)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertNotNil(webView.lastLoadedRequest)
        XCTAssertEqual(webView.lastLoadedRequest?.url?.scheme, "https")
        XCTAssertEqual(webView.lastLoadedRequest?.url?.host, "example.com")

        // 3. FTP Blocked
        let ftpURL = URL(string: "ftp://example.com")!
        let actionFTP = MockNavigationAction(url: ftpURL)
        expectation = self.expectation(description: "FTP Blocked")

        delegate.webView(webView, decidePolicyFor: actionFTP) { policy in
            XCTAssertEqual(policy, .cancel)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // 4. File Blocked
        let fileURL = URL(string: "file:///etc/passwd")!
        let actionFile = MockNavigationAction(url: fileURL)
        expectation = self.expectation(description: "File Blocked")

        delegate.webView(webView, decidePolicyFor: actionFile) { policy in
            XCTAssertEqual(policy, .cancel)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // 5. Javascript Blocked
        let jsURL = URL(string: "javascript:alert(1)")!
        let actionJS = MockNavigationAction(url: jsURL)
        expectation = self.expectation(description: "JS Blocked")

        delegate.webView(webView, decidePolicyFor: actionJS) { policy in
            XCTAssertEqual(policy, .cancel)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

}
