import Foundation
import NaturalLanguage
import os

nonisolated final class EmbeddingService: @unchecked Sendable {
    nonisolated static let shared = EmbeddingService()

    nonisolated static let embeddingVersion: Int32 = 2

    private let contextualEmbedding: NLContextualEmbedding?
    private let fallbackEmbedding: NLEmbedding?
    private var didLoadContextual = false
    private let loadLock = NSLock()
    private let inferenceLock = NSLock()

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
            var results: [[Double]?] = Array(repeating: nil, count: texts.count)

            for (index, text) in texts.enumerated() {
                if Task.isCancelled { break }
                guard !text.isEmpty else { continue }
                if Self.isMemoryCritical() { break }
                results[index] = self.embedSync(text)
            }

            return results
        }.value
    }

    private static let memoryFloor: Int = 48 * 1024 * 1024
    private static func isMemoryCritical() -> Bool {
        #if os(iOS)
        return os_proc_available_memory() < memoryFloor
        #else
        return false
        #endif
    }




    private func embedSync(_ text: String) -> [Double]? {
        guard let clean = Self.sanitize(text) else { return nil }

        if let ctx = ensureLoaded(),
           Self.looksEnglish(clean),
           let vector = contextualVector(ctx, text: clean) {
            return vector
        }

        return fallbackEmbedding?.vector(for: clean)
    }

    private static func sanitize(_ text: String) -> String? {
        let filtered = text.unicodeScalars.lazy.filter { s in
            if s.value < 0x20 && s != "\n" && s != "\t" { return false }
            if s.value == 0x7F { return false }
            if s.value == 0xFFFC || s.value == 0xFEFF { return false }
            if (0xFFF0...0xFFFF).contains(s.value) { return false }
            if (0xD800...0xDFFF).contains(s.value) { return false }
            return true
        }

        var sanitizedText = String(String.UnicodeScalarView(filtered))
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let maxUTF16: Int = 1500
        if sanitizedText.utf16.count > maxUTF16 {
            let end = sanitizedText.utf16.index(sanitizedText.utf16.startIndex, offsetBy: maxUTF16)
            if let clamped = String(sanitizedText.utf16[..<end]) { sanitizedText = clamped }
        }

        return sanitizedText.isEmpty ? nil : sanitizedText
    }

    private static func looksEnglish(_ text: String) -> Bool {
        guard text.utf16.count >= 16 else { return true }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let lang = recognizer.dominantLanguage else { return false }

        return lang == .english
    }

    private func contextualVector(_ ctx: NLContextualEmbedding, text: String) -> [Double]? {
        inferenceLock.lock()
        defer { inferenceLock.unlock() }
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
