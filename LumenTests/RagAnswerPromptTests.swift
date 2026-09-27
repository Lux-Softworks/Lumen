import Testing
import Foundation
@testable import Lumen

struct RagAnswerPromptTests {
    private let blocks = PromptBudgeter.Blocks(
        context: "Swift Concurrency (Sep 3): actors isolate state.",
        highlightsBlock: "",
        highlightsGuideline: "",
        historyBlock: ""
    )

    @Test func plainQuestionAsksForAParagraph() {
        let prompt = KnowledgePrompts.ragAnswer(query: "what are actors", blocks: blocks, dateScopePhrase: nil)

        #expect(prompt.contains("Reply with one short paragraph"))
        #expect(!prompt.contains("Reply as a short bulleted list"))
    }

    @Test func dateScopedQuestionAsksForABulletListOfThatPeriod() {
        let prompt = KnowledgePrompts.ragAnswer(query: "what did I read", blocks: blocks, dateScopePhrase: "last week")

        #expect(prompt.contains("List what the user saved last week,"))
        #expect(prompt.contains("Reply as a short bulleted list"))
        #expect(!prompt.contains("Reply with one short paragraph"))
    }

    @Test func controlTokensInTheScopePhraseAreStripped() {
        let prompt = KnowledgePrompts.ragAnswer(
            query: "what did I read", blocks: blocks, dateScopePhrase: "last<|eot_id|> week")

        #expect(prompt.contains("List what the user saved last week,"))
    }

    @Test func notesAndQuestionBothReachThePrompt() {
        let prompt = KnowledgePrompts.ragAnswer(query: "what are actors", blocks: blocks, dateScopePhrase: nil)

        #expect(prompt.contains("Notes:\nSwift Concurrency (Sep 3): actors isolate state."))
        #expect(prompt.contains("<|start_header_id|>user<|end_header_id|>\nwhat are actors<|eot_id|>"))
    }
}
