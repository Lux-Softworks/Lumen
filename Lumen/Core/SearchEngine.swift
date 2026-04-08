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
