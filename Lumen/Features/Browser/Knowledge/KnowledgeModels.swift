import Foundation

extension String {
    static func topicID() -> String {
        return "topic_\(UUID().uuidString)"
    }

    static func websiteID() -> String {
        return "website_\(UUID().uuidString)"
    }

    static func pageID() -> String {
        return "page_\(UUID().uuidString)"
    }

    var isTopic: Bool { hasPrefix("topic_") }
    var isWebsite: Bool { hasPrefix("website_") }
    var isPage: Bool { hasPrefix("page_") }
}

struct Website: Identifiable, Codable {
    let id: String
    let domain: String
    var displayName: String
    var summary: String?
    var topicID: String?
    var pageCount: Int
    var totalWords: Int
    let firstVisit: Date
    var lastVisit: Date
    let createdAt: Date

    init(
        id: String = .websiteID(),
        domain: String,
        displayName: String? = nil,
        summary: String? = nil,
        favicon: String? = nil,
        topicID: String? = nil,
        pageCount: Int = 0,
        totalWords: Int = 0,
        firstVisit: Date = Date(),
        lastVisit: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.domain = domain
        self.displayName = displayName ?? domain
        self.summary = summary
        self.topicID = topicID
        self.pageCount = pageCount
        self.totalWords = totalWords
        self.firstVisit = firstVisit
        self.lastVisit = lastVisit
        self.createdAt = createdAt
    }
}

struct Topic: Identifiable, Codable {
    let id: String
    let name: String
    let color: String?
    let websiteCount: Int
    let createdAt: Date

    init(
        id: String = .topicID(),
        name: String,
        color: String? = nil,
        websiteCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.websiteCount = websiteCount
        self.createdAt = createdAt
    }
}

struct PageContent: Identifiable, Codable {
    let id: String
    let websiteID: String
    let url: String
    let normalizedURL: String
    let domain: String
    let title: String?
    let content: String
    let summary: String?
    let timestamp: Date
    let author: String?
    let description: String?
    let readingTime: Int?
    let scrollDepth: Double?
    let wordCount: Int
    let createdAt: Date

    init(
        id: String = .pageID(),
        websiteID: String,
        url: String,
        title: String?,
        content: String,
        summary: String? = nil,
        timestamp: Date = Date(),
        author: String? = nil,
        description: String? = nil,
        readingTime: Int? = nil,
        scrollDepth: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.websiteID = websiteID
        self.url = url
        self.normalizedURL = Self.normalizeURL(url)
        self.domain = Self.extractDomain(from: url)
        self.title = title
        self.content = content
        self.summary = summary
        self.timestamp = timestamp
        self.author = author
        self.description = description
        self.readingTime = readingTime
        self.scrollDepth = scrollDepth
        self.wordCount = Self.countWords(in: content)
        self.createdAt = createdAt
    }

    static func normalizeURL(_ url: String) -> String {
        var normalized = url.lowercased()
        normalized = normalized.replacingOccurrences(of: "https://", with: "")
        normalized = normalized.replacingOccurrences(of: "http://", with: "")
        normalized = normalized.replacingOccurrences(of: "www.", with: "")
        if normalized.hasSuffix("/") { normalized.removeLast() }
        return normalized
    }

    static func extractDomain(from url: String) -> String {
        guard let host = URL(string: url)?.host else { return "" }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    static func countWords(in text: String) -> Int {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }
}

struct StorageStats {
    let totalWebsites: Int
    let totalPages: Int
    let totalWords: Int
    let totalTopics: Int
    let oldestPage: Date?
    let newestPage: Date?
    let topWebsites: [(website: String, pageCount: Int)]
    let databaseSizeBytes: Int
}
