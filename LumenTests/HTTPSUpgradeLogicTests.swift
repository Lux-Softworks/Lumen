import Testing
import Foundation
@testable import Lumen

struct HTTPSUpgradeLogicTests {
    @Test func httpsAllowed() {
        let url = URL(string: "https://example.com")!
        #expect(HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: true) == .allow)
    }

    @Test func aboutBlankAllowed() {
        let url = URL(string: "about:blank")!
        #expect(HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: true) == .allow)
    }

    @Test func httpUpgradedWhenHttpsOnly() {
        let url = URL(string: "http://example.com/path?q=1")!
        let action = HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: true)
        #expect(action == .upgrade(URL(string: "https://example.com/path?q=1")!))
    }

    @Test func httpAllowedWhenHttpsOnlyDisabled() {
        let url = URL(string: "http://example.com")!
        #expect(HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: false) == .allow)
    }

    @Test func unknownSchemeCancelled() {
        let url = URL(string: "ftp://example.com/file")!
        #expect(HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: true) == .cancel)
    }

    @Test func customSchemeCancelled() {
        let url = URL(string: "myapp://open")!
        #expect(HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: true) == .cancel)
    }

    @Test func fileSchemeAllowed() {
        let url = URL(string: "file:///tmp/download.pdf")!
        #expect(HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: true) == .allow)
    }

    @Test func mixedCaseHttpUpgraded() {
        let url = URL(string: "HTTP://Example.com/")!
        let action = HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: true)
        guard case .upgrade(let upgraded) = action else {
            Issue.record("expected upgrade, got \(action)")
            return
        }
        #expect(upgraded.scheme == "https")
    }
}
