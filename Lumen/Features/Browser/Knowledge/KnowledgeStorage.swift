import SQLite3
import Foundation
import Accelerate

struct Website: Identifiable, Codable, Equatable, Hashable, Sendable {
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
    var synthesisUpdatedAt: Date?
    var pageCountAtSynthesis: Int

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
        createdAt: Date = Date(),
        synthesisUpdatedAt: Date? = nil,
        pageCountAtSynthesis: Int = 0
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
        self.synthesisUpdatedAt = synthesisUpdatedAt
        self.pageCountAtSynthesis = pageCountAtSynthesis
    }
}

struct Topic: Identifiable, Codable, Equatable, Hashable, Sendable {
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

struct PageContent: Identifiable, Codable, Equatable, Hashable, Sendable {
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

    nonisolated static func normalizeURL(_ url: String) -> String {
        var normalized = url.lowercased()
        normalized = normalized.replacingOccurrences(of: "https://", with: "")
        normalized = normalized.replacingOccurrences(of: "http://", with: "")
        normalized = normalized.replacingOccurrences(of: "www.", with: "")
        if normalized.hasSuffix("/") { normalized.removeLast() }
        return normalized
    }

    nonisolated static func extractDomain(from url: String) -> String {
        guard let host = URL(string: url)?.host else { return "" }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    nonisolated static func countWords(in text: String) -> Int {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }
}

struct StorageStats: Sendable {
    let totalWebsites: Int
    let totalPages: Int
    let totalWords: Int
    let totalTopics: Int
    let oldestPage: Date?
    let newestPage: Date?
    let topWebsites: [(website: String, pageCount: Int)]
    let databaseSizeBytes: Int
}

extension String {
    static func topicID() -> String { return "topic_\(UUID().uuidString)" }
    static func websiteID() -> String { return "website_\(UUID().uuidString)" }
    static func pageID() -> String { return "page_\(UUID().uuidString)" }
}

enum VectorMath: Sendable {
    nonisolated static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dotProduct: Double = 0
        vDSP_dotprD(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))

        var sumSquaresA: Double = 0
        vDSP_svesqD(a, 1, &sumSquaresA, vDSP_Length(a.count))
        let magA = sqrt(sumSquaresA)

        var sumSquaresB: Double = 0
        vDSP_svesqD(b, 1, &sumSquaresB, vDSP_Length(b.count))
        let magB = sqrt(sumSquaresB)

        guard magA > 0 && magB > 0 else { return 0 }
        return dotProduct / (magA * magB)
    }
}

actor KnowledgeStorage {
    static let shared = KnowledgeStorage()

    private var db: OpaquePointer?
    private let dbPath: String
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private init() {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDirectory = paths[0].appendingPathComponent("Lumen", isDirectory: true)

        try? FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)

        self.dbPath = appSupportDirectory.appendingPathComponent("knowledge.sqlite").path
    }

    func initialize() throws {
        guard db == nil else { return }

        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            throw StorageError.failedToOpenDatabase
        }

        try execute("PRAGMA journal_mode=WAL")
        try execute("PRAGMA synchronous=NORMAL")

        try execute("BEGIN TRANSACTION")
        do {
            try createTables()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }

        try runMigrations()
    }

    private func createTables() throws {
        let createTopicsTable = """
        CREATE TABLE IF NOT EXISTS topics (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color TEXT,
            website_count INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL
        );
        """

        let createWebsitesTable = """
        CREATE TABLE IF NOT EXISTS websites (
            id TEXT PRIMARY KEY,
            domain TEXT NOT NULL UNIQUE,
            display_name TEXT NOT NULL,
            summary TEXT,
            favicon TEXT,
            topic_id TEXT,
            page_count INTEGER DEFAULT 0,
            total_words INTEGER DEFAULT 0,
            first_visit INTEGER NOT NULL,
            last_visit INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            synthesis_updated_at INTEGER,
            page_count_at_synthesis INTEGER DEFAULT 0,
            FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE SET NULL
        );
        """

        let createPagesTable = """
        CREATE TABLE IF NOT EXISTS pages (
            id TEXT PRIMARY KEY,
            website_id TEXT NOT NULL,
            url TEXT NOT NULL,
            normalized_url TEXT NOT NULL UNIQUE,
            domain TEXT NOT NULL,
            title TEXT,
            content TEXT NOT NULL,
            summary TEXT,
            timestamp INTEGER NOT NULL,
            author TEXT,
            description TEXT,
            reading_time INTEGER,
            scroll_depth REAL,
            word_count INTEGER,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (website_id) REFERENCES websites(id) ON DELETE CASCADE
        );
        """

        let createIndexes = """
        CREATE INDEX IF NOT EXISTS idx_websites_topic ON websites(topic_id);
        CREATE INDEX IF NOT EXISTS idx_websites_last_visit ON websites(last_visit DESC);
        CREATE INDEX IF NOT EXISTS idx_pages_website ON pages(website_id);
        CREATE INDEX IF NOT EXISTS idx_pages_timestamp ON pages(timestamp DESC);
        """

        let createEmbeddingsTable = """
        CREATE TABLE IF NOT EXISTS page_embeddings (
            page_id TEXT PRIMARY KEY,
            vector BLOB NOT NULL,
            FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
        );
        """

        let createFTS = """
        CREATE VIRTUAL TABLE IF NOT EXISTS pages_fts USING fts5(
            title,
            body
        );
        """

        let createFTSTriggers = """
        CREATE TRIGGER IF NOT EXISTS pages_ai AFTER INSERT ON pages BEGIN
            INSERT INTO pages_fts(title, body)
            VALUES (new.title, new.content);
        END;

        CREATE TRIGGER IF NOT EXISTS pages_ad AFTER DELETE ON pages BEGIN
            DELETE FROM pages_fts WHERE title = old.title AND body = old.content;
        END;

        CREATE TRIGGER IF NOT EXISTS pages_au AFTER UPDATE ON pages BEGIN
            DELETE FROM pages_fts WHERE title = old.title AND body = old.content;
            INSERT INTO pages_fts(title, body)
            VALUES (new.title, new.content);
        END;
        """

        try execute(createTopicsTable)
        try execute(createWebsitesTable)
        try execute(createPagesTable)
        try execute(createEmbeddingsTable)
        try execute(createIndexes)
        try execute(createFTS)
        try execute(createFTSTriggers)
    }

    private func runMigrations() throws {
        if try !columnExists(table: "websites", column: "synthesis_updated_at") {
            try execute("ALTER TABLE websites ADD COLUMN synthesis_updated_at INTEGER")
        }
        if try !columnExists(table: "websites", column: "page_count_at_synthesis") {
            try execute("ALTER TABLE websites ADD COLUMN page_count_at_synthesis INTEGER DEFAULT 0")
        }
    }

    private func columnExists(table: String, column: String) throws -> Bool {
        let sql = "PRAGMA table_info(\(table))"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            let columnName = String(cString: sqlite3_column_text(statement, 1))
            if columnName == column {
                return true
            }
            
        }
        return false
    }

    func save(
        url: String,
        title: String?,
        content: String,
        author: String? = nil,
        summary: String? = nil,
        description: String? = nil,
        readingTime: Int? = nil,
        scrollDepth: Double? = nil
    ) async throws -> String {
        try initialize()

        let domain = PageContent.extractDomain(from: url)
        let websiteID: String
        if let existingWebsite = try await fetchWebsite(domain: domain) {
            websiteID = existingWebsite.id
        } else {
            let newWebsite = await Website(domain: domain, displayName: domain)
            try createWebsite(website: newWebsite)
            websiteID = newWebsite.id
        }

        let page = await PageContent(
            websiteID: websiteID,
            url: url,
            title: title,
            content: content,
            summary: summary,
            author: author,
            description: description,
            readingTime: readingTime,
            scrollDepth: scrollDepth
        )

        try savePage(page)
        try updateWebsiteStats(websiteID: websiteID)

        return page.id
    }

    private func savePage(_ page: PageContent) throws {
        let sql = """
        INSERT OR REPLACE INTO pages (
            id, website_id, url, normalized_url, domain, title, content, summary,
            timestamp, author, description, reading_time, scroll_depth, word_count, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, page.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, page.websiteID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, page.url, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, page.normalizedURL, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, page.domain, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 6, page.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 7, page.content, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 8, page.summary, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 9, Int64(page.timestamp.timeIntervalSince1970))
        sqlite3_bind_text(statement, 10, page.author, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 11, page.description, -1, SQLITE_TRANSIENT)

        if let readingTime = page.readingTime {
            sqlite3_bind_int(statement, 12, Int32(readingTime))
        } else {
            sqlite3_bind_null(statement, 12)
        }

        if let scrollDepth = page.scrollDepth {
            sqlite3_bind_double(statement, 13, scrollDepth)
        } else {
            sqlite3_bind_null(statement, 13)
        }

        sqlite3_bind_int(statement, 14, Int32(page.wordCount))
        sqlite3_bind_int64(statement, 15, Int64(page.createdAt.timeIntervalSince1970))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StorageError.failedToInsert(String(cString: sqlite3_errmsg(db)))
        }
    }

    func createWebsite(website: Website) throws {
        let sql = """
        INSERT OR REPLACE INTO websites (
            id, domain, display_name, summary, topic_id, page_count, total_words,
            first_visit, last_visit, created_at, synthesis_updated_at, page_count_at_synthesis
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        try execute(sql, bindValues: { [self] statement in
            sqlite3_bind_text(statement, 1, website.id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, website.domain, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, website.displayName, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 4, website.summary, -1, SQLITE_TRANSIENT)
            if let topicID = website.topicID {
                sqlite3_bind_text(statement, 5, topicID, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, 5)
            }
            sqlite3_bind_int(statement, 6, Int32(website.pageCount))
            sqlite3_bind_int(statement, 7, Int32(website.totalWords))
            sqlite3_bind_int64(statement, 8, Int64(website.firstVisit.timeIntervalSince1970))
            sqlite3_bind_int64(statement, 9, Int64(website.lastVisit.timeIntervalSince1970))
            sqlite3_bind_int64(statement, 10, Int64(website.createdAt.timeIntervalSince1970))
            if let synthesisDate = website.synthesisUpdatedAt {
                sqlite3_bind_int64(statement, 11, Int64(synthesisDate.timeIntervalSince1970))
            } else {
                sqlite3_bind_null(statement, 11)
            }
            sqlite3_bind_int(statement, 12, Int32(website.pageCountAtSynthesis))
        })
    }

    func updateWebsite(_ website: Website) throws {
        let sql = """
        UPDATE websites SET
            domain = ?,
            display_name = ?,
            summary = ?,
            topic_id = ?,
            page_count = ?,
            total_words = ?,
            last_visit = ?,
            synthesis_updated_at = ?,
            page_count_at_synthesis = ?
        WHERE id = ?
        """

        try execute(sql, bindValues: { [self] statement in
            sqlite3_bind_text(statement, 1, website.domain, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, website.displayName, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, website.summary, -1, SQLITE_TRANSIENT)
            if let topicID = website.topicID {
                sqlite3_bind_text(statement, 4, topicID, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, 4)
            }
            sqlite3_bind_int(statement, 5, Int32(website.pageCount))
            sqlite3_bind_int(statement, 6, Int32(website.totalWords))
            sqlite3_bind_int64(statement, 7, Int64(website.lastVisit.timeIntervalSince1970))
            if let synthesisDate = website.synthesisUpdatedAt {
                sqlite3_bind_int64(statement, 8, Int64(synthesisDate.timeIntervalSince1970))
            } else {
                sqlite3_bind_null(statement, 8)
            }
            sqlite3_bind_int(statement, 9, Int32(website.pageCountAtSynthesis))
            sqlite3_bind_text(statement, 10, website.id, -1, SQLITE_TRANSIENT)
        })
    }

    func updateWebsiteSynthesis(websiteID: String, summary: String, pageCount: Int) throws {
        try initialize()
        let sql = """
        UPDATE websites SET
            summary = ?,
            synthesis_updated_at = ?,
            page_count_at_synthesis = ?
        WHERE id = ?
        """
        let now = Int64(Date().timeIntervalSince1970)
        try execute(sql, bindValues: { [self] statement in
            sqlite3_bind_text(statement, 1, summary, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(statement, 2, now)
            sqlite3_bind_int(statement, 3, Int32(pageCount))
            sqlite3_bind_text(statement, 4, websiteID, -1, SQLITE_TRANSIENT)
        })
    }

    func updatePageEngagement(url: String, scrollDepth: Double, readingTime: Int) throws {
        try initialize()
        let normalizedURL = PageContent.normalizeURL(url)
        let sql = """
        UPDATE pages SET
            scroll_depth = ?,
            reading_time = ?
        WHERE normalized_url = ?
        """

        try execute(sql, bindValues: { [self] statement in
            sqlite3_bind_double(statement, 1, scrollDepth)
            sqlite3_bind_int(statement, 2, Int32(readingTime))
            sqlite3_bind_text(statement, 3, normalizedURL, -1, SQLITE_TRANSIENT)
        })
    }

    func fetchTopic(name: String) async throws -> Topic? {
        try initialize()

        let sql = "SELECT * FROM topics WHERE name = ?"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, name, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return try await parseTopic(from: statement)
    }

    func fetchWebsite(domain: String) async throws -> Website? {
        try initialize()

        let sql = "SELECT * FROM websites WHERE domain = ?"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, domain, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return try await parseWebsite(from: statement)
    }

    func saveEmbedding(pageID: String, vector: [Double]) throws {
        try initialize()
        let sql = "INSERT OR REPLACE INTO page_embeddings (page_id, vector) VALUES (?, ?)"
        let data = vector.withUnsafeBytes { Data($0) }

        try execute(sql, bindValues: { [self] statement in
            sqlite3_bind_text(statement, 1, pageID, -1, SQLITE_TRANSIENT)
            sqlite3_bind_blob(statement, 2, (data as NSData).bytes, Int32(data.count), SQLITE_TRANSIENT)
        })
    }

    func searchSemantic(query: String, limit: Int = 3) async throws -> [PageContent] {
        try initialize()

        guard let queryVector = await EmbeddingService.shared.generateEmbedding(for: query) else {
            return []
        }

        let sql = """
            SELECT pe.page_id, pe.vector FROM page_embeddings pe
            JOIN pages p ON pe.page_id = p.id
            ORDER BY p.timestamp DESC
            LIMIT 500
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        var similarities: [(pageID: String, score: Double)] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let pageID = String(cString: sqlite3_column_text(statement, 0))
            let blobData = sqlite3_column_blob(statement, 1)
            let blobSize = Int(sqlite3_column_bytes(statement, 1))

            guard let rawPtr = blobData, blobSize > 0 else { continue }
            let count = blobSize / MemoryLayout<Double>.size
            guard count > 0 else { continue }
            let vector = Array(UnsafeBufferPointer(start: rawPtr.assumingMemoryBound(to: Double.self), count: count))

            let score = VectorMath.cosineSimilarity(queryVector, vector)
            similarities.append((pageID: pageID, score: score))
        }

        let topResults = similarities
            .sorted { $0.score > $1.score }
            .prefix(limit)

        var pages: [PageContent] = []
        for result in topResults {
            if let page = try await fetchPage(pageID: result.pageID) {
                pages.append(page)
            }
        }

        return pages
    }

    func fetchAllWebsites() async throws -> [Website] {
        try initialize()

        let sql = "SELECT * FROM websites ORDER BY last_visit DESC"
        return try await queryWebsites(sql: sql)
    }

    func fetchAllTopics() async throws -> [Topic] {
        try initialize()
        let sql = "SELECT * FROM topics ORDER BY name ASC"
        return try await queryTopics(sql: sql)
    }

    func fetchWebsites(for topicID: String) async throws -> [Website] {
        try initialize()
        let sql = "SELECT * FROM websites WHERE topic_id = ? ORDER BY last_visit DESC"
        return try await queryWebsites(sql: sql) { [self] statement in
            sqlite3_bind_text(statement, 1, (topicID as NSString).utf8String, -1, self.SQLITE_TRANSIENT)
        }
    }

    private func updateWebsiteStats(websiteID: String) throws {
        let sql = """
        UPDATE websites SET
            page_count = (SELECT COUNT(*) FROM pages WHERE website_id = ?),
            total_words = (SELECT COALESCE(SUM(word_count), 0) FROM pages WHERE website_id = ?),
            last_visit = (SELECT MAX(timestamp) FROM pages WHERE website_id = ?)
        WHERE id = ?
        """

        try execute(sql, bindValues: { [self] statement in
            sqlite3_bind_text(statement, 1, websiteID, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, websiteID, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, websiteID, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 4, websiteID, -1, SQLITE_TRANSIENT)
        })
    }

    func deleteWebsite(websiteID: String) throws {
        try initialize()

        let sql = "DELETE FROM websites WHERE id = ?"
        try execute(sql, bindValues: { statement in
            sqlite3_bind_text(statement, 1, websiteID, -1, self.SQLITE_TRANSIENT)
        })

    }

    func fetchPages(websiteID: String) async throws -> [PageContent] {
        try initialize()

        let sql = "SELECT * FROM pages WHERE website_id = ? ORDER BY timestamp DESC"
        return try await queryPages(sql: sql, bindValues: { statement in
            sqlite3_bind_text(statement, 1, websiteID, -1, self.SQLITE_TRANSIENT)
        })
    }

    func fetchPage(pageID: String) async throws -> PageContent? {
        try initialize()

        let sql = "SELECT * FROM pages WHERE id = ?"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, pageID, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return try await parsePage(from: statement)
    }

    func searchPages(query: String, limit: Int = 50) async throws -> [PageContent] {
        try initialize()

        let sql = """
        SELECT p.* FROM pages p
        JOIN pages_fts ON p.rowid = pages_fts.rowid
        WHERE pages_fts MATCH ?
        ORDER BY rank
        LIMIT ?
        """

        return try await queryPages(sql: sql, bindValues: { statement in
            sqlite3_bind_text(statement, 1, query, -1, self.SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 2, Int32(limit))
        })
    }

    func deletePage(pageID: String) async throws {
        try initialize()

        guard let page = try await fetchPage(pageID: pageID) else { return }

        let sql = "DELETE FROM pages WHERE id = ?"
        try execute(sql, bindValues: { statement in
            sqlite3_bind_text(statement, 1, pageID, -1, self.SQLITE_TRANSIENT)
        })

        try updateWebsiteStats(websiteID: page.websiteID)
    }

    func createTopic(name: String, color: String? = nil) async throws -> String {
        try initialize()

        let topic = await Topic(name: name, color: color)

        let sql = """
        INSERT INTO topics (id, name, color, website_count, created_at)
        VALUES (?, ?, ?, ?, ?)
        """

        try execute(sql, bindValues: { [self] statement in
            sqlite3_bind_text(statement, 1, topic.id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, topic.name, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, topic.color, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 4, Int32(topic.websiteCount))
            sqlite3_bind_int64(statement, 5, Int64(topic.createdAt.timeIntervalSince1970))
        })

        return topic.id
    }

    func assignWebsiteToTopic(websiteID: String, topicID: String?) throws {
        try initialize()

        let sql = "UPDATE websites SET topic_id = ? WHERE id = ?"
        try execute(sql, bindValues: { [self] statement in
            if let topicID = topicID {
                sqlite3_bind_text(statement, 1, topicID, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, 1)
            }
            sqlite3_bind_text(statement, 2, websiteID, -1, SQLITE_TRANSIENT)
        })

        try updateTopicCounts()
    }

    private func updateTopicCounts() throws {
        let sql = """
        UPDATE topics SET website_count = (
            SELECT COUNT(*) FROM websites WHERE topic_id = topics.id
        )
        """
        try execute(sql)
    }

    func deleteTopic(topicID: String) throws {
        try initialize()

        let sql = "DELETE FROM topics WHERE id = ?"
        try execute(sql, bindValues: { statement in
            sqlite3_bind_text(statement, 1, topicID, -1, self.SQLITE_TRANSIENT)
        })
    }

    func deleteAllTopics() throws {
        try initialize()
        try execute("DELETE FROM pages")
        try execute("DELETE FROM websites")
        try execute("DELETE FROM topics")
    }

    func seedTestData() async throws {
        try initialize()

        try execute("BEGIN TRANSACTION")
        do {
            try deleteAllTopics()

            let topicID = try await createTopic(name: "Technology", color: "#4A90E2")

            let apple = await Website(
                domain: "apple.com",
                displayName: "Apple",
                summary: "Official Apple website",
                topicID: topicID
            )
            try createWebsite(website: apple)

            let github = await Website(
                domain: "github.com",
                displayName: "GitHub",
                summary: "Where the world builds software",
                topicID: topicID
            )
            try createWebsite(website: github)

            let theverge = await Website(
                domain: "theverge.com",
                displayName: "The Verge",
                summary: "Tech news and reviews",
                topicID: topicID
            )
            try createWebsite(website: theverge)

            let seedPages: [(website: Website, title: String, summary: String)] = [
                (apple, "Apple Intelligence Overview",
                 "Covers Apple's on-device AI features in iOS 18, including Writing Tools, Image Playground, and Siri upgrades."),
                (apple, "WWDC 2025 Highlights",
                 "Swift 6 language changes, visionOS 3 updates, and new SwiftUI APIs for spatial computing."),
                (github, "GitHub Copilot Workspace",
                 "AI-assisted code planning tool that turns issues into pull requests with multi-file context."),
                (github, "GitHub Actions improvements",
                 "New arm64 runners, faster caching, and improved secrets management in Actions 2025."),
                (theverge, "The state of AI browsers",
                 "Survey of browsers integrating LLMs: Arc, Opera, Brave, and new challengers."),
            ]

            var offset: TimeInterval = 0
            for item in seedPages {
                let page = await PageContent(
                    websiteID: item.website.id,
                    url: "https://\(item.website.domain)/\(item.title.lowercased().replacingOccurrences(of: " ", with: "-"))",
                    title: item.title,
                    content: item.summary,
                    summary: item.summary,
                    timestamp: Date().addingTimeInterval(-offset),
                    readingTime: Int.random(in: 4...15),
                    scrollDepth: Double.random(in: 0.5...1.0)
                )
                offset += 3600
                try savePage(page)
                try updateWebsiteStats(websiteID: item.website.id)
            }

            try updateTopicCounts()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    func nukeDatabase() throws {
        if let db = db {
            let _ = sqlite3_close_v2(db)
            self.db = nil
        }

        let fileManager = FileManager.default
        let appSupportDirectory = URL(fileURLWithPath: dbPath).deletingLastPathComponent()

        if fileManager.fileExists(atPath: appSupportDirectory.path) {
            let files = try fileManager.contentsOfDirectory(at: appSupportDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
        }

        try initialize()
    }

    func getStats() async throws -> StorageStats {
        try initialize()
        var totalPages = 0
        var totalWords = 0
        var totalTopics = 0
        var totalWebsites = 0
        var oldestTimestamp: Int64?
        var newestTimestamp: Int64?

        let countSQL = """
        SELECT
            (SELECT COUNT(*) FROM websites),
            (SELECT COUNT(*) FROM pages),
            (SELECT SUM(word_count) FROM pages),
            (SELECT COUNT(*) FROM topics),
            (SELECT MIN(timestamp) FROM pages),
            (SELECT MAX(timestamp) FROM pages)
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, countSQL, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        if sqlite3_step(statement) == SQLITE_ROW {
            totalWebsites = Int(sqlite3_column_int(statement, 0))
            totalPages = Int(sqlite3_column_int(statement, 1))
            totalWords = Int(sqlite3_column_int(statement, 2))
            totalTopics = Int(sqlite3_column_int(statement, 3))

            if sqlite3_column_type(statement, 4) != SQLITE_NULL {
                oldestTimestamp = sqlite3_column_int64(statement, 4)
            }
            if sqlite3_column_type(statement, 5) != SQLITE_NULL {
                newestTimestamp = sqlite3_column_int64(statement, 5)
            }
        }

        let topWebsites = try await fetchAllWebsites().prefix(10).map { ($0.domain, $0.pageCount) }

        let fileSize = try? FileManager.default.attributesOfItem(atPath: dbPath)[.size] as? Int ?? 0

        return StorageStats(
            totalWebsites: totalWebsites,
            totalPages: totalPages,
            totalWords: totalWords,
            totalTopics: totalTopics,
            oldestPage: oldestTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            newestPage: newestTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            topWebsites: topWebsites,
            databaseSizeBytes: fileSize ?? 0
        )
    }

    private func queryPages(sql: String, bindValues: ((OpaquePointer?) -> Void)? = nil) async throws -> [PageContent] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        bindValues?(statement)

        var results: [PageContent] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            await results.append(try parsePage(from: statement))
        }

        return results
    }

    private func queryWebsites(sql: String, bindValues: ((OpaquePointer?) -> Void)? = nil) async throws -> [Website] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        bindValues?(statement)

        var results: [Website] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            await results.append(try parseWebsite(from: statement))
        }

        return results
    }

    private func queryTopics(sql: String, bindValues: ((OpaquePointer?) -> Void)? = nil) async throws -> [Topic] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        bindValues?(statement)

        var results: [Topic] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            await results.append(try parseTopic(from: statement))
        }

        return results
    }

    private func execute(_ sql: String, bindValues: ((OpaquePointer?) -> Void)? = nil) throws {
        var currentSql = sql

        while !currentSql.isEmpty {
            var statement: OpaquePointer?
            var tail: UnsafePointer<Int8>?

            let result = sqlite3_prepare_v2(db, currentSql, -1, &statement, &tail)
            guard result == SQLITE_OK else {
                throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
            }

            if let statement = statement {
                defer { sqlite3_finalize(statement) }

                bindValues?(statement)

                let stepResult = sqlite3_step(statement)
                guard stepResult == SQLITE_DONE || stepResult == SQLITE_ROW else {
                    throw StorageError.failedToExecute(String(cString: sqlite3_errmsg(db)))
                }
            }

            if let tail = tail {
                let tailStr = String(cString: tail).trimmingCharacters(in: .whitespacesAndNewlines)
                currentSql = tailStr
            } else {
                currentSql = ""
            }
        }
    }

    private func parsePage(from statement: OpaquePointer?) async throws -> PageContent {
        let id = String(cString: sqlite3_column_text(statement, 0))
        let websiteID = String(cString: sqlite3_column_text(statement, 1))
        let url = String(cString: sqlite3_column_text(statement, 2))

        let title = sqlite3_column_type(statement, 5) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(statement, 5)) : nil

        let content = String(cString: sqlite3_column_text(statement, 6))

        let summary = sqlite3_column_type(statement, 7) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(statement, 7)) : nil

        let timestamp = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 8)))

        let author = sqlite3_column_type(statement, 9) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(statement, 9)) : nil

        let description = sqlite3_column_type(statement, 10) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(statement, 10)) : nil

        let readingTime = sqlite3_column_type(statement, 11) != SQLITE_NULL
            ? Int(sqlite3_column_int(statement, 11)) : nil

        let scrollDepth = sqlite3_column_type(statement, 12) != SQLITE_NULL
            ? sqlite3_column_double(statement, 12) : nil

        let _ = Int(sqlite3_column_int(statement, 13))
        let createdAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 14)))

        return await PageContent(
            id: id,
            websiteID: websiteID,
            url: url,
            title: title,
            content: content,
            summary: summary,
            timestamp: timestamp,
            author: author,
            description: description,
            readingTime: readingTime,
            scrollDepth: scrollDepth,
            createdAt: createdAt
        )
    }

    private func parseWebsite(from statement: OpaquePointer?) async throws -> Website {
        let id = String(cString: sqlite3_column_text(statement, 0))
        let domain = String(cString: sqlite3_column_text(statement, 1))
        let displayName = String(cString: sqlite3_column_text(statement, 2))

        let summary = sqlite3_column_type(statement, 3) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(statement, 3)) : nil

        let favicon = sqlite3_column_type(statement, 4) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(statement, 4)) : nil

        let topicID = sqlite3_column_type(statement, 5) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(statement, 5)) : nil

        let pageCount = Int(sqlite3_column_int(statement, 6))
        let totalWords = Int(sqlite3_column_int(statement, 7))
        let firstVisit = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 8)))
        let lastVisit = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 9)))
        let createdAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 10)))

        let synthesisUpdatedAt: Date? = sqlite3_column_type(statement, 11) != SQLITE_NULL
            ? Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 11))) : nil
        let pageCountAtSynthesis = Int(sqlite3_column_int(statement, 12))

        return await Website(
            id: id,
            domain: domain,
            displayName: displayName,
            summary: summary,
            favicon: favicon,
            topicID: topicID,
            pageCount: pageCount,
            totalWords: totalWords,
            firstVisit: firstVisit,
            lastVisit: lastVisit,
            createdAt: createdAt,
            synthesisUpdatedAt: synthesisUpdatedAt,
            pageCountAtSynthesis: pageCountAtSynthesis
        )
    }

    private func parseTopic(from statement: OpaquePointer?) async throws -> Topic {
        let id = String(cString: sqlite3_column_text(statement, 0))
        let name = String(cString: sqlite3_column_text(statement, 1))

        let color = sqlite3_column_type(statement, 2) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(statement, 2)) : nil

        let websiteCount = Int(sqlite3_column_int(statement, 3))
        let createdAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 4)))

        return await Topic(
            id: id,
            name: name,
            color: color,
            websiteCount: websiteCount,
            createdAt: createdAt
        )
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
}

enum StorageError: Error, LocalizedError {
    case failedToOpenDatabase
    case failedToPrepare(String)
    case failedToInsert(String)
    case failedToExecute(String)

    var errorDescription: String? {
        switch self {
        case .failedToOpenDatabase:
            return "Failed to open database"
        case .failedToPrepare(let msg):
            return "Failed to prepare statement: \(msg)"
        case .failedToInsert(let msg):
            return "Failed to insert: \(msg)"
        case .failedToExecute(let msg):
            return "Failed to execute: \(msg)"
        }
    }
}
