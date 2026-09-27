import Testing
@testable import Lumen

@MainActor
struct RelevanceGateTests {
    private func page(_ title: String, content: String) -> PageContent {
        PageContent(
            websiteID: "site",
            url: "https://example.com/\(title)",
            title: title,
            content: content,
            summary: nil
        )
    }

    @Test func missingOneTermNoLongerDiscards() {
        let ranked = [
            (page: page("A", content: "swift concurrency actors isolation"), score: 0.6),
            (page: page("B", content: "swift concurrency tasks"), score: 0.55)
        ]
        let kept = KnowledgeAIViewModel.relevanceGated(
            ranked, query: "swift concurrency actors", floor: 0.30)
        #expect(kept.count == 2)
    }

    @Test func keepsAtLeastTwoWhenTwoPassMargin() {
        let ranked = [
            (page: page("A", content: "quantum computing qubits"), score: 0.6),
            (page: page("B", content: "completely unrelated gardening"), score: 0.55)
        ]
        let kept = KnowledgeAIViewModel.relevanceGated(
            ranked, query: "quantum computing", floor: 0.30)
        #expect(kept.count == 2)
    }

    @Test func rescuesTopTwoWhenBelowFloorButClose() {
        let ranked = [
            (page: page("A", content: "anything"), score: 0.27),
            (page: page("B", content: "anything"), score: 0.26),
            (page: page("C", content: "anything"), score: 0.10)
        ]
        let kept = KnowledgeAIViewModel.relevanceGated(
            ranked, query: "some question", floor: 0.30)
        #expect(kept.count == 2)
    }

    @Test func trulyIrrelevantStillReturnsNothing() {
        let ranked = [
            (page: page("A", content: "anything"), score: 0.12)
        ]
        let kept = KnowledgeAIViewModel.relevanceGated(
            ranked, query: "some question", floor: 0.30)
        #expect(kept.isEmpty)
    }

    @Test func majorityOfTermsRequiredForLexicalPassWithManyTerms() {
        let ranked = [
            (page: page("A", content: "espresso grinder brewing ratio water"), score: 0.6),
            (page: page("B", content: "espresso only"), score: 0.58)
        ]
        let kept = KnowledgeAIViewModel.relevanceGated(
            ranked, query: "espresso grinder brewing ratio", floor: 0.30)
        #expect(kept.first?.title == "A")
        #expect(kept.count == 2)
    }
}
