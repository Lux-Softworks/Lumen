//
//  AegisTests.swift
//  AegisTests
//
//  Created by Daniel Kosukhin on 12/22/25.
//

import XCTest
import WebKit
@testable import Aegis

final class AegisTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testURLStringComparisonPerformance() throws {
        guard let url1 = URL(string: "https://www.example.com/path/to/resource"),
              let url2 = URL(string: "https://www.example.com/path/to/resource"),
              let url3 = URL(string: "https://www.example.com/other/path") else {
            XCTFail("Failed to create URLs")
            return
        }

        self.measure {
            for _ in 0..<100_000 {
                let _ = url1.absoluteString != url2.absoluteString
                let _ = url1.absoluteString != url3.absoluteString
            }
        }
    }

    func testURLObjectComparisonPerformance() throws {
        guard let url1 = URL(string: "https://www.example.com/path/to/resource"),
              let url2 = URL(string: "https://www.example.com/path/to/resource"),
              let url3 = URL(string: "https://www.example.com/other/path") else {
            XCTFail("Failed to create URLs")
            return
        }

        // direct url comparison
        self.measure {
            for _ in 0..<100_000 {
                let _ = url1 != url2
                let _ = url1 != url3
            }
        }
      
    func testBrowserEngineConfiguration_mediaTypesRequiringUserActionForPlayback() {
        var policy = PrivacyPolicy()
        policy.allowsMediaAutoPlay = false
      
        var config = BrowserEngine.makeConfiguration(policy: policy)
        XCTAssertEqual(config.mediaTypesRequiringUserActionForPlayback, .all, "Auto-play should be disabled (require user action for all) when allowsMediaAutoPlay is false")

        policy.allowsMediaAutoPlay = true
        config = BrowserEngine.makeConfiguration(policy: policy)
        XCTAssertEqual(config.mediaTypesRequiringUserActionForPlayback, [], "Auto-play should be enabled (require user action for none) when allowsMediaAutoPlay is true")
    }

}
