import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import UIKit
internal import Tokenizers
import os

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

    private var shutdownRequested: Bool = false
    private var inflightCount: Int = 0
    private var streamTasks: Set<Task<Void, Never>> = []
    private static let shutdownDrainTimeoutSeconds: Double = 3.0

    private static func compile(_ patterns: [String]) -> [NSRegularExpression] {
        patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }

    private static let outputMetaPatterns: [NSRegularExpression] = compile([
        "(?i)^here('s| is| are)\\b[^:]*:",
        "(?i)^(in |based on |according to |sure|okay|of course)[^:]*:",
        "(?i)^.{0,20}(concise|natural|brief|short|sentence)[^:]*:",
        "(?i)^.{0,20}(response|answer|summary)[^:]*:",
    ])

    private static let outputMetaSentences: [NSRegularExpression] = compile([
        "(?i)^(sure|okay|of course|certainly)[.,!]?\\s*",
        "(?i)^(let me|i'?ll|i can|i would)\\b[^.]*\\.\\s*",
        "(?i)^i('?ve| have)?\\s*(looked|searched|checked|reviewed|scanned|gone through|looked through)\\b[^.]*\\.\\s*",
        "(?i)^(based on|from|according to|looking at|drawing on)\\s+(your|the)\\s+(saved |reading |)?(pages?|sources?|history|notes)\\b[^.]*\\.\\s*",
        "(?i)^(in|from) your saved pages[^.]*\\.\\s*",
    ])

    private static let summaryMetaPrefixes: [NSRegularExpression] = compile([
        "(?i)^here('s| is| are)\\b[^:]*:",
        "(?i)^(sure|okay|of course|this)[^:]*:",
        "(?i)^.{0,15}(summary|description|purpose|overview)[^:]*:",
        "(?i)^(the (article|page|website|site|content) (is about|covers|discusses|describes|explains))\\s*",
    ])

    private static let strayStarRegex = try? NSRegularExpression(pattern: "(?<![*])\\*(?![*])")

    private static func stripPrefix(_ text: String, using regex: NSRegularExpression) -> String {
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: text, range: range), match.range.location == 0 else {
            return text
        }
        let end = match.range.location + match.range.length
        return ns.substring(from: end).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replaceAll(_ text: String, using regex: NSRegularExpression?, with replacement: String) -> String {
        guard let regex else { return text }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

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
            Task { [weak self] in await self?.handleShutdown() }
        }
    }

    private func beginInference() {
        inflightCount += 1
    }

    private func endInference() {
        inflightCount = max(0, inflightCount - 1)
    }

    private func registerStreamTask(_ task: Task<Void, Never>) {
        streamTasks.insert(task)
    }

    private func unregisterStreamTask(_ task: Task<Void, Never>) {
        streamTasks.remove(task)
    }

    private func handleShutdown() async {
        shutdownRequested = true

        let deadline = Date().addingTimeInterval(Self.shutdownDrainTimeoutSeconds)
        while inflightCount > 0, Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        if inflightCount == 0 {
            unloadModel()
            streamTasks.removeAll()
        }
        shutdownRequested = false
    }

    private func touch() {
        lastUsed = Date()
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.idleUnloadSeconds * 1_000_000_000)
            } catch {
                return
            }
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

        try ensureDiskSpaceForModel()

        let task = Task<ModelContainer, Error> {
            let config = ModelConfiguration(
                id: "mlx-community/Llama-3.2-1B-Instruct-4bit",
                revision: "08231374eeacb049a0eade7922910865b8fce912"
            )
            return try await LLMModelFactory.shared.loadContainer(configuration: config)
        }

        self.loadingTask = task
        self.modelContainer = try await task.value
        self.loadingTask = nil
        try? await warmupIfNeeded()
        #endif
    }

    private static let requiredDiskBytes: Int64 = 1_200_000_000

    private func ensureDiskSpaceForModel() throws {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let values = try? supportURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = values?.volumeAvailableCapacityForImportantUsage ?? 0

        if available < Self.requiredDiskBytes {
            throw NSError(
                domain: "LocalKnowledgeProvider",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Not enough free space to download the AI model. Free up at least 1.2 GB and try again."
                ]
            )
        }
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

        beginInference()
        defer { endInference() }

        let prompt = await KnowledgePrompts.pageSummary(content: content, title: title)

        let parameters = GenerateParameters(maxTokens: 50, temperature: 0.1)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if Task.isCancelled { break }
            if case .chunk(let text) = event { output += text }
        }

        clearGPUCache()
        touch()
        return cleanSummary(output)
    }

    func summarizeConversationWithLLM(
        turns: [(role: String, text: String)],
        priorSummary: String?
    ) async throws -> String {
        if modelContainer == nil {
            try await loadModel()
        }

        guard let container = modelContainer else {
            throw NSError(
                domain: "LocalKnowledgeProvider", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        beginInference()
        defer { endInference() }

        let prompt = await KnowledgePrompts.conversationSummary(turns: turns, priorSummary: priorSummary)
        let parameters = GenerateParameters(maxTokens: 140, temperature: 0.2)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))
        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if Task.isCancelled { break }
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

        beginInference()
        defer { endInference() }

        let prompt = await KnowledgePrompts.websiteSummary(content: content, title: title)

        let parameters = GenerateParameters(maxTokens: 25, temperature: 0.1)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if Task.isCancelled { break }
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

        beginInference()
        defer { endInference() }

        let prompt = await KnowledgePrompts.websiteReadingSynthesis(summaries: summaries)

        let parameters = GenerateParameters(maxTokens: 60, temperature: 0.15)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if Task.isCancelled { break }
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

        beginInference()
        defer { endInference() }

        let prompt = await KnowledgePrompts.topicClassification(content: content, title: title)

        let parameters = GenerateParameters(maxTokens: 14, temperature: 0.0)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if Task.isCancelled { break }
            if case .chunk(let text) = event { output += text }
        }

        clearGPUCache()
        touch()
        return await Self.sanitizeTopic(output)
    }

    private static let topicStopwords: Set<String> = [
        "just", "the", "a", "an", "this", "that", "it", "here", "there",
        "sure", "okay", "ok", "yes", "no", "well", "so",
        "article", "topic", "content", "page", "website", "site",
        "news", "story", "post", "blog", "other", "unknown", "none", "n/a", "na",
        "is", "about", "regarding", "general", "misc", "miscellaneous"
    ]

    @MainActor private static func sanitizeTopic(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let firstLine = trimmed.split(whereSeparator: { $0.isNewline }).first.map(String.init) ?? trimmed
        let firstToken = firstLine
            .components(separatedBy: .whitespacesAndNewlines)
            .first ?? ""

        let allowed = CharacterSet.letters.union(CharacterSet(charactersIn: "&-/."))
        let cleaned = String(firstToken.unicodeScalars.filter { allowed.contains($0) })
        guard cleaned.count >= 2 else { return "" }

        let lower = cleaned.lowercased()
        if topicStopwords.contains(lower) { return "" }

        return TopicCanonicalizer.canonical(for: cleaned)
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

        beginInference()
        defer { endInference() }

        let prompt = await KnowledgePrompts.queryRefinement(query: query)

        let parameters = GenerateParameters(maxTokens: 20, temperature: 0.1)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if Task.isCancelled { break }
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
        history: [(role: String, text: String)] = [],
        conversationSummary: String? = nil
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

        beginInference()
        defer { endInference() }

        let blocks = await PromptBudgeter.build(
            query: query,
            sources: sources,
            highlights: highlights,
            history: history,
            conversationSummary: conversationSummary
        )

        let prompt = await KnowledgePrompts.ragAnswer(
            query: query,
            context: blocks.context,
            highlightsBlock: blocks.highlightsBlock,
            highlightsGuideline: blocks.highlightsGuideline,
            historyBlock: blocks.historyBlock
        )

        let parameters = GenerateParameters(maxTokens: 320, temperature: 0.2)
        let tokens = await container.encode(prompt)
        let input = LMInput(tokens: MLXArray(tokens))

        let stream = try await container.generate(input: input, parameters: parameters)

        var output = ""
        for await event in stream {
            if Task.isCancelled { break }
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
        history: [(role: String, text: String)] = [],
        conversationSummary: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task<Void, Never> {
                self.beginInference()
                defer { self.endInference() }

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

                    let blocks = await PromptBudgeter.build(
                        query: query,
                        sources: sources,
                        highlights: highlights,
                        history: history,
                        conversationSummary: conversationSummary
                    )

                    let prompt = await KnowledgePrompts.ragAnswer(
                        query: query,
                        context: blocks.context,
                        highlightsBlock: blocks.highlightsBlock,
                        highlightsGuideline: blocks.highlightsGuideline,
                        historyBlock: blocks.historyBlock
                    )

                    let parameters = GenerateParameters(
                        maxTokens: 8192,
                        temperature: 0.3
                    )
                    let tokens = await container.encode(prompt)
                    let input = LMInput(tokens: MLXArray(tokens))

                    let stream = try await container.generate(input: input, parameters: parameters)

                    var chunkCount = 0
                    var eventCount = 0
                    for await event in stream {
                        if Task.isCancelled { break }
                        eventCount += 1
                        if case .chunk(let text) = event {
                            chunkCount += 1
                            continuation.yield(text)
                        }
                    }
                    await KnowledgeLogger.rag.log("stream done: promptChars=\(prompt.count, privacy: .public) tokens=\(tokens.count, privacy: .public) events=\(eventCount, privacy: .public) chunks=\(chunkCount, privacy: .public)")

                    self.clearGPUCache()
                    self.touch()
                    continuation.finish()
                    #endif
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            Task { self.registerStreamTask(task) }

            continuation.onTermination = { _ in
                task.cancel()
                Task { await self.unregisterStreamTask(task) }
            }
        }
    }

    private func simulatorAnswer(query: String, sources: [PageContent]) -> String {
        let top = sources.first
        let title = top?.title ?? top?.domain ?? "your saved pages"
        return "Based on **\(title)** [1], this covers topics related to your query."
    }

    private func cleanOutput(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanSummary(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        for regex in Self.summaryMetaPrefixes {
            text = Self.stripPrefix(text, using: regex)
        }

        if let first = text.first, first.isLowercase {
            text = first.uppercased() + text.dropFirst()
        }

        text = Self.replaceAll(text, using: Self.strayStarRegex, with: "")
        let starCount = text.components(separatedBy: "**").count - 1
        if starCount % 2 != 0 {
            text = text.replacingOccurrences(of: "**", with: "")
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
