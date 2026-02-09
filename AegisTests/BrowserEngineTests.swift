import XCTest
import WebKit
@testable import Aegis

final class BrowserEngineTests: XCTestCase {

    func testMakeConfiguration_DefaultPolicy() {
        // Arrange
        let policy = PrivacyPolicy()

        // Act
        let config = BrowserEngine.makeConfiguration(policy: policy)

        // Assert
        // Check if the data store is non-persistent.
        // Note: WKWebsiteDataStore.nonPersistent() returns a store that is not persistent.
        XCTAssertFalse(config.websiteDataStore.isPersistent, "WebsiteDataStore should be non-persistent")

        XCTAssertNotNil(config.userContentController, "UserContentController should be set")

        XCTAssertEqual(config.allowsInlineMediaPlayback, policy.allowsInlineMediaPlayback, "allowsInlineMediaPlayback should match policy")

        if #available(iOS 16.0, *) {
            XCTAssertEqual(config.mediaTypesRequiringUserActionForPlayback, [], "mediaTypesRequiringUserActionForPlayback should be empty on iOS 16+")
        } else {
            // Note: requiresUserActionForMediaPlayback is deprecated but used in BrowserEngine for < iOS 16
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
        // Arrange
        var policy = PrivacyPolicy()
        // Default allowsJavaScript is true, so set to false to test change
        policy.allowsJavaScript = false
        // Default allowsInlineMediaPlayback is false, so set to true
        policy.allowsInlineMediaPlayback = true
        // Default javaScriptCanOpenWindowsAutomatically is false, so set to true
        policy.javaScriptCanOpenWindowsAutomatically = true
        // Default suppressesIncrementalRendering is true, so set to false
        policy.suppressesIncrementalRendering = false
        // Default customUserAgent is nil, so set to value
        policy.customUserAgent = "CustomUserAgentString"

        // Act
        let config = BrowserEngine.makeConfiguration(policy: policy)

        // Assert
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
}
