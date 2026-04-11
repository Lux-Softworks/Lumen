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
                id: "mlx-community/Llama-3.2-3B-Instruct-4bit"
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
            Summarize the following content with the title in 2-3 concise sentences (exclude one or the other if nil):

            Content: \(content.prefix(2000))
            Title: \(title ?? "N/A")
            """

        let parameters = GenerateParameters(maxTokens: 150, temperature: 0.1)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if case .chunk(let text) = event { output += text }
        }

        unloadModel()
        return output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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
            Based on this content, what is the overall purpose or category of this website/domain?
            Respond with a very short description (max 12 words).

            Content: \(content.prefix(1500))
            Title: \(title ?? "N/A")
            """

        let parameters = GenerateParameters(maxTokens: 40, temperature: 0.1)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if case .chunk(let text) = event { output += text }
        }

        unloadModel()
        return output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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

        unloadModel()
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

        unloadModel()
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
