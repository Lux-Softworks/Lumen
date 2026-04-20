import Foundation
import Observation

nonisolated private let KnowledgeWebsiteSessionGapThreshold: TimeInterval = 7200

struct ReadingSession: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let pages: [PageContent]

    var totalReadingTime: Int {
        pages.compactMap(\.readingTime).reduce(0, +)
    }

    var headerLabel: String {
        let dateLabel = ReadingSession.formatDate(date)
        let count = pages.count
        let mins = totalReadingTime
        let timeStr = mins > 0 ? " · \(mins)m" : ""
        let pageStr = count == 1 ? "1 page" : "\(count) pages"
        return "\(dateLabel) · \(pageStr)\(timeStr)"
    }

    static func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        if date > weekAgo { return DateFormatters.weekday.string(from: date) }
        return DateFormatters.monthDay.string(from: date)
    }
}

enum SynthesisState: Equatable {
    case idle
    case generating
    case ready(String)
    case failed
}

@Observable
@MainActor
final class KnowledgeWebsiteViewModel {
    private(set) var website: Website
    private(set) var sessions: [ReadingSession] = []
    private(set) var synthesisState: SynthesisState = .idle

    init(website: Website, pages: [PageContent]) {
        self.website = website
        self.sessions = Self.clusterIntoSessions(pages)
    }

    static func clusterIntoSessions(
        _ pages: [PageContent],
        gapThreshold: TimeInterval = KnowledgeWebsiteSessionGapThreshold
    ) -> [ReadingSession] {
        guard !pages.isEmpty else { return [] }

        let sorted = pages.sorted { $0.timestamp > $1.timestamp }

        var sessions: [ReadingSession] = []
        var currentGroup: [PageContent] = []

        for page in sorted {
            if let last = currentGroup.last {
                let gap = last.timestamp.timeIntervalSince(page.timestamp)
                if gap > gapThreshold {
                    sessions.append(ReadingSession(
                        id: UUID(),
                        date: currentGroup.last?.timestamp ?? last.timestamp,
                        pages: currentGroup
                    ))
                    currentGroup = []
                }
            }
            currentGroup.append(page)
        }

        if !currentGroup.isEmpty {
            sessions.append(ReadingSession(
                id: UUID(),
                date: currentGroup.last?.timestamp ?? currentGroup[0].timestamp,
                pages: currentGroup
            ))
        }

        return sessions
    }

    func loadSynthesis() async {
        if case .generating = synthesisState { return }

        if let existingSummary = website.summary,
           !existingSummary.isEmpty,
           let _ = website.synthesisUpdatedAt,
           website.pageCountAtSynthesis >= website.pageCount {
            synthesisState = .ready(existingSummary)
            return
        }

        let pages = sessions.flatMap(\.pages)
        let summaries = pages.compactMap(\.summary).filter { !$0.isEmpty }
        guard !summaries.isEmpty else {
            synthesisState = .failed
            return
        }

        synthesisState = .generating

        let result = await KnowledgeClassifier.synthesizeWebsiteReading(summaries: summaries)

        if result.isEmpty {
            synthesisState = .failed
            return
        }

        do {
            try await KnowledgeStorage.shared.updateWebsiteSynthesis(
                websiteID: website.id,
                summary: result,
                pageCount: website.pageCount
            )
            website.summary = result
            website.pageCountAtSynthesis = website.pageCount
            website.synthesisUpdatedAt = Date()
        } catch {}

        synthesisState = .ready(result)
    }
}

