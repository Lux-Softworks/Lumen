import Foundation
import Observation

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

    func preloadModel() async {
        guard !isModelLoading else { return }
        isModelLoading = true
        sparklePhase = .spinning
        try? await LocalKnowledgeProvider.shared.loadModel()
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
            messages.append(ChatMessage(role: .assistant, text: "Knowledge search failed.", sources: []))
            return
        }

        var searchResults = scored.map { $0.page }
        let topScore = scored.first?.score ?? 0

        if searchResults.count < 3 {
            if let keywordHits = try? await KnowledgeStorage.shared.searchPages(query: ftsQuery(from: trimmed), limit: 4) {
                let existing = Set(searchResults.map { $0.id })
                for page in keywordHits where !existing.contains(page.id) {
                    searchResults.append(page)
                    if searchResults.count >= 4 { break }
                }
            }
        }

        let match = SourceMatch.classify(topScore: topScore)

        let priorSources = priorMessages.last { $0.role == .assistant }?.sources ?? []
        let existingIDs = Set(searchResults.map { $0.id })
        var merged = searchResults
        for src in priorSources where !existingIDs.contains(src.id) {
            merged.append(src)
        }
        let sources = Array(merged.prefix(4))

        guard !sources.isEmpty else {
            finishThinking()
            messages.append(ChatMessage(role: .assistant, text: "I don't have anything on that from your saved pages.", sources: [], sourceMatch: nil))
            return
        }

        let history: [(role: String, text: String)] = priorMessages.suffix(6).map { msg in
            (msg.role == .user ? "user" : "assistant", msg.text)
        }

        var highlights: [String] = []
        for page in sources {
            if let anns = try? await KnowledgeStorage.shared.fetchAnnotations(pageID: page.id) {
                highlights.append(contentsOf: anns.map { $0.text })
            }
        }

        do {
            let answer = try await LocalKnowledgeProvider.shared.answerFromKnowledge(
                query: trimmed, sources: sources, highlights: highlights, history: history)
            finishThinking()
            messages.append(ChatMessage(role: .assistant, text: answer, sources: sources, sourceMatch: match))
        } catch {
            finishThinking()
            messages.append(ChatMessage(role: .assistant, text: "Couldn't generate an answer.", sources: []))
        }
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
    }

    func clearMessages() {
        messages = []
        inputText = ""
    }
}
