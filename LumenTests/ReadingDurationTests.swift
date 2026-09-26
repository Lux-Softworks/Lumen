import Foundation
import Testing
@testable import Lumen

struct ReadingDurationTests {
    @Test func underAMinuteReadsAsLessThanOneMinute() {
        #expect(ReadingDuration.label(seconds: 45) == "<1m")
    }

    @Test func wholeMinutesDropLeftoverSeconds() {
        #expect(ReadingDuration.label(seconds: 150) == "2m")
    }

    @Test func exactlyOneHourReadsAsHours() {
        #expect(ReadingDuration.label(seconds: 3600) == "1h")
    }

    @Test func overAnHourShowsHoursAndMinutes() {
        #expect(ReadingDuration.label(seconds: 3900) == "1h 5m")
    }

    @Test func sessionHeaderShowsSummedSecondsAsMinutes() {
        let session = ReadingSession(
            id: UUID(),
            date: Date(),
            pages: [
                PageContent(websiteID: "w1", url: "https://example.com/a", title: "A", content: "", readingTime: 90),
                PageContent(websiteID: "w1", url: "https://example.com/b", title: "B", content: "", readingTime: 100)
            ]
        )

        #expect(session.headerLabel == "Today · 2 pages · 3m")
    }

    @Test func sessionHeaderOmitsTimeWhenNothingWasRead() {
        let session = ReadingSession(
            id: UUID(),
            date: Date(),
            pages: [
                PageContent(websiteID: "w1", url: "https://example.com/a", title: "A", content: "")
            ]
        )

        #expect(session.headerLabel == "Today · 1 page")
    }
}
