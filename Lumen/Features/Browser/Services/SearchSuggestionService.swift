import Combine
import Foundation

struct SearchSuggestion: Identifiable, Equatable, Hashable {
    let text: String
    var id: String { text }
}

final class SearchSuggestionService {
    static let shared = SearchSuggestionService()

    private static let maxSuggestions = 5

    private init() {}

    static func requestURL(
        for query: String,
        engine: SearchEngine,
        isIncognito: Bool,
        isEnabled: Bool
    ) -> URL? {
        guard isEnabled, !isIncognito else { return nil }

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        return engine.suggestionURL(for: trimmed)
    }

    static func parseSuggestions(from data: Data) -> [SearchSuggestion] {
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [Any],
            jsonArray.count >= 2,
            let suggestions = jsonArray[1] as? [String]
        else {
            return []
        }

        return suggestions.prefix(maxSuggestions).map { SearchSuggestion(text: $0) }
    }

    func fetchSuggestions(
        for query: String,
        engine: SearchEngine,
        isIncognito: Bool,
        isEnabled: Bool
    ) async throws -> [SearchSuggestion] {
        guard
            let url = Self.requestURL(
                for: query, engine: engine, isIncognito: isIncognito, isEnabled: isEnabled
            )
        else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        request.httpShouldHandleCookies = false

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }

        return Self.parseSuggestions(from: data)
    }
}
