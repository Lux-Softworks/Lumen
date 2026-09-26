import Testing
@testable import Lumen

struct TopicVoteTests {
    @Test func clearWinnerWins() {
        let winner = TopicVote.majority(
            counts: [("t_ai", 5), ("t_food", 2)], current: "t_food")
        #expect(winner == "t_ai")
    }

    @Test func tieKeepsCurrent() {
        let winner = TopicVote.majority(
            counts: [("t_ai", 3), ("t_food", 3)], current: "t_food")
        #expect(winner == "t_food")
    }

    @Test func tieWithoutCurrentIsDeterministic() {
        let winner = TopicVote.majority(
            counts: [("t_food", 3), ("t_ai", 3)], current: nil)
        #expect(winner == "t_ai")
    }

    @Test func noVotesKeepsCurrent() {
        let winner = TopicVote.majority(counts: [], current: "t_ai")
        #expect(winner == "t_ai")
    }
}
