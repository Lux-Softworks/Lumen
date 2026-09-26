import Foundation
import Testing
@testable import Lumen

@MainActor
struct KnowledgeLibraryEditingTests {
    @Test func removedPageDisappearsFromReadingSessions() {
        let kept = PageContent(id: "page_kept", websiteID: "w1", url: "https://example.com/a", title: "Kept", content: "")
        let removed = PageContent(id: "page_removed", websiteID: "w1", url: "https://example.com/b", title: "Removed", content: "")
        let viewModel = KnowledgeWebsiteViewModel(
            website: Website(id: "w1", domain: "example.com", pageCount: 2),
            pages: [kept, removed]
        )

        viewModel.removePage(id: "page_removed")

        #expect(viewModel.sessions.flatMap(\.pages).map(\.id) == ["page_kept"])
    }

    @Test func removedPageLowersWebsitePageCount() {
        let kept = PageContent(id: "page_kept", websiteID: "w1", url: "https://example.com/a", title: "Kept", content: "")
        let removed = PageContent(id: "page_removed", websiteID: "w1", url: "https://example.com/b", title: "Removed", content: "")
        let viewModel = KnowledgeWebsiteViewModel(
            website: Website(id: "w1", domain: "example.com", pageCount: 2),
            pages: [kept, removed]
        )

        viewModel.removePage(id: "page_removed")

        #expect(viewModel.website.pageCount == 1)
    }

    @Test func categorizedWebsiteCanMoveToOtherTopicsOrUncategorized() {
        let topics = [
            Topic(id: "topic_ai", name: "AI"),
            Topic(id: "topic_finance", name: "Finance")
        ]
        let website = Website(domain: "example.com", topicID: "topic_ai")

        let destinations = KnowledgeMenuViewModel.moveDestinations(for: website, among: topics)

        #expect(destinations.map(\.name) == ["Finance", "Uncategorized"])
    }

    @Test func uncategorizedWebsiteCanMoveToAnyNamedTopic() {
        let topics = [
            Topic(id: "topic_ai", name: "AI"),
            Topic(id: "topic_finance", name: "Finance"),
            Topic(id: Topic.uncategorizedID, name: Topic.uncategorizedName)
        ]
        let website = Website(domain: "example.com", topicID: nil)

        let destinations = KnowledgeMenuViewModel.moveDestinations(for: website, among: topics)

        #expect(destinations.map(\.name) == ["AI", "Finance"])
    }
}
