import Foundation
import NaturalLanguage

final class EmbeddingService: @unchecked Sendable {
    static let shared = EmbeddingService()

    private let embeddingModel: NLEmbedding?

    private init() {
        self.embeddingModel = NLEmbedding.sentenceEmbedding(for: .english)
    }

    func generateEmbedding(for text: String) async -> [Double]? {
        guard !text.isEmpty, let model = embeddingModel else {
            return nil
        }

        return await Task.detached(priority: .userInitiated) { [model] in
            model.vector(for: text)
        }.value
    }

    func generateEmbeddings(for texts: [String]) async -> [[Double]?] {
        guard let model = embeddingModel else {
            return Array(repeating: nil, count: texts.count)
        }

        return await withTaskGroup(of: (Int, [Double]?).self, returning: [[Double]?].self) { group in
            for (index, text) in texts.enumerated() {
                group.addTask(priority: .userInitiated) {
                    guard !text.isEmpty else { return (index, nil) }
                    return (index, model.vector(for: text))
                }
            }

            var results: [(Int, [Double]?)] = []
            for await result in group {
                results.append(result)
            }

            results.sort { $0.0 < $1.0 }
            return results.map { $0.1 }
        }
    }
}
