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
    
    let predefinedTopics = ["Technology", "Science", "Politics", "Health", "Finance", "Business", "Sports", "Entertainment", "Education", "Environment", "Travel", "Food & Cooking", "Art & Design", "History", "Philosophy", "Psychology", "Engineering", "Space", "Medicine", "Other"]

    private var modelContainer: ModelContainer?
    private var loadingTask: Task<ModelContainer, Error>?

    func loadModel() async throws {
        if modelContainer != nil { return }

        #if targetEnvironment(simulator)
            return
        #endif

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
    }

    func unloadModel() {
        modelContainer = nil
        loadingTask = nil
    }

    /*
    func route(_ input: String) async -> KnowledgeIntent {
        let lower = input.lowercased()

        if lower.starts(with: "click") || lower.starts(with: "tap") || lower.starts(with: "fill")
            || lower.starts(with: "type")
        {
            return .action
        }

        if lower.contains("summarize") || lower.contains("read this")
            || lower.contains("what is on this page")
        {
            return .context
        }

        return .knowledge
    }
    */

    func summarizeWithLLM(content: String, title: String?) async throws -> String {
        if modelContainer == nil {
            try await loadModel()
        }

        guard let container = modelContainer else {
            throw NSError(domain: "LocalKnowledgeProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        let prompt = """
        Summarize the following content with the title in 2-3 concise sentences (exclude one or the other if nil):

        Content: \(content.prefix(2000))
        Title: \(title ?? "N/A")
        """

        let parameters = GenerateParameters(maxTokens: 150, temperature: 0.1)

        let output = try await container.perform { context in
            let promptTokens = context.tokenizer.encode(text: prompt)

            let result = try await MLXLMCommon.generate(
                promptTokens: promptTokens,
                parameters: parameters,
                model: context.model,
                tokenizer: context.tokenizer,
                didGenerate: { _ in .more }
            )

            await unloadModel()
            return result.output
        }

        return output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    func summarizeWebsiteWithLLM(content: String, title: String?) async throws -> String {
        if modelContainer == nil {
            try await loadModel()
        }

        guard let container = modelContainer else {
            throw NSError(domain: "LocalKnowledgeProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        let prompt = """
        Based on this content, what is the overall purpose or category of this website/domain? 
        Respond with a very short description (max 12 words).

        Content: \(content.prefix(1500))
        Title: \(title ?? "N/A")
        """

        let parameters = GenerateParameters(maxTokens: 40, temperature: 0.1)

        let output = try await container.perform { context in
            let promptTokens = context.tokenizer.encode(text: prompt)

            let result = try await MLXLMCommon.generate(
                promptTokens: promptTokens,
                parameters: parameters,
                model: context.model,
                tokenizer: context.tokenizer,
                didGenerate: { _ in .more }
            )

            await unloadModel()
            return result.output
        }

        return output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    func classifyTopicWithLLM(content: String, title: String?) async throws -> String {
        if modelContainer == nil {
            try await loadModel()
        }

        guard let container = modelContainer else {
            throw NSError(domain: "LocalKnowledgeProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        let prompt = """
        You are a topic classifier. Choose ONE topic from this list:
        \(predefinedTopics.joined(separator: ", "))

        If the article doesn't clearly fit any category, respond with "Other".

        Title: \(title ?? "N/A")
        Content: \(content.prefix(2000))

        Respond with ONLY the topic name from the list above.
        """

        let parameters = GenerateParameters(maxTokens: 20, temperature: 0.1)

        let output = try await container.perform { context in
            let promptTokens = context.tokenizer.encode(text: prompt)
            let result = try await MLXLMCommon.generate(
                promptTokens: promptTokens,
                parameters: parameters,
                model: context.model,
                tokenizer: context.tokenizer,
                didGenerate: { _ in .more }
            )

            await unloadModel()
            return result.output
        }

        let cleanedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)

        if predefinedTopics.contains(cleanedOutput) {
            return cleanedOutput
        } else {
            return "Other"
        }
    }
}
