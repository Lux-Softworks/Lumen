import Testing
@testable import Lumen

struct AnswerValidityScorerTests {
    @Test func highMatchAtOrAboveThreshold() {
        #expect(AnswerValidityScorer.match(for: 0.55) == .high)
        #expect(AnswerValidityScorer.match(for: 0.99) == .high)
    }

    @Test func mediumMatchInRange() {
        #expect(AnswerValidityScorer.match(for: 0.25) == .medium)
        #expect(AnswerValidityScorer.match(for: 0.54) == .medium)
    }

    @Test func lowMatchBelowThreshold() {
        #expect(AnswerValidityScorer.match(for: 0.0) == .low)
        #expect(AnswerValidityScorer.match(for: 0.24) == .low)
    }

    @Test func negativeValidityIsLow() {
        #expect(AnswerValidityScorer.match(for: -0.5) == .low)
    }

    @Test func refusalAnswerSuppressesBadge() {
        let answer = "You don't have a library."
        #expect(AnswerValidityScorer.match(answer: answer, validity: 0.9) == nil)
    }

    @Test func didNotReadAnswerSuppressesBadge() {
        let answer = "You didn't read an article."
        #expect(AnswerValidityScorer.match(answer: answer, validity: 0.8) == nil)
    }

    @Test func shortAnswerCapsAtMedium() {
        let answer = "Real Madrid won."
        #expect(AnswerValidityScorer.match(answer: answer, validity: 0.9) == .medium)
    }

    @Test func substantiveAnswerKeepsHigh() {
        let answer = "Real Madrid signed a new midfielder this week, with the transfer fee reportedly exceeding sixty million euros, and Barcelona offered a counter bid before withdrawing late yesterday."
        #expect(AnswerValidityScorer.match(answer: answer, validity: 0.7) == .high)
    }
}
