import Foundation
import NaturalLanguage

nonisolated final class EmbeddingService: @unchecked Sendable {
    nonisolated static let shared = EmbeddingService()

    nonisolated static let embeddingVersion: Int32 = 2

    private let contextualEmbedding: NLContextualEmbedding?
    private let fallbackEmbedding: NLEmbedding?
    private var didLoadContextual = false
    private let loadLock = NSLock()

    private init() {
        self.contextualEmbedding = NLContextualEmbedding(language: .english)
        self.fallbackEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
    }

    var dimension: Int {
        if let ctx = contextualEmbedding {
            return ctx.dimension
        }
        return fallbackEmbedding?.dimension ?? 0
    }

    private func ensureLoaded() -> NLContextualEmbedding? {
        loadLock.lock()
        defer { loadLock.unlock() }

        guard let ctx = contextualEmbedding else { return nil }
        if didLoadContextual { return ctx }

        if !ctx.hasAvailableAssets {
            ctx.requestAssets { _, _ in }
        }

        do {
            try ctx.load()
            didLoadContextual = true
            return ctx
        } catch {
            return nil
        }
    }

    func generateEmbedding(for text: String) async -> [Double]? {
        guard !text.isEmpty else { return nil }

        return await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return nil }
            return self.embedSync(text)
        }.value
    }

    func generateEmbeddings(for texts: [String]) async -> [[Double]?] {
        await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return Array(repeating: nil, count: texts.count) }
            return texts.map { text -> [Double]? in
                guard !text.isEmpty else { return nil }
                return self.embedSync(text)
            }
        }.value
    }

    private func embedSync(_ text: String) -> [Double]? {
        let snippet = String(text.prefix(2000))

        if let ctx = ensureLoaded(), let vector = contextualVector(ctx, text: snippet) {
            return vector
        }

        return fallbackEmbedding?.vector(for: snippet)
    }

    private func contextualVector(_ ctx: NLContextualEmbedding, text: String) -> [Double]? {
        do {
            let result = try ctx.embeddingResult(for: text, language: .english)
            let dim = ctx.dimension
            guard dim > 0, result.sequenceLength > 0 else { return nil }

            var pooled = [Double](repeating: 0, count: dim)
            var tokenCount = 0

            result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, _ in
                guard vector.count == dim else { return true }
                for i in 0..<dim {
                    pooled[i] += vector[i]
                }
                tokenCount += 1
                return true
            }

            guard tokenCount > 0 else { return nil }

            let inv = 1.0 / Double(tokenCount)
            for i in 0..<dim {
                pooled[i] *= inv
            }

            return pooled
        } catch {
            return nil
        }
    }
}
