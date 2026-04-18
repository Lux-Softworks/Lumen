import Foundation

struct CaptureQuality {
    let score: Double
    let shouldCapturePage: Bool
    let shouldCreateWebsite: Bool

    private static let blockedPathPatterns: [String] = [
        "/search", "/results", "/find",
        "/login", "/signin", "/sign-in", "/signup", "/sign-up", "/register",
        "/logout", "/account", "/settings", "/preferences", "/checkout",
        "/cart", "/oauth", "/auth"
    ]

    private static let blockedDomainSubstrings: [String] = [
        "google.", "bing.com", "duckduckgo.com", "yahoo.com", "baidu.com",
        "ecosia.org", "startpage.com", "kagi.com", "brave.com/search",
        "chat.openai.com", "claude.ai", "gemini.google.com",
        "accounts.", "login.", "auth."
    ]

    static func evaluate(
        url: String,
        domain: String,
        wordCount: Int,
        readingTime: Int,
        scrollDepth: Double,
        hasArticleMetadata: Bool
    ) -> CaptureQuality {
        let lowerDomain = domain.lowercased()
        let lowerURL = url.lowercased()

        for pattern in blockedDomainSubstrings {
            if lowerDomain.contains(pattern) || lowerURL.contains(pattern) {
                return CaptureQuality(score: 0, shouldCapturePage: false, shouldCreateWebsite: false)
            }
        }

        if let parsed = URL(string: url) {
            let path = parsed.path.lowercased()
            for pattern in blockedPathPatterns where path.hasPrefix(pattern) {
                return CaptureQuality(score: 0, shouldCapturePage: false, shouldCreateWebsite: false)
            }

            if let query = parsed.query?.lowercased(),
               query.contains("q=") || query.contains("query=") || query.contains("search=") {
                return CaptureQuality(score: 0, shouldCapturePage: false, shouldCreateWebsite: false)
            }
        }

        var score: Double = 0

        if wordCount >= 120 { score += 1 }
        if wordCount >= 400 { score += 1 }
        if wordCount >= 1000 { score += 1 }

        if readingTime >= 15 { score += 1 }
        if readingTime >= 45 { score += 1 }
        if readingTime >= 120 { score += 1 }

        let scrollTarget = expectedScrollTarget(wordCount: wordCount)
        if scrollDepth >= scrollTarget * 0.6 { score += 0.5 }
        if scrollDepth >= scrollTarget { score += 0.5 }

        if hasArticleMetadata { score += 1 }

        let expectedReadSeconds = max(10, Double(wordCount) / 250.0 * 60.0)
        let readProgress = Double(readingTime) / expectedReadSeconds
        if readProgress >= 0.15 { score += 0.5 }
        if readProgress >= 0.4 { score += 0.5 }

        let engagementFloor = readingTime >= 10 && scrollDepth >= 0.15
        let contentFloor = wordCount >= 100

        let shouldCapturePage = engagementFloor && contentFloor && score >= 2.0

        return CaptureQuality(
            score: score,
            shouldCapturePage: shouldCapturePage,
            shouldCreateWebsite: shouldCapturePage
        )
    }

    private static func expectedScrollTarget(wordCount: Int) -> Double {
        switch wordCount {
        case 0..<300: return 0.75
        case 300..<800: return 0.55
        case 800..<2500: return 0.35
        default: return 0.22
        }
    }
}
