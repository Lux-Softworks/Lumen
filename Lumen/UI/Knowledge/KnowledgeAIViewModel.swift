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
    var scrollToBottomTrigger: Int = 0

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
        messages.append(ChatMessage(role: .user, text: trimmed))
        scrollToBottomTrigger += 1
        isThinking = true
        sparklePhase = .spinning

        let sources: [PageContent]
        do {
            sources = try await KnowledgeStorage.shared.searchSemantic(query: trimmed, limit: 3)
        } catch {
            finishThinking()
            messages.append(ChatMessage(role: .assistant, text: "Knowledge search failed.", sources: []))
            return
        }
        guard !sources.isEmpty else {
            finishThinking()
            messages.append(ChatMessage(role: .assistant, text: "I don't have anything relevant on that from your reading history.", sources: []))
            return
        }
        do {
            let answer = try await LocalKnowledgeProvider.shared.answerFromKnowledge(
                query: trimmed, sources: sources)
            let used = Array(sources.prefix(3))
            finishThinking()
            messages.append(ChatMessage(role: .assistant, text: answer, sources: used))
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
