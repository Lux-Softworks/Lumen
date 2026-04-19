import Testing
@testable import Lumen

struct AnswerValidityScorerTests {
    @Test func highMatchAtOrAboveThreshold() {
        #expect(AnswerValidityScorer.match(for: 0.45) == .high)
        #expect(AnswerValidityScorer.match(for: 0.99) == .high)
    }

    @Test func mediumMatchInRange() {
        #expect(AnswerValidityScorer.match(for: 0.20) == .medium)
        #expect(AnswerValidityScorer.match(for: 0.44) == .medium)
    }

    @Test func lowMatchBelowThreshold() {
        #expect(AnswerValidityScorer.match(for: 0.0) == .low)
        #expect(AnswerValidityScorer.match(for: 0.19) == .low)
    }

    @Test func negativeValidityIsLow() {
        #expect(AnswerValidityScorer.match(for: -0.5) == .low)
    }
}
