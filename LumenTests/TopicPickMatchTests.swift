import Testing
@testable import Lumen

@MainActor
struct TopicPickMatchTests {
    @Test func exactMatchWins() {
        let match = LocalKnowledgeProvider.matchCandidate(
            output: "Finance", candidates: ["Finance", "Business", "Politics"])
        #expect(match == "Finance")
    }

    @Test func caseAndWhitespaceInsensitive() {
        let match = LocalKnowledgeProvider.matchCandidate(
            output: "  finance\n", candidates: ["Finance", "Business"])
        #expect(match == "Finance")
    }

    @Test func prefixedRamblePicksLeadingCandidate() {
        let match = LocalKnowledgeProvider.matchCandidate(
            output: "Finance because the article covers rates",
            candidates: ["Finance", "Business"])
        #expect(match == "Finance")
    }

    @Test func unknownOutputMatchesNothing() {
        let match = LocalKnowledgeProvider.matchCandidate(
            output: "Cooking", candidates: ["Finance", "Business"])
        #expect(match == nil)
    }

    @Test func promptContainsNoBracketPlaceholders() {
        let prompt = KnowledgePrompts.topicPick(
            summary: "The Fed held rates steady.", candidates: ["Finance", "Politics"])
        #expect(!prompt.contains("["))
    }
}
