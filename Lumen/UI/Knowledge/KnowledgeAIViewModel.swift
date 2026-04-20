import Foundation
import Observation
import os

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
        setStatus("Searching your library…")

        await maybeCompactHistory(priorMessages: priorMessages)

        let scored: [(page: PageContent, score: Double)]
        do {
            scored = try await KnowledgeStorage.shared.searchSemanticScored(query: trimmed, limit: 6)
        } catch {
            finishThinking()
            messages.append(ChatMessage(role: .assistant, text: "Knowledge search failed."))
            return
        }

        let strongMinScore = 0.40
        let weakMinScore = 0.30
        let topScore = scored.first?.score ?? 0

        var searchResults = scored.filter { $0.score >= strongMinScore }.map { $0.page }
        var ftsHitCount = 0

        if searchResults.isEmpty {
            do {
                let keywordHits = try await KnowledgeStorage.shared.searchPages(query: ftsQuery(from: trimmed), limit: 4)
                ftsHitCount = keywordHits.count

                if !keywordHits.isEmpty {
                    let existing = Set(searchResults.map { $0.id })
                    for page in keywordHits where !existing.contains(page.id) {
                        searchResults.append(page)
                        if searchResults.count >= 3 { break }
                    }

                    if searchResults.isEmpty {
                        for page in scored.filter({ $0.score >= weakMinScore }).map({ $0.page }) {
                            searchResults.append(page)
                            if searchResults.count >= 2 { break }
                        }
                    }
                }
            } catch {
                KnowledgeLogger.query.error("FTS fallback failed: \(String(describing: error), privacy: .public)")
            }
        }

        let match = SourceMatch.classify(
            topScore: topScore,
            resultCount: searchResults.count,
            ftsHits: ftsHitCount
        )

        let priorSources = priorMessages.last { $0.role == .assistant }?.sources ?? []
        var seenIDs = Set<String>()
        var merged: [PageContent] = []

        for page in searchResults where seenIDs.insert(page.id).inserted {
            merged.append(page)
        }
        for src in priorSources where seenIDs.insert(src.id).inserted {
            merged.append(src)
        }

        let sources = Array(merged.prefix(4))

        guard !sources.isEmpty else {
            finishThinking()
            messages.append(ChatMessage(role: .assistant, text: "I don't have that in your saved pages."))
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
                KnowledgeLogger.query.error("annotation fetch failed pageID=\(page.id, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }

        _ = match
        messages.append(ChatMessage(role: .assistant, text: "", sources: sources, sourceMatch: nil, isStreaming: true))
        let streamIndex = messages.count - 1
        setStatus("Thinking…")
        let summary = conversationSummary

        activeTask = Task {
            var raw = ""
            var streamError: Error? = nil
            let flushInterval: TimeInterval = 0.08
            var lastFlush = Date(timeIntervalSince1970: 0)

            @MainActor func flushIfDue(force: Bool = false) {
                let now = Date()
                guard force || now.timeIntervalSince(lastFlush) >= flushInterval else { return }
                lastFlush = now
                if streamIndex < messages.count, messages[streamIndex].text != raw {
                    messages[streamIndex].text = raw
                }
            }

            do {
                let stream = await LocalKnowledgeProvider.shared.answerStreamFromKnowledge(
                    query: trimmed, sources: sources, highlights: highlights, history: history, conversationSummary: summary)
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
                        query: trimmed, sources: sources, highlights: highlights, history: history, conversationSummary: summary)
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
                if streamIndex < messages.count {
                    messages[streamIndex].text = "Couldn't generate an answer."
                    messages[streamIndex].isStreaming = false
                    messages[streamIndex].sourceMatch = nil
                }
                finishThinking()
                return
            }

            var finalText = raw
            modelProducedOutput = !finalText.isEmpty

            if !modelProducedOutput {
                finalText = "No response generated for that query. Please try again."
            }

            var scoredMatch: SourceMatch? = nil
            if modelProducedOutput {
                do {
                    let rows = try await KnowledgeStorage.shared.fetchPageEmbeddings(pageIDs: sources.map { $0.id })
                    let vectors = rows.map { $0.vector }
                    let validity = await AnswerValidityScorer.score(
                        answer: finalText,
                        sources: sources,
                        sourceEmbeddings: vectors
                    )
                    scoredMatch = AnswerValidityScorer.match(for: validity)
                } catch {
                    KnowledgeLogger.rag.error("validity scoring failed: \(String(describing: error), privacy: .public)")
                }
            }

            if streamIndex < messages.count {
                if messages[streamIndex].text != finalText {
                    messages[streamIndex].text = finalText
                }
                messages[streamIndex].sourceMatch = scoredMatch
                messages[streamIndex].isStreaming = false
            }

            finishThinking()
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

    private func ftsQuery(from raw: String) -> String {
        let stopwords: Set<String> = [
            "the", "a", "an", "is", "are", "was", "were", "be", "been",
            "of", "to", "in", "on", "for", "and", "or", "but", "if",
            "what", "which", "who", "whom", "whose", "when", "where", "why", "how",
            "do", "does", "did", "can", "could", "would", "should", "may", "might",
            "this", "that", "these", "those", "i", "you", "he", "she", "it", "we", "they",
            "my", "your", "his", "her", "its", "our", "their", "about", "with", "from",
        ]
        let tokens = raw
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 1 && !stopwords.contains($0) }
            .prefix(6)
            .map { "\"\($0)\"*" }
        guard !tokens.isEmpty else { return "\"\(raw.replacingOccurrences(of: "\"", with: ""))\"" }
        return tokens.joined(separator: " OR ")
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

        setStatus("Compacting history...")
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
        setStatus("Searching your library…")
    }

    func clearMessages() {
        stopGeneration()
        messages = []
        inputText = ""
        conversationSummary = nil
        compactedThroughIndex = 0
    }
}
