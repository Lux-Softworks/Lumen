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

    private var activeTask: Task<Void, Never>?

    func preloadModel() async {
        guard !isModelLoading else { return }
        isModelLoading = true
        sparklePhase = .spinning
        do {
            try await LocalKnowledgeProvider.shared.loadModel()
        } catch {
            KnowledgeLogger.rag.error("model load failed: \(String(describing: error), privacy: .public)")
        }
        sparklePhase = .idle
        isModelLoading = false
    }

    func send() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isThinking, !isModelLoading else { return }
        inputText = ""
        let priorMessages = messages
        messages.append(ChatMessage(role: .user, text: trimmed))
        isThinking = true
        sparklePhase = .spinning

        let scored: [(page: PageContent, score: Double)]
        do {
            scored = try await KnowledgeStorage.shared.searchSemanticScored(query: trimmed, limit: 4)
        } catch {
            finishThinking()
            messages.append(ChatMessage(role: .assistant, text: "Knowledge search failed."))
            return
        }

        let minScore = 0.20
        var searchResults = scored.filter { $0.score >= minScore }.map { $0.page }
        let topScore = scored.first?.score ?? 0
        var ftsHitCount = 0

        if topScore < 0.30 || searchResults.count < 3 {
            do {
                let keywordHits = try await KnowledgeStorage.shared.searchPages(query: ftsQuery(from: trimmed), limit: 4)
                ftsHitCount = keywordHits.count
                let existing = Set(searchResults.map { $0.id })
                for page in keywordHits where !existing.contains(page.id) {
                    searchResults.append(page)
                    if searchResults.count >= 4 { break }
                }
            } catch {
                KnowledgeLogger.query.error("FTS fallback failed: \(String(describing: error), privacy: .public)")
            }
        }

        var match = SourceMatch.classify(topScore: topScore)
        if match == .low && ftsHitCount > 0 {
            match = .medium
        }

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

        if match == .low {
            finishThinking()
            messages.append(ChatMessage(
                role: .assistant,
                text: "I don't have that in your saved pages.",
                sources: sources,
                sourceMatch: .low
            ))
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

        messages.append(ChatMessage(role: .assistant, text: "", sources: sources, sourceMatch: match, isStreaming: true))
        let streamIndex = messages.count - 1

        activeTask = Task {
            var raw = ""
            do {
                let stream = await LocalKnowledgeProvider.shared.answerStreamFromKnowledge(
                    query: trimmed, sources: sources, highlights: highlights, history: history)
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    raw += chunk
                    if streamIndex < messages.count {
                        messages[streamIndex].text = raw
                    }
                }
            } catch {
                if Task.isCancelled { return }
                if streamIndex < messages.count {
                    messages[streamIndex].text = "Couldn't generate an answer."
                    messages[streamIndex].isStreaming = false
                }
                finishThinking()
                return
            }

            let cleaned = await LocalKnowledgeProvider.shared.cleanAnswerText(raw)
            if streamIndex < messages.count {
                messages[streamIndex].text = cleaned.isEmpty ? raw : cleaned
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
    }

    func clearMessages() {
        stopGeneration()
        messages = []
        inputText = ""
    }
}
