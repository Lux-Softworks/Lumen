import Foundation

enum DomainNameFormatter {
    nonisolated private static let strippedSubdomains: Set<String> = [
        "www", "www1", "www2", "m", "mobile", "amp", "en",
        "app", "web", "site", "touch", "desktop", "beta"
    ]

    nonisolated private static let knownMultiTLDs: Set<String> = [
        "co.uk", "co.jp", "co.in", "co.kr", "co.za", "co.nz", "co.il",
        "com.au", "com.br", "com.cn", "com.mx", "com.ar", "com.sg", "com.tw", "com.hk",
        "ac.uk", "ac.jp", "ac.nz", "gov.uk", "gov.au", "org.uk", "ne.jp", "or.jp",
        "github.io", "compute.amazonaws.com", "herokuapp.com", "vercel.app", "netlify.app", "pages.dev"
    ]

    nonisolated private static let acronymApex: Set<String> = [
        "bbc", "cnn", "abc", "nbc", "cbs", "ibm", "nasa", "npr", "mit", "nsa",
        "nyt", "wsj", "ft", "fbi", "cia", "eu", "un", "who", "cdc",
        "aws", "gcp", "ios", "usa", "uk", "hbr"
    ]

    nonisolated private static let specialCases: [String: String] = [
        "youtube": "YouTube", "github": "GitHub", "gitlab": "GitLab",
        "icloud": "iCloud", "iphone": "iPhone", "ipad": "iPad", "imac": "iMac",
        "ebay": "eBay", "paypal": "PayPal", "deepmind": "DeepMind",
        "openai": "OpenAI", "stackoverflow": "Stack Overflow",
        "stackexchange": "Stack Exchange", "hackernews": "Hacker News",
        "ycombinator": "Y Combinator", "tiktok": "TikTok",
        "dribbble": "Dribbble", "behance": "Behance",
        "linkedin": "LinkedIn", "instagram": "Instagram",
        "whatsapp": "WhatsApp", "airbnb": "Airbnb", "doordash": "DoorDash",
        "fedex": "FedEx", "ups": "UPS", "usps": "USPS",
        "nytimes": "The New York Times", "theverge": "The Verge",
        "theatlantic": "The Atlantic", "theguardian": "The Guardian",
        "medium": "Medium", "substack": "Substack",
        "reddit": "Reddit", "twitch": "Twitch", "x": "X",
        "chatgpt": "ChatGPT", "anthropic": "Anthropic",
        "vercel": "Vercel", "netlify": "Netlify", "cloudflare": "Cloudflare",
        "npmjs": "npm", "pypi": "PyPI", "arxiv": "arXiv",
        "soundcloud": "SoundCloud", "vimeo": "Vimeo"
    ]

    nonisolated private static let ipv4Regex = try? NSRegularExpression(
        pattern: #"^(\d{1,3}\.){3}\d{1,3}$"#
    )

    nonisolated static func format(host rawInput: String) -> String {
        let host = Self.extractHost(from: rawInput)
        guard !host.isEmpty else { return "" }

        if Self.isIPAddress(host) { return host }

        var labels = host.split(separator: ".").map(String.init)
        while let first = labels.first, strippedSubdomains.contains(first) {
            labels.removeFirst()
        }
        guard !labels.isEmpty else { return "" }

        let tldCount = Self.tldLabelCount(for: labels)
        let significant = max(labels.count - tldCount, 1)
        let nameLabels = Array(labels.prefix(significant))

        let parts = nameLabels.reversed().map(Self.humanize)

        if parts.count == 1 { return parts[0] }
        return parts.joined(separator: " ")
    }

    nonisolated private static func extractHost(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return "" }

        if let components = URLComponents(string: trimmed), let host = components.host, !host.isEmpty {
            return host
        }

        let candidate = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
            ? trimmed
            : "https://\(trimmed)"
        if let components = URLComponents(string: candidate), let host = components.host, !host.isEmpty {
            return host
        }

        if let slash = trimmed.firstIndex(of: "/") {
            return String(trimmed[..<slash])
        }
        return trimmed
    }

    nonisolated private static func isIPAddress(_ host: String) -> Bool {
        if host.contains(":") { return true }
        guard let regex = Self.ipv4Regex else { return false }
        let range = NSRange(host.startIndex..<host.endIndex, in: host)
        return regex.firstMatch(in: host, range: range) != nil
    }

    nonisolated private static func tldLabelCount(for labels: [String]) -> Int {
        guard labels.count >= 2 else { return labels.count }
        let last2 = labels.suffix(2).joined(separator: ".")
        if Self.knownMultiTLDs.contains(last2) { return 2 }
        return 1
    }

    nonisolated private static func humanize(_ label: String) -> String {
        if let special = Self.specialCases[label] { return special }
        if Self.acronymApex.contains(label) { return label.uppercased() }

        let tokens = label.split(whereSeparator: { $0 == "-" || $0 == "_" })
        let mapped: [String] = tokens.map { token in
            let key = String(token)
            if let special = Self.specialCases[key] { return special }
            if Self.acronymApex.contains(key) { return key.uppercased() }
            return key.prefix(1).uppercased() + key.dropFirst()
        }
        return mapped.joined(separator: " ")
    }
}
