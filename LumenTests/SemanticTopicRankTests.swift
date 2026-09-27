import Testing
@testable import Lumen

struct SemanticTopicRankTests {
    @Test func clearWinnerReturnsBestAndCandidates() {
        let result = SemanticTopicClassifier.rank([
            (name: "AI", score: 0.61),
            (name: "Programming", score: 0.44),
            (name: "Technology", score: 0.41),
            (name: "Food", score: 0.12)
        ])
        #expect(result.best == "AI")
        #expect(result.candidates == ["AI", "Programming", "Technology"])
    }

    @Test func nearTieStillReturnsProvisionalBest() {
        let result = SemanticTopicClassifier.rank([
            (name: "AI", score: 0.502),
            (name: "Programming", score: 0.499)
        ])
        #expect(result.best == "AI")
        #expect(result.candidates == ["AI", "Programming"])
    }

    @Test func allBelowFloorReturnsNothing() {
        let result = SemanticTopicClassifier.rank([
            (name: "AI", score: 0.10),
            (name: "Food", score: 0.05)
        ])
        #expect(result.best == nil)
        #expect(result.candidates.isEmpty)
    }

    @Test func candidatesExcludeBelowFloorEntries() {
        let result = SemanticTopicClassifier.rank([
            (name: "AI", score: 0.55),
            (name: "Food", score: 0.08)
        ])
        #expect(result.candidates == ["AI"])
    }
}
