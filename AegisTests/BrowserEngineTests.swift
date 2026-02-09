//
//  BrowserEngineTests.swift
//  AegisTests
//
//  Created by Jules on 12/22/25.
//

import XCTest
@testable import Aegis
import WebKit

final class BrowserEngineTests: XCTestCase {

    func testCustomUserAgentApplication() {
        // Given
        var policy = PrivacyPolicy()
        let customUA = "CustomUserAgent/1.0"
        policy.customUserAgent = customUA

        // When
        let config = BrowserEngine.makeConfiguration(policy: policy)

        // Then
        XCTAssertEqual(config.applicationNameForUserAgent, customUA, "The custom user agent should be applied to the configuration.")
    }

    func testDefaultUserAgent() {
        // Given
        var policy = PrivacyPolicy()
        policy.customUserAgent = nil

        // When
        let config = BrowserEngine.makeConfiguration(policy: policy)

        // Then
        XCTAssertNil(config.applicationNameForUserAgent, "The application name for user agent should be nil when no custom user agent is provided.")
    }
}
