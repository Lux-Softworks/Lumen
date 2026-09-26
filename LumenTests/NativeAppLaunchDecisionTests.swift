import Foundation
import Testing
@testable import Lumen

@MainActor
struct NativeAppLaunchDecisionTests {
    @Test func askPolicyAsksBeforeOpeningATappedAppLink() throws {
        let url = try #require(URL(string: "zoommtg://zoom.us/join?confno=1"))

        #expect(NativeAppLaunchDecision.decide(for: url, policy: .ask, isUserInitiated: true) == .ask)
    }

    @Test func alwaysOpenPolicyOpensATappedAppLink() throws {
        let url = try #require(URL(string: "zoommtg://zoom.us/join?confno=1"))

        #expect(NativeAppLaunchDecision.decide(for: url, policy: .always, isUserInitiated: true) == .open)
    }

    @Test func stayInBrowserPolicyKeepsATappedAppLinkInTheBrowser() throws {
        let url = try #require(URL(string: "zoommtg://zoom.us/join?confno=1"))

        #expect(NativeAppLaunchDecision.decide(for: url, policy: .never, isUserInitiated: true) == .stay)
    }

    @Test func appLinkTheUserDidNotTapStaysEvenWhenAlwaysOpen() throws {
        let url = try #require(URL(string: "zoommtg://zoom.us/join?confno=1"))

        #expect(NativeAppLaunchDecision.decide(for: url, policy: .always, isUserInitiated: false) == .stay)
    }

    @Test func webLinkIsNeverHandedToAnApp() throws {
        let url = try #require(URL(string: "https://zoom.us/join"))

        #expect(NativeAppLaunchDecision.decide(for: url, policy: .always, isUserInitiated: true) == .stay)
    }
}
