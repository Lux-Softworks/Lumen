import XCTest
@testable import Aegis
import WebKit

final class BrowserEngineTests: XCTestCase {

    func testMediaAutoplayConfiguration() {
        let policy = PrivacyPolicy()
        let config = BrowserEngine.makeConfiguration(policy: policy)

        if #available(iOS 10.0, *) {
            // Verify that mediaTypesRequiringUserActionForPlayback is set to .all to prevent insecure autoplay
            // Note: On iOS 16+, the previous implementation insecurely set this to [], allowing all autoplay.
            // The fix sets it to .all.
            XCTAssertEqual(config.mediaTypesRequiringUserActionForPlayback, .all, "Media types requiring user action for playback should be .all to prevent insecure autoplay")
        } else {
            // Verify fallback for older iOS versions where mediaTypesRequiringUserActionForPlayback might not be available or used differently
             XCTAssertTrue(config.requiresUserActionForMediaPlayback, "requiresUserActionForMediaPlayback should be true for older iOS versions")
        }
    }
}
