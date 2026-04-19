import Foundation
import NaturalLanguage

final class EmbeddingService: @unchecked Sendable {
    static let shared = EmbeddingService()

    private let embeddingModel: NLEmbedding?

    private init() {
        self.embeddingModel = NLEmbedding.sentenceEmbedding(for: .english)
    }

    func generateEmbedding(for text: String) -> [Double]? {
        guard !text.isEmpty, let model = embeddingModel else {
            return nil
        }

        return model.vector(for: text)
    }
}
