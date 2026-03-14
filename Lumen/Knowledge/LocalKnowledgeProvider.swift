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
    private var modelContainer: ModelContainer?
    private var loadingTask: Task<ModelContainer, Error>?

    func loadModel() async throws {
        if modelContainer != nil { return }

        #if targetEnvironment(simulator)
            print("MLX model loading is disabled on Simulator to prevent crashes")
            return
        #endif

        if let existingTask = loadingTask {
            self.modelContainer = try await existingTask.value
            return
        }

        let task = Task<ModelContainer, Error> {
            let config = ModelConfiguration(
                id: "mlx-community/Qwen2.5-3B-Instruct-4bit"
            )
            return try await LLMModelFactory.shared.loadContainer(configuration: config)
        }

        self.loadingTask = task
        self.modelContainer = try await task.value
        self.loadingTask = nil

        _ = await self.debugRun(prompt: "test")
    }

    func debugRun(prompt: String = "Hello, are you operational?") async -> String {
        if modelContainer == nil {
            do {
                try await self.loadModel()
            } catch {
                return "Model load error: \(error.localizedDescription)"
            }
        }

        guard let container = modelContainer else {
            return "Model load error: Container is nil"
        }

        let parameters = GenerateParameters(maxTokens: 50, temperature: 0.15)

        do {
            let output = try await container.perform { context in
                let promptTokens = context.tokenizer.encode(text: prompt)
                let result = try await MLXLMCommon.generate(
                    promptTokens: promptTokens,
                    parameters: parameters,
                    model: context.model,
                    tokenizer: context.tokenizer,
                    didGenerate: { _ in .more }
                )
                return result.output
            }

            if output.isEmpty { return "Error: Model returned empty string" }
            return output
        } catch {
            return "Error generating: \(error)"
        }
    }

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
}
