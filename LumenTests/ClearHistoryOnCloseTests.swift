import SwiftUI
import Testing
@testable import Lumen

@MainActor
@Suite(.serialized)
struct ClearHistoryOnCloseTests {
    @Test func goingToBackgroundClearsPageHistoryWhenEnabled() {
        HistoryStore.shared.record(url: "https://lumen-test.invalid/page", title: "Test page")

        ClearHistoryOnClose.handle(.background, isEnabled: true)

        #expect(HistoryStore.shared.entries.isEmpty)
    }

    @Test func goingToBackgroundClearsSearchHistoryWhenEnabled() {
        SearchHistoryStore.shared.record(query: "lumen test query", isIncognito: false)

        ClearHistoryOnClose.handle(.background, isEnabled: true)

        #expect(SearchHistoryStore.shared.entries.isEmpty)
    }

    @Test func goingToBackgroundKeepsHistoryWhenDisabled() {
        HistoryStore.shared.record(url: "https://lumen-test.invalid/kept", title: "Kept page")

        ClearHistoryOnClose.handle(.background, isEnabled: false)

        #expect(HistoryStore.shared.entries.first?.title == "Kept page")
    }

    @Test func becomingInactiveKeepsHistory() {
        HistoryStore.shared.record(url: "https://lumen-test.invalid/inactive", title: "Inactive page")

        ClearHistoryOnClose.handle(.inactive, isEnabled: true)

        #expect(HistoryStore.shared.entries.first?.title == "Inactive page")
    }
}
