import Foundation
import Observation

@Observable
@MainActor
final class KnowledgeAIViewModel {
    var query: String = ""
    var results: [PageContent] = []
    var isSearching: Bool = false
    var error: Error? = nil

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await KnowledgeStorage.shared.searchSemantic(query: trimmed, limit: 10)
        } catch {
            self.error = error
        }
    }

    func clearResults() {
        results = []
        error = nil
    }
}
