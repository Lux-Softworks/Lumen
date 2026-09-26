import Foundation
import Testing
@testable import Lumen

@MainActor
struct DisconnectListTests {
    @Test func invasiveFingerprintingClassifiesAsFingerprinting() {
        #expect(DisconnectList.category(forKey: "FingerprintingInvasive") == .fingerprinting)
    }

    @Test func generalFingerprintingClassifiesAsFingerprinting() {
        #expect(DisconnectList.category(forKey: "FingerprintingGeneral") == .fingerprinting)
    }

    @Test func emailClassifiesAsEmail() {
        #expect(DisconnectList.category(forKey: "Email") == .email)
    }

    @Test func aggressiveEmailClassifiesAsEmail() {
        #expect(DisconnectList.category(forKey: "EmailAggressive") == .email)
    }

    @Test func everyCategoryInTheBundledListClassifies() throws {
        let url = try #require(Bundle.main.url(forResource: "disconnect-services", withExtension: "json"))
        let entries = DisconnectList.entries(from: try Data(contentsOf: url))
        let categories = Set(entries.map(\.categoryKey)).map(DisconnectList.category(forKey:))

        #expect(categories.count == 11)
        #expect(!categories.contains(.unknown))
    }

    @Test func entityDomainsSkipNonListFlags() throws {
        let json = #"""
            {"categories":{"Analytics":[{"RecCo":{"https://rec.example/":["rec.example"],"session-replay":"true"}}]}}
            """#

        let entries = DisconnectList.entries(from: try #require(json.data(using: .utf8)))

        #expect(entries == [DisconnectEntry(categoryKey: "Analytics", entityName: "RecCo", domains: ["rec.example"])])
    }
}
