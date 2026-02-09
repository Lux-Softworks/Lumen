import XCTest
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
    }
}
