import Foundation
import Observation
import os
import UIKit

enum SparklePhase: Equatable {
    case idle
    case spinning
    case collapsing
}

@Observable
@MainActor
final class KnowledgeAIViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isThinking: Bool = false
    var isModelLoading: Bool = false
    var sparklePhase: SparklePhase = .idle
    var statusMessage: String? = nil

    private var activeTask: Task<Void, Never>?
    private var conversationSummary: String? = nil
    private var compactedThroughIndex: Int = 0
    private let autoCompactThreshold = 8
    private let keepRecentTurns = 3

    private static let thinkingMessages = [
        "Thinking…",
        "Pondering…",
        "Wondering…",
        "Reflecting…",
    ]

    private static let searchingMessages = [
        "Searching…",
        "Browsing…",
        "Scanning…",
        "Digging…",
    ]

    private static let compactingMessages = [
        "Condensing…",
        "Summarizing…",
    ]

    private func setStatus(_ message: String?) {
        statusMessage = message
    }

    func preloadModel() async {
        guard !isModelLoading else { return }

        isModelLoading = true
        sparklePhase = .spinning
        setStatus("Loading model…")

        do {
            try await LocalKnowledgeProvider.shared.loadModel()
        } catch {
            KnowledgeLogger.rag.error("model load failed: \(String(describing: error), privacy: .public)")
        }

        sparklePhase = .idle
        isModelLoading = false
        setStatus(nil)
    }

    func send() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isThinking, !isModelLoading else { return }

        inputText = ""
        let priorMessages = messages
        messages.append(ChatMessage(role: .user, text: trimmed))

        isThinking = true
        sparklePhase = .spinning
        setStatus(Self.thinkingMessages.randomElement()!)

        await maybeCompactHistory(priorMessages: priorMessages)

        let correction = await QueryCorrector.correct(trimmed)
        let query = correction.corrected

        let chatHistory: [(role: String, text: String)] = priorMessages.suffix(8).map { msg in
            (msg.role == .user ? "user" : "assistant", msg.text)
        }

        let forcedKnowledge = Self.looksLikeKnowledgeQuery(query)
        let isConversational =
            forcedKnowledge
            ? false
            : await LocalKnowledgeProvider.shared.classifyConversationalIntent(query: query, history: chatHistory)

        if isConversational {
            await respondConversationally(query: query, history: chatHistory)
            return
        }

        setStatus(Self.searchingMessages.randomElement()!)

        let correctionNote = correction.changed ? "Showing results for “\(query)”" : nil
        let parsedDate = DateQueryParser.parse(query)
        var searchResults: [PageContent] = []
        let weakMinScore = 0.30

        let priorSources =
            parsedDate == nil
            ? (priorMessages.last { $0.role == .assistant }?.sources ?? [])
            : []

        if let parsedDate {
            setStatus("Searching pages from \(parsedDate.phrase)…")
            let residual = parsedDate.cleanedQuery

            do {
                if isListAllQuery(residual) {
                    searchResults = try await KnowledgeStorage.shared.fetchPagesCreated(
                        in: parsedDate.range, limit: 6
                    )
                } else {
                    let scoped = try await KnowledgeStorage.shared.searchSemanticScoredInDateRange(
                        query: residual, range: parsedDate.range, limit: 6
                    )
                    searchResults = scoped.filter { $0.score >= weakMinScore }.map { $0.page }
                }
            } catch {
                finishThinking()
                messages.append(ChatMessage(role: .assistant, text: "Knowledge search failed."))
                return
            }

            if searchResults.isEmpty {
                finishThinking()
                let fallback = await emptyResultMessage(scopePhrase: parsedDate.phrase)
                messages.append(ChatMessage(role: .assistant, text: fallback))
                return
            }
        } else {
            let scored: [(page: PageContent, score: Double)]
            do {
                scored = try await KnowledgeStorage.shared.searchSemanticScored(query: query, limit: 6)
            } catch {
                finishThinking()
                messages.append(ChatMessage(role: .assistant, text: "Knowledge search failed."))
                return
            }

            var seenCandidate = Set<String>()
            var candidates: [PageContent] = []
            func addCandidate(_ page: PageContent) {
                if seenCandidate.insert(page.id).inserted { candidates.append(page) }
            }

            for entry in scored { addCandidate(entry.page) }

            let keywordHits =
                (try? await KnowledgeStorage.shared.searchPages(
                    query: ftsQuery(from: query), limit: 4
                )) ?? []
            for page in keywordHits { addCandidate(page) }

            for src in priorSources { addCandidate(src) }

            let reranked =
                (try? await KnowledgeStorage.shared.rerankByRelevance(
                    query: query, pages: candidates
                )) ?? []
            searchResults = Self.relevanceGated(reranked, query: query, floor: weakMinScore)
        }

        let sources = Array(searchResults.prefix(4))

        guard !sources.isEmpty else {
            finishThinking()
            let fallback = await emptyResultMessage(scopePhrase: nil)
            messages.append(ChatMessage(role: .assistant, text: fallback))
            return
        }

        let history: [(role: String, text: String)] = priorMessages.suffix(6).map { msg in
            (msg.role == .user ? "user" : "assistant", msg.text)
        }

        var highlights: [String] = []
        for page in sources {
            do {
                let anns = try await KnowledgeStorage.shared.fetchAnnotations(pageID: page.id)
                highlights.append(contentsOf: anns.map { $0.text })
            } catch {
                KnowledgeLogger.query.error(
                    "annotation fetch failed pageID=\(page.id, privacy: .public): \(String(describing: error), privacy: .public)"
                )
            }
        }

        let streamMessage = ChatMessage(
            role: .assistant, text: "", sources: sources, sourceMatch: nil, isStreaming: true,
            correctionNote: correctionNote)
        let streamMessageID = streamMessage.id
        messages.append(streamMessage)
        setStatus(Self.thinkingMessages.randomElement()!)

        let summary = conversationSummary
        let dateScopePhrase = parsedDate?.phrase

        let substance: [String: [String]] =
            parsedDate == nil
            ? ((try? await KnowledgeStorage.shared.topMatchingChunks(
                query: query, pageIDs: sources.map { $0.id }, perPage: 1, maxCharsPerChunk: 500
            )) ?? [:])
            : [:]

        let modelQuery = parsedDate == nil ? Self.topicQuestion(from: query) : query

        activeTask = Task {
            var raw = ""
            var streamError: Error? = nil
            let flushInterval: TimeInterval = 0.08
            var lastFlush = Date(timeIntervalSince1970: 0)

            @MainActor func streamingIndex() -> Int? {
                messages.firstIndex(where: { $0.id == streamMessageID })
            }

            @MainActor func flushIfDue(force: Bool = false) {
                let now = Date()
                guard force || now.timeIntervalSince(lastFlush) >= flushInterval else { return }
                lastFlush = now
                if let idx = streamingIndex(), messages[idx].text != raw {
                    messages[idx].text = raw
                }
            }

            do {
                let stream = await LocalKnowledgeProvider.shared.answerStreamFromKnowledge(
                    query: modelQuery, sources: sources, highlights: highlights, history: history,
                    conversationSummary: summary, dateScopePhrase: dateScopePhrase, substance: substance)
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    raw += chunk
                    flushIfDue()
                }
                flushIfDue(force: true)
            } catch {
                if Task.isCancelled { return }
                streamError = error
            }

            var modelProducedOutput = !raw.isEmpty

            if !modelProducedOutput, !Task.isCancelled {
                KnowledgeLogger.rag.error("empty stream output — retrying stream")
                do {
                    let retryStream = await LocalKnowledgeProvider.shared.answerStreamFromKnowledge(
                        query: modelQuery, sources: sources, highlights: highlights, history: history,
                        conversationSummary: summary, dateScopePhrase: dateScopePhrase, substance: substance)
                    for try await chunk in retryStream {
                        if Task.isCancelled { break }
                        raw += chunk
                        flushIfDue()
                    }
                    flushIfDue(force: true)
                    modelProducedOutput = !raw.isEmpty
                    streamError = nil
                } catch {
                    if Task.isCancelled { return }
                    streamError = error
                }
            }

            if !modelProducedOutput, streamError != nil {
                if let idx = streamingIndex() {
                    messages[idx].text = "Couldn't generate an answer."
                    messages[idx].isStreaming = false
                    messages[idx].sourceMatch = nil
                }
                finishThinking()
                return
            }

            var finalText = raw
            modelProducedOutput = !finalText.isEmpty

            if !modelProducedOutput {
                finalText = "No response generated for that query. Please try again."
            }

            if let idx = streamingIndex() {
                if messages[idx].text != finalText {
                    messages[idx].text = finalText
                }
                messages[idx].isStreaming = false
            }

            finishThinking()

            guard modelProducedOutput else { return }

            var scoredMatch: SourceMatch? = nil
            do {
                let rows = try await KnowledgeStorage.shared.fetchPageEmbeddings(pageIDs: sources.map { $0.id })
                let vectors = rows.map { $0.vector }
                let validity = await AnswerValidityScorer.score(
                    answer: finalText,
                    sources: sources,
                    sourceEmbeddings: vectors
                )
                scoredMatch = AnswerValidityScorer.match(answer: finalText, validity: validity)
            } catch {
                KnowledgeLogger.rag.error("validity scoring failed: \(String(describing: error), privacy: .public)")
            }

            if let scoredMatch, let idx = streamingIndex() {
                messages[idx].sourceMatch = scoredMatch
            }
        }
    }

    func stopGeneration() {
        activeTask?.cancel()
        activeTask = nil

        if let idx = messages.lastIndex(where: { $0.isStreaming }) {
            messages[idx].isStreaming = false
            if messages[idx].text.isEmpty {
                messages.remove(at: idx)
            }
        }

        finishThinking()
    }

    private static let listAllStopwords: Set<String> = [
        "what", "which", "who", "when", "where", "why", "how",
        "did", "do", "does", "have", "had", "has",
        "read", "reading", "reads", "see", "saw", "seen", "look", "looked",
        "tell", "show", "list", "give", "about", "stuff", "things", "thing",
        "anything", "everything", "saved", "article", "articles", "page", "pages",
        "the", "an", "of", "to", "in", "on", "for", "and", "or",
        "is", "are", "was", "were", "me", "my", "you", "your", "it", "that", "this",
    ]

    private static let knowledgeQueryPatterns: [NSRegularExpression] = {
        let raw = [
            #"\bwhat (did|have|had) i\b"#,
            #"\b(did|have|had) i (read|reas|see|saw|seen|look|study|learn|view|browse|check|visit)\b"#,
            #"\bwhat do i know about\b"#,
            #"\b(tell|show|remind) me (about|what|which|more about|everything about)\b"#,
            #"\bsummari[sz]e\b"#,
            #"\bmy (saved|reading|library|notes|pages|history|articles|bookmarks)\b"#,
        ]
        return raw.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private static let readingLeadIns: [String] = [
        "what did i read about ", "what did i read on ", "what did i read regarding ",
        "what have i read about ", "what have i read on ", "tell me what i read about ",
        "what did i see about ", "what did i learn about ", "what did i study about ",
        "what do i know about ", "remind me what i read about ", "remind me about ",
        "tell me about ", "what did i read ", "what have i read ", "what did i see ",
    ].sorted { $0.count > $1.count }

    private static func topicQuestion(from query: String) -> String {
        let lower = query.lowercased()
        for lead in readingLeadIns where lower.hasPrefix(lead) {
            let topic = String(query.dropFirst(lead.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: " ?.!,"))
            guard !topic.isEmpty else { break }
            return "Tell me about \(topic)."
        }
        return query
    }

    private static func looksLikeKnowledgeQuery(_ query: String) -> Bool {
        let ns = query as NSString
        let range = NSRange(location: 0, length: ns.length)
        return knowledgeQueryPatterns.contains { $0.firstMatch(in: query, range: range) != nil }
    }

    private static func distinctiveTerms(_ query: String) -> [String] {
        query
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 && !listAllStopwords.contains($0) }
    }

    static func relevanceGated(
        _ ranked: [(page: PageContent, score: Double)],
        query: String,
        floor: Double
    ) -> [PageContent] {
        guard let topScore = ranked.first?.score else { return [] }
        let relativeMargin = 0.13
        let rescueFloor = 0.25
        let byMargin = ranked.filter { $0.score >= floor && $0.score >= topScore - relativeMargin }

        if byMargin.isEmpty {
            guard topScore >= rescueFloor else { return [] }
            return ranked.prefix(2).map { $0.page }
        }

        let terms = distinctiveTerms(query)
        let lexical = byMargin.filter { lexicalPass($0.page, terms: terms) }

        let minimumKeep = min(2, byMargin.count)
        let kept = lexical.count >= minimumKeep ? lexical : Array(byMargin.prefix(minimumKeep))
        return kept.map { $0.page }
    }

    private static func lexicalPass(_ page: PageContent, terms: [String]) -> Bool {
        guard !terms.isEmpty else { return true }
        let haystack =
            ((page.title ?? "") + " " + (page.summary ?? "") + " "
            + page.content.prefix(50_000)).lowercased()
        let words = Set(haystack.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        let hits = terms.filter { words.contains($0) }.count
        if terms.count >= 3 { return hits * 2 >= terms.count }
        return hits >= 1
    }

    private func isListAllQuery(_ residual: String) -> Bool {
        let tokens =
            residual
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 && !Self.listAllStopwords.contains($0) }
        return tokens.isEmpty
    }

    private func ftsQuery(from raw: String) -> String {
        let stopwords: Set<String> = [
            "the", "a", "an", "is", "are", "was", "were", "be", "been",
            "of", "to", "in", "on", "for", "and", "or", "but", "if",
            "what", "which", "who", "whom", "whose", "when", "where", "why", "how",
            "do", "does", "did", "can", "could", "would", "should", "may", "might",
            "this", "that", "these", "those", "i", "you", "he", "she", "it", "we", "they",
            "my", "your", "his", "her", "its", "our", "their", "about", "with", "from",
        ]
        let tokens =
            raw
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 1 && !stopwords.contains($0) }
            .prefix(6)
            .map { "\"\($0)\"*" }
        guard !tokens.isEmpty else { return "\"\(raw.replacingOccurrences(of: "\"", with: ""))\"" }
        return tokens.joined(separator: " OR ")
    }

    private func respondConversationally(
        query: String,
        history: [(role: String, text: String)]
    ) async {
        let libraryContext = await buildLibraryContext()

        let streamMessage = ChatMessage(role: .assistant, text: "", isStreaming: true)
        let streamMessageID = streamMessage.id
        messages.append(streamMessage)
        let summary = conversationSummary

        activeTask = Task {
            var raw = ""
            var streamError: Error? = nil
            let flushInterval: TimeInterval = 0.08
            var lastFlush = Date(timeIntervalSince1970: 0)

            @MainActor func streamingIndex() -> Int? {
                messages.firstIndex(where: { $0.id == streamMessageID })
            }

            @MainActor func flushIfDue(force: Bool = false) {
                let now = Date()
                guard force || now.timeIntervalSince(lastFlush) >= flushInterval else { return }
                lastFlush = now
                if let idx = streamingIndex(), messages[idx].text != raw {
                    messages[idx].text = raw
                }
            }

            do {
                let stream = await LocalKnowledgeProvider.shared.chatStream(
                    query: query,
                    history: history,
                    conversationSummary: summary,
                    libraryContext: libraryContext
                )
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    raw += chunk
                    flushIfDue()
                }
                flushIfDue(force: true)
            } catch {
                if Task.isCancelled { return }
                streamError = error
            }

            if let idx = streamingIndex() {
                if raw.isEmpty {
                    messages[idx].text =
                        streamError != nil
                        ? "Couldn't generate a reply."
                        : "…"
                } else {
                    messages[idx].text = raw
                }
                messages[idx].isStreaming = false
            }

            finishThinking()
        }
    }

    private func buildLibraryContext() async -> String? {
        let total = (try? await KnowledgeStorage.shared.pageCount()) ?? 0

        if total == 0 {
            return "The user's library is completely empty — no saved pages yet."
        }

        let topics = ((try? await KnowledgeStorage.shared.fetchAllTopics()) ?? [])
            .filter { !$0.isUncategorized }
            .map { $0.name }

        let pageWord = total == 1 ? "page" : "pages"

        if topics.isEmpty {
            return "The user has \(total) saved \(pageWord) but no categorized topics yet."
        }

        let list = topics.prefix(5).joined(separator: ", ")
        return "The user has \(total) saved \(pageWord) across topics: \(list)."
    }

    private func emptyResultMessage(scopePhrase: String?) async -> String {
        let total = (try? await KnowledgeStorage.shared.pageCount()) ?? 0

        if total == 0 {
            return
                "Your library is empty right now — there's nothing for me to dig through yet. Open an article in the browser and I will start remembering what you read, then ask me anything about it."
        }

        let topics = ((try? await KnowledgeStorage.shared.fetchAllTopics()) ?? [])
            .filter { !$0.isUncategorized }
            .map { $0.name }

        let pageWord = total == 1 ? "page" : "pages"

        if let scopePhrase {
            if topics.isEmpty {
                return
                    "Nothing saved from \(scopePhrase). You've got \(total) \(pageWord) saved overall — try a different time window, or ask what's in your library."
            }
            let list = topics.prefix(3).joined(separator: ", ")
            return
                "Nothing saved from \(scopePhrase). The topics in your library right now are \(list) — want to look at one of those instead?"
        }

        if topics.isEmpty {
            return
                "Nothing in your saved pages matched that. You've got \(total) \(pageWord) saved — try asking about a title or topic from your library."
        }

        let list = topics.prefix(3).joined(separator: ", ")
        return
            "Nothing in your saved pages matched that. You could try asking about \(list) — those are what you've been reading."
    }

    private func finishThinking() {
        sparklePhase = .idle
        isThinking = false
        activeTask = nil
        setStatus(nil)
    }

    private func maybeCompactHistory(priorMessages: [ChatMessage]) async {
        guard priorMessages.count >= autoCompactThreshold else { return }
        let keepFrom = max(0, priorMessages.count - keepRecentTurns)
        guard keepFrom > compactedThroughIndex else { return }

        let slice = Array(priorMessages[compactedThroughIndex..<keepFrom])
        let turns: [(role: String, text: String)] = slice.map {
            ($0.role == .user ? "user" : "assistant", $0.text)
        }
        guard !turns.isEmpty else { return }

        setStatus(Self.compactingMessages.randomElement()!)
        do {
            let newSummary = try await LocalKnowledgeProvider.shared.summarizeConversationWithLLM(
                turns: turns,
                priorSummary: conversationSummary
            )
            if !newSummary.isEmpty {
                conversationSummary = newSummary
                compactedThroughIndex = keepFrom
            }
        } catch {
            KnowledgeLogger.rag.error("conversation compaction failed: \(String(describing: error), privacy: .public)")
        }

        setStatus(Self.searchingMessages.randomElement()!)
    }

    func clearMessages() {
        stopGeneration()

        messages = []
        inputText = ""
        conversationSummary = nil
        compactedThroughIndex = 0
    }
}

@MainActor
enum QueryCorrector {
    private static let textChecker = UITextChecker()

    private static let stopwords: Set<String> = [
        "what", "which", "who", "when", "where", "why", "how", "whose", "whom",
        "did", "does", "have", "had", "has", "was", "were", "are", "the", "and",
        "about", "from", "with", "that", "this", "these", "those", "your", "read",
        "tell", "show", "give", "list", "into", "over", "want", "know", "there",
        "their", "they", "them", "then", "than", "some", "more", "most", "much",
    ]

    static func correct(_ query: String) async -> QueryCorrection {
        let words = query.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard !words.isEmpty else { return QueryCorrection(corrected: query, changed: false) }

        var changed = false
        var out: [String] = []
        for word in words {
            if let fix = await correctWord(word) {
                out.append(fix)
                changed = true
            } else {
                out.append(word)
            }
        }

        return QueryCorrection(corrected: out.joined(separator: " "), changed: changed)
    }

    private static func correctWord(_ word: String) async -> String? {
        let core = word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard core.count >= 4 else { return nil }
        let lower = core.lowercased()
        guard !lower.contains(where: { $0.isNumber }) else { return nil }
        guard !stopwords.contains(lower) else { return nil }
        if await KnowledgeStorage.shared.corpusContains(lower) { return nil }
        guard isMisspelled(lower) else { return nil }

        let ns = lower as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let guesses = textChecker.guesses(forWordRange: range, in: lower, language: "en") else { return nil }

        for guess in guesses.prefix(10) {
            let candidate = guess.lowercased()
            guard candidate != lower, candidate.count >= 3, candidate.allSatisfy({ $0.isLetter }) else { continue }
            guard await KnowledgeStorage.shared.corpusContains(candidate) else { continue }

            var replacement = candidate
            if let first = core.first, first.isUppercase {
                replacement = replacement.prefix(1).uppercased() + replacement.dropFirst()
            }
            if let coreRange = word.range(of: core) {
                return word.replacingCharacters(in: coreRange, with: replacement)
            }
            return replacement
        }
        return nil
    }

    private static func isMisspelled(_ word: String) -> Bool {
        let range = NSRange(location: 0, length: (word as NSString).length)
        let result = textChecker.rangeOfMisspelledWord(
            in: word, range: range, startingAt: 0, wrap: false, language: "en")
        return result.location != NSNotFound
    }
}
