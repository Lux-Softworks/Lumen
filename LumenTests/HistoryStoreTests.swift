import Testing
@testable import Lumen

struct HistoryStoreTests {
    @Test func normalizeStripsScheme() {
        #expect(HistoryStore.normalizeURL("https://example.com") == "example.com")
        #expect(HistoryStore.normalizeURL("http://example.com") == "example.com")
    }

    @Test func normalizeStripsWww() {
        #expect(HistoryStore.normalizeURL("https://www.example.com") == "example.com")
    }

    @Test func normalizeStripsTrailingSlashes() {
        #expect(HistoryStore.normalizeURL("https://example.com/") == "example.com")
        #expect(HistoryStore.normalizeURL("https://example.com///") == "example.com")
    }

    @Test func normalizeCaseInsensitive() {
        #expect(HistoryStore.normalizeURL("HTTPS://EXAMPLE.COM") == "example.com")
    }

    @Test func stableIDDeterministicForSameURL() {
        let first = HistoryStore.stableID(for: "example.com/x")
        let second = HistoryStore.stableID(for: "example.com/x")
        #expect(first == second)
    }

    @Test func stableIDDiffersForDifferentURLs() {
        let first = HistoryStore.stableID(for: "example.com/x")
        let second = HistoryStore.stableID(for: "example.com/y")
        #expect(first != second)
    }

    @Test func stableIDLength() {
        let id = HistoryStore.stableID(for: "example.com")
        #expect(id.count == 16)
    }
}
