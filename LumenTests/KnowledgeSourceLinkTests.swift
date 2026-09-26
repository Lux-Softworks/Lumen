import Foundation
import Testing
@testable import Lumen

struct KnowledgeSourceLinkTests {
    @Test func webPageSourceOpensItsSavedAddress() {
        let page = PageContent(websiteID: "w1", url: "https://example.com/article?id=4", title: "Article", content: "")

        #expect(KnowledgeSourceLink.url(for: page)?.absoluteString == "https://example.com/article?id=4")
    }

    @Test func scriptAddressIsNeverOpened() {
        let page = PageContent(websiteID: "w1", url: "javascript:alert(1)", title: "Script", content: "")

        #expect(KnowledgeSourceLink.url(for: page) == nil)
    }

    @Test func emptyAddressIsNeverOpened() {
        let page = PageContent(websiteID: "w1", url: "", title: "Blank", content: "")

        #expect(KnowledgeSourceLink.url(for: page) == nil)
    }
}
