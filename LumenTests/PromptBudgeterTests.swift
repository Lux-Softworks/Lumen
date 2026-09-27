import Testing
import Foundation
@testable import Lumen

struct PromptBudgeterTests {
    private func page(title: String, content: String, summary: String? = nil) -> PageContent {
        PageContent(
            websiteID: "test-site",
            url: "https://example.com/\(title.lowercased())",
            title: title,
            content: content,
            summary: summary
        )
    }

    @Test func emptySourcesProduceEmptyContext() {
        let blocks = PromptBudgeter.build(
            query: "hello",
            sources: [],
            highlights: [],
            history: []
        )
        #expect(blocks.context.isEmpty)
        #expect(blocks.highlightsBlock.isEmpty)
        #expect(blocks.historyBlock.isEmpty)
    }

    @Test func contextIncludesFirstThreeSources() {
        let sources = (1...5).map {
            page(title: "Page\($0)", content: String(repeating: "word ", count: 200))
        }
        let blocks = PromptBudgeter.build(
            query: "tell me",
            sources: sources,
            highlights: [],
            history: []
        )
        #expect(blocks.context.contains("Page1"))
        #expect(blocks.context.contains("Page2"))
        #expect(blocks.context.contains("Page3"))
        #expect(!blocks.context.contains("Page4"))
    }

    @Test func contextRespectsBudget() {
        let huge = String(repeating: "a", count: 100_000)
        let sources = [page(title: "Doc", content: huge)]
        let blocks = PromptBudgeter.build(
            query: "q",
            sources: sources,
            highlights: [],
            history: []
        )
        #expect(blocks.context.count < PromptBudgeter.maxInputChars)
    }

    @Test func highlightsBlockPopulatedWhenProvided() {
        let blocks = PromptBudgeter.build(
            query: "q",
            sources: [page(title: "Doc", content: "body body")],
            highlights: ["important passage about closures"],
            history: []
        )
        #expect(blocks.highlightsBlock.contains("closures"))
        #expect(!blocks.highlightsGuideline.isEmpty)
    }

    @Test func historyBlockIncludesPriorUserQuestions() {
        let history: [(role: String, text: String)] = [
            ("user", "first question about Swift"),
            ("assistant", "some answer"),
            ("user", "second question about concurrency")
        ]
        let blocks = PromptBudgeter.build(
            query: "follow up",
            sources: [page(title: "Doc", content: "body")],
            highlights: [],
            history: history
        )
        #expect(blocks.historyBlock.contains("second question"))
    }

    @Test func conversationSummaryIncluded() {
        let summary = String(repeating: "priorContext ", count: 20)
        let blocks = PromptBudgeter.build(
            query: "q",
            sources: [page(title: "Doc", content: "body")],
            highlights: [],
            history: [],
            conversationSummary: summary
        )
        #expect(blocks.historyBlock.contains("Earlier in conversation"))
    }
}
