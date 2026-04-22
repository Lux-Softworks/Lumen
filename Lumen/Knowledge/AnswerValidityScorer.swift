import Foundation

enum AnswerValidityScorer {
    private static let stopwords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "if", "is", "are", "was", "were",
        "be", "been", "being", "have", "has", "had", "do", "does", "did",
        "of", "to", "in", "on", "for", "with", "from", "by", "at", "as",
        "this", "that", "these", "those", "it", "its", "their", "there",
        "what", "which", "who", "when", "where", "why", "how",
        "i", "you", "he", "she", "we", "they", "them", "us", "our", "your",
        "not", "no", "yes", "can", "could", "would", "should", "may", "might",
        "about", "into", "than", "then", "so", "such", "also", "just", "more",
        "most", "some", "any", "all", "each", "every", "only", "other"
    ]

    static func score(answer: String, sources: [PageContent], sourceEmbeddings: [[Double]]) async -> Double {
        let cosine = await semanticSimilarity(answer: answer, sourceEmbeddings: sourceEmbeddings)
        let overlap = tokenOverlap(answer: answer, sources: sources)
        return 0.6 * cosine + 0.4 * overlap
    }

    static func match(for validity: Double) -> SourceMatch {
        if validity >= 0.45 { return .high }
        if validity >= 0.20 { return .medium }
        return .low
    }

    private static func semanticSimilarity(answer: String, sourceEmbeddings: [[Double]]) async -> Double {
        guard let answerVec = await EmbeddingService.shared.generateEmbedding(for: answer),
              !answerVec.isEmpty else { return 0 }
        let sims = sourceEmbeddings.map { VectorMath.cosineSimilarity(answerVec, $0) }
        return sims.max() ?? 0
    }

    private static func tokenOverlap(answer: String, sources: [PageContent]) -> Double {
        let answerTokens = tokenize(answer)
        guard !answerTokens.isEmpty else { return 0 }

        let joinedSources = sources.map { page -> String in
            var parts: [String] = []
            if let title = page.title, !title.isEmpty { parts.append(title) }
            if let summary = page.summary, !summary.isEmpty { parts.append(summary) }
            parts.append(String(page.content.prefix(2000)))
            return parts.joined(separator: " ")
        }.joined(separator: " ")

        let sourceSet = Set(tokenize(joinedSources))
        let hits = answerTokens.filter { sourceSet.contains($0) }.count
        return Double(hits) / Double(answerTokens.count)
    }

    private static func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 && !stopwords.contains($0) }
    }
}
