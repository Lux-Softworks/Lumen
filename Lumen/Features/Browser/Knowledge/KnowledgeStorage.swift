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
            body,
            content=pages,
            content_rowid=rowid
        );
        """

        let createFTSTriggers = """
        CREATE TRIGGER IF NOT EXISTS pages_ai AFTER INSERT ON pages BEGIN
            INSERT INTO pages_fts(rowid, title, body)
            VALUES (new.rowid, new.title, new.content);
        END;

        CREATE TRIGGER IF NOT EXISTS pages_ad AFTER DELETE ON pages BEGIN
            INSERT INTO pages_fts(pages_fts, rowid, title, body)
            VALUES ('delete', old.rowid, old.title, old.content);
        END;

        CREATE TRIGGER IF NOT EXISTS pages_au AFTER UPDATE ON pages BEGIN
            INSERT INTO pages_fts(pages_fts, rowid, title, body)
            VALUES ('delete', old.rowid, old.title, old.content);
            INSERT INTO pages_fts(rowid, title, body)
            VALUES (new.rowid, new.title, new.content);
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
        try migrateFTSToContentTable()
    }

    private func migrateFTSToContentTable() throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        let sql = "SELECT sql FROM sqlite_master WHERE type='table' AND name='pages_fts'"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW else { return }
        let createSQL = String(cString: sqlite3_column_text(statement, 0))
        if createSQL.contains("content=pages") { return }

        try execute("DROP TRIGGER IF EXISTS pages_ai")
        try execute("DROP TRIGGER IF EXISTS pages_ad")
        try execute("DROP TRIGGER IF EXISTS pages_au")
        try execute("DROP TABLE IF EXISTS pages_fts")
        try execute("""
            CREATE VIRTUAL TABLE pages_fts USING fts5(
                title, body, content=pages, content_rowid=rowid
            )
        """)
        try execute("INSERT INTO pages_fts(pages_fts) VALUES ('rebuild')")
        try execute("""
            CREATE TRIGGER pages_ai AFTER INSERT ON pages BEGIN
                INSERT INTO pages_fts(rowid, title, body) VALUES (new.rowid, new.title, new.content);
            END
        """)
        try execute("""
            CREATE TRIGGER pages_ad AFTER DELETE ON pages BEGIN
                INSERT INTO pages_fts(pages_fts, rowid, title, body) VALUES ('delete', old.rowid, old.title, old.content);
            END
        """)
        try execute("""
            CREATE TRIGGER pages_au AFTER UPDATE ON pages BEGIN
                INSERT INTO pages_fts(pages_fts, rowid, title, body) VALUES ('delete', old.rowid, old.title, old.content);
                INSERT INTO pages_fts(rowid, title, body) VALUES (new.rowid, new.title, new.content);
            END
        """)
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

    func deleteTopic(id: String) throws {
        try initialize()

        let steps: [String] = [
            "DELETE FROM page_embeddings WHERE page_id IN (SELECT p.id FROM pages p JOIN websites w ON p.website_id = w.id WHERE w.topic_id = ?)",
            "DELETE FROM pages WHERE website_id IN (SELECT id FROM websites WHERE topic_id = ?)",
            "DELETE FROM websites WHERE topic_id = ?",
            "DELETE FROM topics WHERE id = ?",
        ]

        for sql in steps {
            try execute(sql) { stmt in
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, self.SQLITE_TRANSIENT)
            }
        }
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

            let techID    = try await createTopic(name: "Technology",  color: "#4A90E2")
            let scienceID = try await createTopic(name: "Science",     color: "#7ED321")
            let financeID = try await createTopic(name: "Finance",     color: "#F5A623")

            let apple = await Website(domain: "apple.com", displayName: "Apple", summary: "Official Apple developer and product news.", topicID: techID)
            let verge = await Website(domain: "theverge.com", displayName: "The Verge", summary: "Tech news, reviews, and culture.", topicID: techID)
            let github = await Website(domain: "github.com", displayName: "GitHub", summary: "Where the world builds software.", topicID: techID)
            let nature = await Website(domain: "nature.com", displayName: "Nature", summary: "Peer-reviewed scientific research.", topicID: scienceID)
            let arxiv  = await Website(domain: "arxiv.org", displayName: "arXiv", summary: "Open-access research preprints.", topicID: scienceID)
            let wsj    = await Website(domain: "wsj.com", displayName: "Wall St. Journal", summary: "Financial and business news.", topicID: financeID)

            for site in [apple, verge, github, nature, arxiv, wsj] {
                try createWebsite(website: site)
            }

            typealias SeedEntry = (website: Website, title: String, content: String)
            let entries: [SeedEntry] = [
                (apple,
                 "Apple Intelligence: On-Device AI in iOS 18",
                 "Apple Intelligence is Apple's personal AI system deeply integrated into iOS 18, iPadOS 18, and macOS Sequoia. It processes most tasks entirely on-device using a 3-billion parameter language model, ensuring user data never leaves the device. Key capabilities include Writing Tools for rewriting and summarising text across all apps, Image Playground for generating images from text descriptions, and an upgraded Siri with richer context awareness. Apple partnered with OpenAI to offer optional ChatGPT integration for queries the on-device model cannot handle, with explicit user consent required each time. The on-device model runs on the Neural Engine inside A17 Pro and M-series chips. Private Cloud Compute routes more complex requests to Apple silicon servers where data is not retained. This architecture is Apple's answer to balancing AI capability with privacy."),

                (apple,
                 "WWDC 2025: Swift 6 and SwiftUI Advances",
                 "WWDC 2025 introduced Swift 6 with complete concurrency safety enforced at compile time, eliminating data races by default. SwiftUI gained a new observation framework using the @Observable macro, replacing ObservableObject for most patterns. The conference also unveiled visionOS 3 with hand-tracking improvements and a new spatial canvas API. Xcode 17 ships with a native AI code-completion engine powered by Apple Intelligence, offering context-aware suggestions across the entire project. The new Swift Testing library replaces XCTest for most unit testing scenarios with a macro-based syntax. Developers gained new APIs for Live Activities on the Dynamic Island and expanded WidgetKit support for interactive widgets with real-time server push."),

                (verge,
                 "The State of AI Browsers in 2025",
                 "AI-integrated browsers have moved from novelty to mainstream in 2025. Arc Browser by The Browser Company pioneered sidebar AI with Claude integration, letting users ask questions about the current page. Opera introduced Aria, a built-in AI assistant with real-time web search. Brave added a local on-device LLM option using Llama models so queries never leave the computer. Microsoft Edge's Copilot evolved into a full agentic assistant capable of filling forms, summarising PDFs, and composing emails from within the browser. Apple's Safari 18 gained Intelligent Search, distilling long articles into bullet-point summaries using on-device Apple Intelligence. The key differentiator across all these products is privacy: local inference wins for sensitive queries while cloud models remain superior for complex reasoning tasks."),

                (verge,
                 "Why On-Device AI Matters for Privacy",
                 "Running AI models locally on a device rather than in the cloud has profound privacy implications. When a user's queries and documents never leave their phone or laptop, they cannot be logged, analysed, or monetised by a server operator. On-device models like Apple's 3B model and Llama 3.2 3B make this practical on modern hardware. The tradeoff is capability: cloud models like GPT-4o and Claude 3.5 Sonnet have orders of magnitude more parameters and broader knowledge. Hybrid approaches are emerging where a small local model handles routine tasks and routes sensitive or complex queries to the cloud only with explicit user permission. For a personal browser with a knowledge base of reading history, on-device inference is the only reasonable privacy choice."),

                (github,
                 "GitHub Copilot Workspace: AI-Native Development",
                 "GitHub Copilot Workspace is a new agentic coding environment that starts from a GitHub issue and produces a fully implemented pull request. The user describes a task in natural language; Copilot plans the required file changes, writes the code across multiple files, runs tests, and submits a PR. It uses GPT-4o under the hood with a specialised code-execution sandbox. Workspace maintains full conversation context across the planning and implementation phases, allowing developers to redirect the agent mid-task. Early benchmarks show it completes simple bug-fix issues end-to-end in under five minutes. The product is positioned as an AI pair programmer rather than a code autocomplete tool, handling whole-feature implementation rather than line-level suggestions."),

                (github,
                 "GitHub Actions 2025: Faster CI/CD",
                 "GitHub Actions received major performance and security upgrades in 2025. New arm64 Linux runners are 40% faster and 50% cheaper than the previous x64 equivalents, driven by custom Ampere Altra hardware in GitHub's data centres. The cache action now supports cross-workflow cache sharing within the same repository, cutting cold-start times on monorepos dramatically. Secrets management was overhauled: organisation-level OIDC token binding means third-party cloud credentials are scoped to specific workflows and auto-rotate. The new Deployments API gives fine-grained control over multi-environment promotion with approval gates built into the workflow YAML. GitHub also launched a built-in code-scanning feature that runs Copilot-powered security analysis on every pull request."),

                (nature,
                 "Large Language Models Show Signs of Compositional Reasoning",
                 "A study published in Nature Machine Intelligence found that frontier large language models demonstrate a limited but measurable capacity for compositional reasoning — the ability to combine learned concepts in novel ways not seen during training. Researchers at DeepMind tested GPT-4, Claude 3, and Gemini Ultra on a benchmark of 10,000 novel symbol-manipulation tasks. All three models exceeded random baselines and generalised to unseen compositions, though accuracy dropped sharply with task depth beyond five compositional steps. The authors argue this suggests emergent systematic generalisation rather than pure memorisation, challenging earlier claims that transformers fundamentally cannot reason. The finding has implications for AI safety: models that can compose concepts may also be able to reason about their own constraints."),

                (arxiv,
                 "Retrieval-Augmented Generation: A Survey",
                 "Retrieval-Augmented Generation (RAG) enhances language model responses by first retrieving relevant documents from a corpus and then conditioning generation on those documents. This approach grounds the model's output in verifiable source material, reducing hallucination and extending the effective knowledge cutoff beyond training data. The survey covers three retrieval paradigms: sparse retrieval using BM25 keyword matching, dense retrieval using bi-encoder embeddings, and hybrid approaches combining both. Key challenges include retrieval latency, context window limits when many documents are retrieved, and faithfulness — ensuring the model cites sources it actually used. Advanced techniques like HyDE (Hypothetical Document Embeddings) generate a synthetic answer first, then retrieve documents similar to the hypothesis, improving recall on complex queries. RAG is now standard practice for enterprise AI deployments requiring factual accuracy."),

                (arxiv,
                 "Mixture of Experts Scaling in Language Models",
                 "Mixture of Experts (MoE) architecture allows language models to scale parameter count without proportionally increasing compute per token. In an MoE transformer, each token is routed to a small subset of specialised feed-forward networks called experts, typically 2 out of 64 or 128. Mistral's Mixtral 8x7B demonstrated that an MoE model with 46.7B total parameters matches a dense 70B model on most benchmarks while using roughly 12B parameters per forward pass. Google's Gemini 1.5 Pro uses a MoE design to achieve a one-million-token context window at practical serving costs. The key challenge is load balancing: auxiliary losses encourage uniform expert utilisation but can conflict with optimal routing. MoE models are now the dominant architecture for models above 30B effective parameters."),

                (wsj,
                 "Federal Reserve Holds Rates as Inflation Cools",
                 "The Federal Reserve held its benchmark interest rate steady in the 5.25–5.50% range for the third consecutive meeting after inflation data showed the consumer price index declining to 2.4% year-over-year, approaching the Fed's 2% target. Chair Jerome Powell noted that the labour market remains resilient with unemployment at 3.9% but signalled the committee needs several more months of data before cutting rates. Markets priced in a first 25-basis-point cut for September with 70% probability following the announcement. Treasury yields fell across the curve, with the 10-year dropping to 4.2%. Equity markets rallied 1.4% on the day. The Fed's dot plot showed a median projection of two cuts in 2025 and three in 2026, slightly more dovish than the previous quarter's projections."),

                (wsj,
                 "AI Chip Demand Reshapes Semiconductor Industry",
                 "Demand for AI accelerator chips has fundamentally restructured the global semiconductor supply chain. NVIDIA's H100 and H200 GPUs command lead times of 12 months or more, with spot-market prices reaching four times the list price. AMD's MI300X is gaining data centre traction as an alternative, offering higher memory bandwidth for inference workloads. Intel's Gaudi 3 is targeting the mid-tier training market. Meanwhile, hyperscalers including Google (TPU v5), Amazon (Trainium 2), and Microsoft (Maia 100) are deploying custom silicon to reduce dependence on NVIDIA and lower cost-per-token for inference. The IEA estimates AI data centres will consume 1,000 TWh of electricity annually by 2026, driving co-location demand near hydroelectric and nuclear power sources. TSMC's 3nm node is fully allocated to AI chips through 2025."),
            ]

            var offset: TimeInterval = 0
            for entry in entries {
                let page = await PageContent(
                    websiteID: entry.website.id,
                    url: "https://\(entry.website.domain)/\(entry.title.lowercased().replacingOccurrences(of: " ", with: "-").prefix(60))",
                    title: entry.title,
                    content: entry.content,
                    summary: String(entry.content.prefix(180)),
                    timestamp: Date().addingTimeInterval(-offset),
                    readingTime: Int.random(in: 4...12),
                    scrollDepth: Double.random(in: 0.6...1.0)
                )
                offset += 3600 * 2
                try savePage(page)
                try updateWebsiteStats(websiteID: entry.website.id)

                if let vector = await EmbeddingService.shared.generateEmbedding(for: entry.content) {
                    try saveEmbedding(pageID: page.id, vector: vector)
                }
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

