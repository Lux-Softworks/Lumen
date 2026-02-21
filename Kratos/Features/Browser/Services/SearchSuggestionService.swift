import Combine
import Foundation

struct SearchSuggestion: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

final class SearchSuggestionService {
    static let shared = SearchSuggestionService()

    // We'll use Google's autocomplete API which is public and returns JSON array format
    // Format is usually: ["search query", ["suggestion 1", "suggestion 2", ...]]
    private let urlTemplate =
        "https://suggestqueries.google.com/complete/search?client=firefox&q=%@"

    private init() {}

    func fetchSuggestions(for query: String) async throws -> [SearchSuggestion] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        guard
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return [] }
        guard let url = URL(string: String(format: urlTemplate, encodedQuery)) else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0  // Fail fast to not hang UI

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }

        // Parse the top-level array
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data, options: []) as? [Any],
            jsonArray.count >= 2,
            let suggestionsArray = jsonArray[1] as? [String]
        else {
            return []
        }

        return suggestionsArray.prefix(8).map { SearchSuggestion(text: $0) }
    }
}
