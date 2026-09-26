import Foundation

enum SearchEngine: String, CaseIterable, Identifiable {
    case google = "Google"
    case duckDuckGo = "DuckDuckGo"
    case bing = "Bing"
    case brave = "Brave"

    var id: String { rawValue }

    var templateURL: String {
        switch self {
        case .google:
            return "https://www.google.com/search?q=%@"
        case .duckDuckGo:
            return "https://duckduckgo.com/?q=%@"
        case .bing:
            return "https://www.bing.com/search?q=%@"
        case .brave:
            return "https://search.brave.com/search?q=%@"
        }
    }

    func suggestionURL(for query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        let queryItems: [URLQueryItem]

        switch self {
        case .google:
            components.host = "suggestqueries.google.com"
            components.path = "/complete/search"
            queryItems = [
                URLQueryItem(name: "client", value: "firefox"),
                URLQueryItem(name: "q", value: query)
            ]
        case .duckDuckGo:
            components.host = "duckduckgo.com"
            components.path = "/ac/"
            queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "type", value: "list")
            ]
        case .bing:
            components.host = "api.bing.com"
            components.path = "/osjson.aspx"
            queryItems = [URLQueryItem(name: "query", value: query)]
        case .brave:
            components.host = "search.brave.com"
            components.path = "/api/suggest"
            queryItems = [URLQueryItem(name: "q", value: query)]
        }

        components.percentEncodedQueryItems = queryItems.map { item in
            URLQueryItem(name: item.name, value: item.value.map(Self.encodeQueryValue))
        }

        return components.url
    }

    private static func encodeQueryValue(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")

        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    var homePage: URL {
        switch self {
        case .google:
            return URL(string: "https://www.google.com")!
        case .duckDuckGo:
            return URL(string: "https://duckduckgo.com")!
        case .bing:
            return URL(string: "https://www.bing.com")!
        case .brave:
            return URL(string: "https://search.brave.com")!
        }
    }
}
