import Foundation
import MLX
import MLXLLM
import MLXLMCommon
internal import Tokenizers

enum KnowledgeIntent {
    case action
    case context
    case knowledge
}

actor LocalKnowledgeProvider {
    static let shared = LocalKnowledgeProvider()

    private var modelContainer: ModelContainer?
    private var loadingTask: Task<ModelContainer, Error>?

    func loadModel() async throws {
        if modelContainer != nil { return }

        #if targetEnvironment(simulator)
        return
        #else
        if let existingTask = loadingTask {
            self.modelContainer = try await existingTask.value
            return
        }

        let task = Task<ModelContainer, Error> {
            let config = ModelConfiguration(
                id: "mlx-community/Llama-3.2-1B-Instruct-4bit"
            )
            return try await LLMModelFactory.shared.loadContainer(configuration: config)
        }

        self.loadingTask = task
        self.modelContainer = try await task.value
        self.loadingTask = nil
        #endif
    }

    func unloadModel() {
        modelContainer = nil
        loadingTask = nil
    }

    func summarizeWithLLM(content: String, title: String?) async throws -> String {
        if modelContainer == nil {
            try await loadModel()
        }

        guard let container = modelContainer else {
            throw NSError(
                domain: "LocalKnowledgeProvider", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        let prompt = """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>
            Summarize articles in one sentence.<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            Understanding closures: Closures capture variables from their enclosing scope and can be passed as arguments.<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>
            Closures capture surrounding variables and can be passed around as self-contained blocks of functionality.<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            \(title ?? ""): \(content.prefix(500))<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>

            """

        let parameters = GenerateParameters(maxTokens: 50, temperature: 0.1)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if case .chunk(let text) = event { output += text }
        }

        return cleanSummary(output)
    }

    func summarizeWebsiteWithLLM(content: String, title: String?) async throws -> String {
        if modelContainer == nil {
            try await loadModel()
        }

        guard let container = modelContainer else {
            throw NSError(
                domain: "LocalKnowledgeProvider", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        let prompt = """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>
            Describe a website's purpose in under 8 words.<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            developer.apple.com: Documentation for iOS, macOS, watchOS APIs and frameworks.<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>
            Apple developer documentation and API reference.<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            \(title ?? ""): \(content.prefix(800))<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>

            """

        let parameters = GenerateParameters(maxTokens: 25, temperature: 0.1)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if case .chunk(let text) = event { output += text }
        }

        return cleanSummary(output)
    }

    func synthesizeWebsiteReadingWithLLM(summaries: [String]) async throws -> String {
        guard !summaries.isEmpty else { return "" }

        if modelContainer == nil {
            try await loadModel()
        }

        guard let container = modelContainer else {
            throw NSError(
                domain: "LocalKnowledgeProvider", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        let joined = summaries.prefix(8)
            .joined(separator: ". ")

        let prompt = """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>
            Describe what these pages have in common in one sentence.<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            \(joined)<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>

            """

        let parameters = GenerateParameters(maxTokens: 60, temperature: 0.15)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if case .chunk(let text) = event { output += text }
        }

        return cleanSummary(output)
    }

    func classifyTopicWithLLM(content: String, title: String?) async throws -> String {
        if modelContainer == nil {
            try await loadModel()
        }

        guard let container = modelContainer else {
            throw NSError(
                domain: "LocalKnowledgeProvider", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        let prompt = """
            You are a topic classifier. Categorize the following article into a single, concise topic name (e.g., 'Finance', 'Technology', 'Sports', 'AI').
            If the article doesn't clearly fit a common category, provide a custom one that is 1-2 words max.

            Title: \(title ?? "N/A")
            Content: \(content.prefix(2000))

            Respond with ONLY the topic name.
            """

        let parameters = GenerateParameters(maxTokens: 20, temperature: 0.1)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if case .chunk(let text) = event { output += text }
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func refineQueryAndFindKeywordWithLLM(query: String) async throws -> String {
        if modelContainer == nil {
            try await loadModel()
        }

        guard let container = modelContainer else {
            throw NSError(
                domain: "LocalKnowledgeProvider", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        let prompt = """
            Your task is to refine the given query to be more suitable for database search.
            Once the query is refined, please find the most relevant keyword from the refined query.
            Respond with ONLY the keyword.

            Query: \(query)
            """

        let parameters = GenerateParameters(maxTokens: 20, temperature: 0.1)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if case .chunk(let text) = event { output += text }
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func answerFromKnowledge(query: String, sources: [PageContent]) async throws -> String {
        guard !sources.isEmpty else { return "" }

        #if targetEnvironment(simulator)
        return simulatorAnswer(query: query, sources: sources)
        #else

        if modelContainer == nil {
            try await loadModel()
        }

        guard let container = modelContainer else {
            throw NSError(
                domain: "LocalKnowledgeProvider", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        let context = sources.prefix(3)
            .map { p in
                let body: String
                if let s = p.summary, !s.isEmpty {
                    body = s
                } else {
                    body = String(p.content.prefix(120))
                }
                return "\(p.title ?? p.domain): \(body)"
            }
            .joined(separator: "\n")

        let prompt = """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>
            Reading assistant. Answer from sources. Bold **key terms**. Use bullet points for lists.<|eot_id|>\
            <|start_header_id|>user<|end_header_id|>
            \(context)

            \(query)<|eot_id|>\
            <|start_header_id|>assistant<|end_header_id|>

            """

        let parameters = GenerateParameters(maxTokens: 750, temperature: 0.1)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if case .chunk(let text) = event { output += text }
        }

        return cleanOutput(output)
        #endif
    }

    private func simulatorAnswer(query: String, sources: [PageContent]) -> String {
        let top = sources.first
        let title = top?.title ?? top?.domain ?? "your saved pages"
        return "Based on **\(title)** [1], this covers topics related to your query."
    }

    private func cleanOutput(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let metaPatterns = [
            "(?i)^here('s| is| are)\\b[^:]*:",
            "(?i)^(in |based on |according to |sure|okay|of course)[^:]*:",
            "(?i)^.{0,20}(concise|natural|brief|short|sentence)[^:]*:",
            "(?i)^.{0,20}(response|answer|summary)[^:]*:",
        ]
        for pattern in metaPatterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                text = String(text[range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        let metaSentences = [
            "(?i)^(sure|okay|of course|certainly)[.,!]?\\s*",
            "(?i)^(let me|i'?ll|i can|i would)\\b[^.]*\\.\\s*",
        ]
        for pattern in metaSentences {
            if let range = text.range(of: pattern, options: .regularExpression) {
                text = String(text[range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        text = text.replacingOccurrences(
            of: "\\[\\d+\\]",
            with: "",
            options: .regularExpression
        )

        text = text.replacingOccurrences(
            of: "(?<![*])\\*(?![*])",
            with: "",
            options: .regularExpression
        )

        let starPairCount = text.components(separatedBy: "**").count - 1
        if starPairCount % 2 != 0 {
            text = text.replacingOccurrences(of: "**", with: "")
        }

        if let lastDot = text.lastIndex(where: { ".!?".contains($0) }) {
            let after = text[text.index(after: lastDot)...]
            if after.count > 3 {
                text = String(text[...lastDot])
            }
        }

        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }

        for p in [",", ".", "!", "?", ";", ":"] {
            text = text.replacingOccurrences(of: " \(p)", with: p)
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanSummary(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let metaPrefixes = [
            "(?i)^here('s| is| are)\\b[^:]*:",
            "(?i)^(sure|okay|of course|this)[^:]*:",
            "(?i)^.{0,15}(summary|description|purpose|overview)[^:]*:",
            "(?i)^(the (article|page|website|site|content) (is about|covers|discusses|describes|explains))\\s*",
        ]
        for pattern in metaPrefixes {
            if let range = text.range(of: pattern, options: .regularExpression) {
                text = String(text[range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let first = text.first, first.isLowercase {
            text = first.uppercased() + text.dropFirst()
        }

        text = text.replacingOccurrences(of: "(?<![*])\\*(?![*])", with: "", options: .regularExpression)
        let starCount = text.components(separatedBy: "**").count - 1
        if starCount % 2 != 0 {
            text = text.replacingOccurrences(of: "**", with: "")
        }

        if let lastDot = text.lastIndex(where: { ".!?".contains($0) }) {
            let after = text[text.index(after: lastDot)...]
            if after.count > 3 {
                text = String(text[...lastDot])
            }
        }

        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }

        for p in [",", ".", "!", "?", ";", ":"] {
            text = text.replacingOccurrences(of: " \(p)", with: p)
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
