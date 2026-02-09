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

    func testBrowserEngineConfiguration_mediaTypesRequiringUserActionForPlayback() {
        // Case 1: Auto-play disabled (default)
        var policy = PrivacyPolicy()
        policy.allowsMediaAutoPlay = false
        var config = BrowserEngine.makeConfiguration(policy: policy)
        XCTAssertEqual(config.mediaTypesRequiringUserActionForPlayback, .all, "Auto-play should be disabled (require user action for all) when allowsMediaAutoPlay is false")

        // Case 2: Auto-play enabled
        policy.allowsMediaAutoPlay = true
        config = BrowserEngine.makeConfiguration(policy: policy)
        XCTAssertEqual(config.mediaTypesRequiringUserActionForPlayback, [], "Auto-play should be enabled (require user action for none) when allowsMediaAutoPlay is true")
    }

}
