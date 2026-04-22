import Foundation

enum PromptBudgeter {
    static let maxInputChars = 3600
    static let templateOverhead = 900
    static let minSourceChars = 140

    struct Blocks {
        let context: String
        let highlightsBlock: String
        let highlightsGuideline: String
        let historyBlock: String
    }

    static func build(
        query: String,
        sources: [PageContent],
        highlights: [String],
        history: [(role: String, text: String)],
        conversationSummary: String? = nil
    ) -> Blocks {
        let available = max(0, maxInputChars - templateOverhead - query.count)
        let sourcesBudget = Int(Double(available) * 0.60)
        let highlightsBudget = Int(Double(available) * 0.20)
        let historyBudget = available - sourcesBudget - highlightsBudget

        let context = buildContext(sources: sources, budget: sourcesBudget)
        let (highlightsBlock, highlightsGuideline) = buildHighlights(highlights: highlights, budget: highlightsBudget)
        let historyBlock = buildHistory(history: history, budget: historyBudget, summary: conversationSummary)

        return Blocks(
            context: context,
            highlightsBlock: highlightsBlock,
            highlightsGuideline: highlightsGuideline,
            historyBlock: historyBlock
        )
    }

    private static func buildContext(sources: [PageContent], budget: Int) -> String {
        let top = Array(sources.prefix(3))
        guard !top.isEmpty, budget > 0 else { return "" }

        let perSource = max(minSourceChars, budget / top.count)

        return top.map { page -> String in
            let label = page.title ?? page.domain
            let summary = page.summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let body = page.content.trimmingCharacters(in: .whitespacesAndNewlines)

            let labelOverhead = label.count + 2
            var remaining = max(0, perSource - labelOverhead)

            var parts: [String] = []
            if !summary.isEmpty {
                let take = min(summary.count, min(remaining, 200))
                parts.append(String(summary.prefix(take)))
                remaining -= take
            }
            if remaining > 40, !body.isEmpty {
                let take = min(body.count, remaining - 3)
                parts.append(String(body.prefix(take)))
            }

            return "\(label): \(parts.joined(separator: " — "))"
        }.joined(separator: "\n\n")
    }

    private static func buildHighlights(highlights: [String], budget: Int) -> (String, String) {
        let cleaned = highlights
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty, budget > 80 else { return ("", "") }

        var lines: [String] = []
        var used = 0
        let header = "\n\nUser-highlighted passages (strong signal, prioritize when relevant):\n"
        let headerCost = header.count
        let lineBudget = max(0, budget - headerCost)

        for highlight in cleaned.prefix(6) {
            let available = lineBudget - used
            if available < 30 { break }
            let take = min(highlight.count, min(available - 6, 240))
            if take <= 0 { break }
            let line = "- \"\(String(highlight.prefix(take)))\""
            lines.append(line)
            used += line.count + 1
        }

        guard !lines.isEmpty else { return ("", "") }

        let block = header + lines.joined(separator: "\n")
        let guideline = "\n- When user-highlighted passages are present, weight them heavily — user explicitly marked them as important."
        return (block, guideline)
    }

    private static func buildHistory(history: [(role: String, text: String)], budget: Int, summary: String?) -> String {
        guard budget > 60 else { return "" }

        var used = 0
        var lines: [String] = []

        if let summary, !summary.isEmpty {
            let cap = min(summary.count, max(0, budget - 60))
            if cap > 40 {
                let body = String(summary.prefix(cap))
                let line = "Earlier in conversation: \(body)"
                lines.append(line)
                used += line.count
            }
        }

        let recentUsers = history.suffix(6).filter { $0.role == "user" }.suffix(2)
        var priorQuestions: [String] = []
        for turn in recentUsers {
            let available = budget - used
            if available < 40 { break }
            let take = min(turn.text.count, min(available - 10, 160))
            if take <= 0 { break }
            let body = String(turn.text.prefix(take))
            priorQuestions.append("- \(body)")
            used += body.count + 4
        }
        if !priorQuestions.isEmpty {
            lines.append("Recent user questions:\n" + priorQuestions.joined(separator: "\n"))
        }

        guard !lines.isEmpty else { return "" }
        return "\n\n" + lines.joined(separator: "\n\n")
    }
}
