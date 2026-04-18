import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import UIKit
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
    private var idleTask: Task<Void, Never>?
    private var lastUsed: Date?
    private var isWarmed: Bool = false
    private static let idleUnloadSeconds: UInt64 = 180

    private init() {
        Task { [weak self] in
            await self?.registerMemoryObservers()
        }
    }

    private func registerMemoryObservers() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in await self?.unloadModel() }
        }
        center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in await self?.unloadModel() }
        }
    }

    private func touch() {
        lastUsed = Date()
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.idleUnloadSeconds * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.unloadIfIdle()
        }
    }

    private func unloadIfIdle() {
        guard let last = lastUsed else { return }
        if Date().timeIntervalSince(last) >= Double(Self.idleUnloadSeconds) {
            unloadModel()
        }
    }

    private func clearGPUCache() {
        #if !targetEnvironment(simulator)
        Memory.clearCache()
        #endif
    }

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
        try? await warmupIfNeeded()
        #endif
    }

    private func warmupIfNeeded() async throws {
        guard !isWarmed, let container = modelContainer else { return }
        let params = GenerateParameters(maxTokens: 1, temperature: 0.0)
        let tokens = await container.encode("Hi")
        let input = LMInput(tokens: MLXArray(tokens))
        let stream = try await container.generate(input: input, parameters: params)
        for await _ in stream { break }
        clearGPUCache()
        isWarmed = true
    }

    func unloadModel() {
        modelContainer = nil
        loadingTask = nil
        idleTask?.cancel()
        idleTask = nil
        isWarmed = false
        clearGPUCache()
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

        let prompt = await KnowledgePrompts.pageSummary(content: content, title: title)

        let parameters = GenerateParameters(maxTokens: 50, temperature: 0.1)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if case .chunk(let text) = event { output += text }
        }

        clearGPUCache()
        touch()
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

        let prompt = await KnowledgePrompts.websiteSummary(content: content, title: title)

        let parameters = GenerateParameters(maxTokens: 25, temperature: 0.1)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if case .chunk(let text) = event { output += text }
        }

        clearGPUCache()
        touch()
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

        let prompt = await KnowledgePrompts.websiteReadingSynthesis(summaries: summaries)

        let parameters = GenerateParameters(maxTokens: 60, temperature: 0.15)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if case .chunk(let text) = event { output += text }
        }

        clearGPUCache()
        touch()
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

        let prompt = await KnowledgePrompts.topicClassification(content: content, title: title)

        let parameters = GenerateParameters(maxTokens: 20, temperature: 0.1)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if case .chunk(let text) = event { output += text }
        }

        clearGPUCache()
        touch()
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

        let prompt = await KnowledgePrompts.queryRefinement(query: query)

        let parameters = GenerateParameters(maxTokens: 20, temperature: 0.1)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if case .chunk(let text) = event { output += text }
        }

        clearGPUCache()
        touch()
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func answerFromKnowledge(
        query: String,
        sources: [PageContent],
        highlights: [String] = [],
        history: [(role: String, text: String)] = []
    ) async throws -> String {
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
                var parts: [String] = []
                if let s = p.summary, !s.isEmpty {
                    parts.append(s)
                }
                let bodyLimit = 350
                let body = String(p.content.prefix(bodyLimit))
                if !body.isEmpty {
                    parts.append(body)
                }
                let joined = parts.joined(separator: " — ")
                return "\(p.title ?? p.domain): \(joined)"
            }
            .joined(separator: "\n\n")

        let cleanedHighlights = highlights
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let highlightsBlock: String
        let highlightsGuideline: String
        if cleanedHighlights.isEmpty {
            highlightsBlock = ""
            highlightsGuideline = ""
        } else {
            let lines = cleanedHighlights.prefix(6)
                .map { "- \"\(String($0.prefix(240)))\"" }
                .joined(separator: "\n")
            highlightsBlock = """


                User-highlighted passages (strong signal, prioritize when relevant):
                \(lines)
                """
            highlightsGuideline = "\n- When user-highlighted passages are present, weight them heavily — user explicitly marked them as important."
        }

        let historyBlock = history.suffix(3)
            .map { turn -> String in
                let header = turn.role == "user" ? "user" : "assistant"
                let body = String(turn.text.prefix(200))
                return "<|start_header_id|>\(header)<|end_header_id|>\n\(body)<|eot_id|>"
            }
            .joined()

        let prompt = await KnowledgePrompts.ragAnswer(
            query: query,
            context: context,
            highlightsBlock: highlightsBlock,
            highlightsGuideline: highlightsGuideline,
            historyBlock: historyBlock
        )

        let parameters = GenerateParameters(maxTokens: 180, temperature: 0.1)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if case .chunk(let text) = event { output += text }
        }

        clearGPUCache()
        touch()
        return cleanOutput(output)
        #endif
    }

    func answerStreamFromKnowledge(
        query: String,
        sources: [PageContent],
        highlights: [String] = [],
        history: [(role: String, text: String)] = []
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !sources.isEmpty else {
                        continuation.finish()
                        return
                    }

                    #if targetEnvironment(simulator)
                    continuation.yield(simulatorAnswer(query: query, sources: sources))
                    continuation.finish()
                    return
                    #else

                    if self.modelContainer == nil {
                        try await self.loadModel()
                    }

                    guard let container = self.modelContainer else {
                        throw NSError(
                            domain: "LocalKnowledgeProvider", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
                    }

                    let context = sources.prefix(3)
                        .map { p in
                            var parts: [String] = []
                            if let s = p.summary, !s.isEmpty { parts.append(s) }
                            let body = String(p.content.prefix(350))
                            if !body.isEmpty { parts.append(body) }
                            return "\(p.title ?? p.domain): \(parts.joined(separator: " — "))"
                        }
                        .joined(separator: "\n\n")

                    let cleanedHighlights = highlights
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    let highlightsBlock: String
                    let highlightsGuideline: String
                    if cleanedHighlights.isEmpty {
                        highlightsBlock = ""
                        highlightsGuideline = ""
                    } else {
                        let lines = cleanedHighlights.prefix(6)
                            .map { "- \"\(String($0.prefix(240)))\"" }
                            .joined(separator: "\n")
                        highlightsBlock = """


                            User-highlighted passages (strong signal, prioritize when relevant):
                            \(lines)
                            """
                        highlightsGuideline = "\n- When user-highlighted passages are present, weight them heavily — user explicitly marked them as important."
                    }

                    let historyBlock = history.suffix(3)
                        .map { turn -> String in
                            let header = turn.role == "user" ? "user" : "assistant"
                            let body = String(turn.text.prefix(200))
                            return "<|start_header_id|>\(header)<|end_header_id|>\n\(body)<|eot_id|>"
                        }
                        .joined()

                    let prompt = await KnowledgePrompts.ragAnswer(
                        query: query, context: context,
                        highlightsBlock: highlightsBlock,
                        highlightsGuideline: highlightsGuideline,
                        historyBlock: historyBlock
                    )

                    let parameters = GenerateParameters(
                        maxTokens: 220,
                        temperature: 0.1,
                        repetitionPenalty: 1.15,
                        repetitionContextSize: 40
                    )
                    let tokens = await container.encode(prompt)
                    let input = LMInput(tokens: MLXArray(tokens))

                    let stream = try await container.generate(input: input, parameters: parameters)

                    for await event in stream {
                        if Task.isCancelled { break }
                        if case .chunk(let text) = event {
                            continuation.yield(text)
                        }
                    }

                    self.clearGPUCache()
                    self.touch()
                    continuation.finish()
                    #endif
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func simulatorAnswer(query: String, sources: [PageContent]) -> String {
        let top = sources.first
        let title = top?.title ?? top?.domain ?? "your saved pages"
        return "Based on **\(title)** [1], this covers topics related to your query."
    }

    func cleanAnswerText(_ raw: String) -> String {
        cleanOutput(raw)
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
            "(?i)^i('?ve| have)?\\s*(looked|searched|checked|reviewed|scanned|gone through|looked through)\\b[^.]*\\.\\s*",
            "(?i)^(based on|from|according to|looking at|drawing on)\\s+(your|the)\\s+(saved |reading |)?(pages?|sources?|history|notes)\\b[^.]*\\.\\s*",
            "(?i)^(in|from) your saved pages[^.]*\\.\\s*",
        ]
        for pattern in metaSentences {
            while let range = text.range(of: pattern, options: .regularExpression) {
                text = String(text[range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        text = dedupeSentences(text)

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

    private func dedupeSentences(_ raw: String) -> String {
        let sentences = raw.split(whereSeparator: { ".!?".contains($0) }).map { sub -> (String, Character) in
            let trimmed = sub.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmed, ".")
        }

        guard sentences.count > 1 else { return raw }

        var seen = Set<String>()
        var kept: [String] = []
        var cursor = raw.startIndex

        for (sentence, _) in sentences {
            guard !sentence.isEmpty else { continue }
            let key = sentence.lowercased()
                .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            if seen.contains(key) { continue }
            seen.insert(key)

            if let r = raw.range(of: sentence, range: cursor..<raw.endIndex) {
                cursor = r.upperBound
                var end = cursor

                while end < raw.endIndex, ".!?".contains(raw[end]) {
                    end = raw.index(after: end)
                }

                kept.append(String(raw[r.lowerBound..<end]))
                cursor = end
            } else {
                kept.append(sentence + ".")
            }
        }

        return kept.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
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
