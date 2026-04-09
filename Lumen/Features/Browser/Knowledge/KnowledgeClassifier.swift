actor KnowledgeClassifier {
    static func summarize(content: String? = nil, title: String? = nil) async -> String {
        guard let content = content, !content.isEmpty else { return "" }
        do {
            return try await LocalKnowledgeProvider.shared.summarizeWithLLM(content: content, title: title)
        } catch {
            return ""
        }
    }

    static func classify(content: String? = nil, title: String? = nil) async -> String {
        guard let content = content, !content.isEmpty else { return "" }
        do {
            return try await LocalKnowledgeProvider.shared.classifyTopicWithLLM(content: content, title: title)
        } catch {
            return ""
        }
    }

    static func summarizeWebsite(content: String? = nil, title: String? = nil) async -> String {
        guard let content = content, !content.isEmpty else { return "" }
        do {
            return try await LocalKnowledgeProvider.shared.summarizeWebsiteWithLLM(content: content, title: title)
        } catch {
            return ""
        }
    }
}
