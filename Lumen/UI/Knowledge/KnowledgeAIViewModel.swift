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

        let searchResults: [PageContent]
        do {
            searchResults = try await KnowledgeStorage.shared.searchSemantic(query: trimmed, limit: 3)
        } catch {
            finishThinking()
            messages.append(ChatMessage(role: .assistant, text: "Knowledge search failed.", sources: []))
            return
        }

        let priorSources = priorMessages.last { $0.role == .assistant }?.sources ?? []
        let existingIDs = Set(searchResults.map { $0.id })
        var merged = searchResults
        for src in priorSources where !existingIDs.contains(src.id) {
            merged.append(src)
        }
        let sources = Array(merged.prefix(4))

        guard !sources.isEmpty else {
            finishThinking()
            messages.append(ChatMessage(role: .assistant, text: "I don't have anything relevant on that from your reading history.", sources: []))
            return
        }

        let history: [(role: String, text: String)] = priorMessages.suffix(6).map { msg in
            (msg.role == .user ? "user" : "assistant", msg.text)
        }

        do {
            let answer = try await LocalKnowledgeProvider.shared.answerFromKnowledge(
                query: trimmed, sources: sources, history: history)
            finishThinking()
            messages.append(ChatMessage(role: .assistant, text: answer, sources: sources))
        } catch {
            finishThinking()
            messages.append(ChatMessage(role: .assistant, text: "Couldn't generate an answer.", sources: []))
        }
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
