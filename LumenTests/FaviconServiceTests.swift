import Foundation
import Testing
@testable import Lumen

@MainActor
struct FaviconServiceTests {
    @Test func iconIsRequestedFromTheSiteItself() {
        let url = FaviconService.faviconURL(for: URL(string: "https://news.example.com/story?id=4")!)

        #expect(url?.absoluteString == "https://news.example.com/favicon.ico")
    }

    @Test func iconForPlainHTTPPageIsRequestedOverHTTPS() {
        let url = FaviconService.faviconURL(for: URL(string: "http://example.com/")!)

        #expect(url?.absoluteString == "https://example.com/favicon.ico")
    }

    @Test func pageWithoutHostHasNoIcon() {
        let url = FaviconService.faviconURL(for: URL(string: "about:blank")!)

        #expect(url == nil)
    }
}
