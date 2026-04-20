import Foundation

struct CaptureQuality {
    let score: Double
    let shouldCapturePage: Bool
    let shouldCreateWebsite: Bool

    private static let blockedPathPatterns: [String] = [
        "/search", "/results", "/find",
        "/login", "/signin", "/sign-in", "/signup", "/sign-up", "/register",
        "/logout", "/account", "/settings", "/preferences", "/checkout",
        "/cart", "/oauth", "/auth", "/password", "/reset", "/verify",
        "/billing", "/payment", "/pay", "/subscription", "/wallet",
        "/admin", "/dashboard", "/inbox", "/messages", "/chat",
        "/dm", "/compose", "/profile/edit", "/security"
    ]

    private static let blockedDomainSubstrings: [String] = [
        "google.com/search", "bing.com/search", "duckduckgo.com", "yahoo.com/search",
        "baidu.com", "ecosia.org", "startpage.com", "kagi.com", "brave.com/search",
        "search.yahoo", "search.brave", "you.com",

        "chat.openai.com", "chatgpt.com", "claude.ai", "gemini.google.com",
        "copilot.microsoft.com", "bard.google.com", "poe.com", "perplexity.ai",

        "accounts.", "login.", "auth.", "signin.", "oauth.", "sso.",
        "myaccount.", "id.", "identity.",

        "mail.google.com", "outlook.live.com", "outlook.office.com", "mail.yahoo",
        "mail.proton", "protonmail.com", "fastmail.com", "icloud.com/mail",

        "bank", "chase.com", "wellsfargo.com", "citibank.com", "bankofamerica.com",
        "capitalone.com", "paypal.com", "venmo.com", "cashapp.com", "stripe.com/dashboard",
        "coinbase.com/account", "binance.com/my",

        "healthcare", "mychart.", "patient.", "kaiserpermanente.org",

        "web.whatsapp.com", "messenger.com", "telegram.org", "discord.com/channels",
        "slack.com/client", "teams.microsoft.com",

        "admin.", "portal.", "dashboard."
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

        return CaptureQuality(score: 1, shouldCapturePage: true, shouldCreateWebsite: true)
    }
}
