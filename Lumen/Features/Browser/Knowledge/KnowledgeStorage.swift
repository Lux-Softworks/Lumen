import SQLite3
import Foundation

actor KnowledgeStorage {
    static let shared = KnowledgeStorage()

    private var db: OpaquePointer?
    private let dbPath: String

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

        try createTables()
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
            favicon TEXT,
            topic_id TEXT,
            page_count INTEGER DEFAULT 0,
            total_words INTEGER DEFAULT 0,
            first_visit INTEGER NOT NULL,
            last_visit INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
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

        try execute(createTopicsTable)
        try execute(createWebsitesTable)
        try execute(createPagesTable)
        try execute(createIndexes)
    }

    func save(
        url: String,
        title: String?,
        content: String,
        author: String? = nil,
        description: String? = nil,
        readingTime: Int? = nil,
        scrollDepth: Double? = nil
    ) throws -> String {
        try initialize()

        let domain = PageContent.extractDomain(from: url)
        let websiteID: String
        if let existingWebsite = try fetchWebsite(domain: domain) {
            websiteID = existingWebsite.id
        } else {
            websiteID = try createWebsite(domain: domain, displayName: domain)
        }

        let page = PageContent(
            websiteID: websiteID,
            url: url,
            title: title,
            content: content,
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

        sqlite3_bind_text(statement, 1, page.id, -1, nil)
        sqlite3_bind_text(statement, 2, page.websiteID, -1, nil)
        sqlite3_bind_text(statement, 3, page.url, -1, nil)
        sqlite3_bind_text(statement, 4, page.normalizedURL, -1, nil)
        sqlite3_bind_text(statement, 5, page.domain, -1, nil)
        sqlite3_bind_text(statement, 6, page.title, -1, nil)
        sqlite3_bind_text(statement, 7, page.content, -1, nil)
        sqlite3_bind_text(statement, 8, page.summary, -1, nil)
        sqlite3_bind_int64(statement, 9, Int64(page.timestamp.timeIntervalSince1970))
        sqlite3_bind_text(statement, 10, page.author, -1, nil)
        sqlite3_bind_text(statement, 11, page.description, -1, nil)

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

    private func createWebsite(domain: String, displayName: String) throws -> String {
        let website = Website(domain: domain, displayName: displayName)

        let sql = """
        INSERT INTO websites (
            id, domain, display_name, favicon, topic_id, page_count, total_words,
            first_visit, last_visit, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        try execute(sql, bindValues: { statement in
            sqlite3_bind_text(statement, 1, website.id, -1, nil)
            sqlite3_bind_text(statement, 2, website.domain, -1, nil)
            sqlite3_bind_text(statement, 3, website.displayName, -1, nil)
            sqlite3_bind_null(statement, 4)
            sqlite3_bind_null(statement, 5)
            sqlite3_bind_int(statement, 6, Int32(website.pageCount))
            sqlite3_bind_int(statement, 7, Int32(website.totalWords))
            sqlite3_bind_int64(statement, 8, Int64(website.firstVisit.timeIntervalSince1970))
            sqlite3_bind_int64(statement, 9, Int64(website.lastVisit.timeIntervalSince1970))
            sqlite3_bind_int64(statement, 10, Int64(website.createdAt.timeIntervalSince1970))
        })

        return website.id
    }

    func fetchWebsite(domain: String) throws -> Website? {
        try initialize()

        let sql = "SELECT * FROM websites WHERE domain = ?"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, domain, -1, nil)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return try parseWebsite(from: statement)
    }

    func fetchAllWebsites() throws -> [Website] {
        try initialize()

        let sql = "SELECT * FROM websites ORDER BY last_visit DESC"
        return try queryWebsites(sql: sql)
    }

    func fetchWebsites(topicID: String) throws -> [Website] {
        try initialize()

        let sql = "SELECT * FROM websites WHERE topic_id = ? ORDER BY last_visit DESC"
        return try queryWebsites(sql: sql, bindValues: { statement in
            sqlite3_bind_text(statement, 1, topicID, -1, nil)
        })
    }

    private func updateWebsiteStats(websiteID: String) throws {
        let sql = """
        UPDATE websites SET
            page_count = (SELECT COUNT(*) FROM pages WHERE website_id = ?),
            total_words = (SELECT COALESCE(SUM(word_count), 0) FROM pages WHERE website_id = ?),
            last_visit = (SELECT MAX(timestamp) FROM pages WHERE website_id = ?)
        WHERE id = ?
        """

        try execute(sql, bindValues: { statement in
            sqlite3_bind_text(statement, 1, websiteID, -1, nil)
            sqlite3_bind_text(statement, 2, websiteID, -1, nil)
            sqlite3_bind_text(statement, 3, websiteID, -1, nil)
            sqlite3_bind_text(statement, 4, websiteID, -1, nil)
        })
    }

    func deleteWebsite(websiteID: String) throws {
        try initialize()

        let sql = "DELETE FROM websites WHERE id = ?"
        try execute(sql, bindValues: { statement in
            sqlite3_bind_text(statement, 1, websiteID, -1, nil)
        })

    }

    func fetchPages(websiteID: String) throws -> [PageContent] {
        try initialize()

        let sql = "SELECT * FROM pages WHERE website_id = ? ORDER BY timestamp DESC"
        return try queryPages(sql: sql, bindValues: { statement in
            sqlite3_bind_text(statement, 1, websiteID, -1, nil)
        })
    }

    func fetchPage(pageID: String) throws -> PageContent? {
        try initialize()

        let sql = "SELECT * FROM pages WHERE id = ?"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_text(statement, 1, pageID, -1, nil)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return try parsePage(from: statement)
    }

    func searchPages(query: String, limit: Int = 50) throws -> [PageContent] {
        try initialize()

        let searchPattern = "%\(query)%"
        let sql = """
        SELECT * FROM pages
        WHERE title LIKE ? OR content LIKE ?
        ORDER BY timestamp DESC
        LIMIT ?
        """

        return try queryPages(sql: sql, bindValues: { statement in
            sqlite3_bind_text(statement, 1, searchPattern, -1, nil)
            sqlite3_bind_text(statement, 2, searchPattern, -1, nil)
            sqlite3_bind_int(statement, 3, Int32(limit))
        })
    }

    func deletePage(pageID: String) throws {
        try initialize()

        guard let page = try fetchPage(pageID: pageID) else { return }

        let sql = "DELETE FROM pages WHERE id = ?"
        try execute(sql, bindValues: { statement in
            sqlite3_bind_text(statement, 1, pageID, -1, nil)
        })

        try updateWebsiteStats(websiteID: page.websiteID)
    }

    func createTopic(name: String, color: String? = nil) throws -> String {
        try initialize()

        let topic = Topic(name: name, color: color)

        let sql = """
        INSERT INTO topics (id, name, color, website_count, created_at)
        VALUES (?, ?, ?, ?, ?)
        """

        try execute(sql, bindValues: { statement in
            sqlite3_bind_text(statement, 1, topic.id, -1, nil)
            sqlite3_bind_text(statement, 2, topic.name, -1, nil)
            sqlite3_bind_text(statement, 3, topic.color, -1, nil)
            sqlite3_bind_int(statement, 4, Int32(topic.websiteCount))
            sqlite3_bind_int64(statement, 5, Int64(topic.createdAt.timeIntervalSince1970))
        })

        return topic.id
    }

    func fetchAllTopics() throws -> [Topic] {
        try initialize()

        let sql = "SELECT * FROM topics ORDER BY name"
        return try queryTopics(sql: sql)
    }

    func assignWebsiteToTopic(websiteID: String, topicID: String?) throws {
        try initialize()

        let sql = "UPDATE websites SET topic_id = ? WHERE id = ?"
        try execute(sql, bindValues: { statement in
            if let topicID = topicID {
                sqlite3_bind_text(statement, 1, topicID, -1, nil)
            } else {
                sqlite3_bind_null(statement, 1)
            }
            sqlite3_bind_text(statement, 2, websiteID, -1, nil)
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
            sqlite3_bind_text(statement, 1, topicID, -1, nil)
        })
    }

    func getStats() throws -> StorageStats {
        try initialize()

        var totalWebsites = 0
        var totalPages = 0
        var totalWords = 0
        var totalTopics = 0
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

        let topWebsites = try fetchAllWebsites().prefix(10).map { ($0.domain, $0.pageCount) }

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

    private func queryPages(sql: String, bindValues: ((OpaquePointer?) -> Void)? = nil) throws -> [PageContent] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        bindValues?(statement)

        var results: [PageContent] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(try parsePage(from: statement))
        }

        return results
    }

    private func queryWebsites(sql: String, bindValues: ((OpaquePointer?) -> Void)? = nil) throws -> [Website] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        bindValues?(statement)

        var results: [Website] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(try parseWebsite(from: statement))
        }

        return results
    }

    private func queryTopics(sql: String, bindValues: ((OpaquePointer?) -> Void)? = nil) throws -> [Topic] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        bindValues?(statement)

        var results: [Topic] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(try parseTopic(from: statement))
        }

        return results
    }

    private func execute(_ sql: String, bindValues: ((OpaquePointer?) -> Void)? = nil) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.failedToPrepare(String(cString: sqlite3_errmsg(db)))
        }

        bindValues?(statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StorageError.failedToExecute(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func parsePage(from statement: OpaquePointer?) throws -> PageContent {
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

        let wordCount = Int(sqlite3_column_int(statement, 13))
        let createdAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 14)))

        return PageContent(
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

    private func parseWebsite(from statement: OpaquePointer?) throws -> Website {
        let id = String(cString: sqlite3_column_text(statement, 0))
        let domain = String(cString: sqlite3_column_text(statement, 1))
        let displayName = String(cString: sqlite3_column_text(statement, 2))

        let favicon = sqlite3_column_type(statement, 3) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(statement, 3)) : nil

        let topicID = sqlite3_column_type(statement, 4) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(statement, 4)) : nil

        let pageCount = Int(sqlite3_column_int(statement, 5))
        let totalWords = Int(sqlite3_column_int(statement, 6))
        let firstVisit = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 7)))
        let lastVisit = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 8)))
        let createdAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 9)))

        return Website(
            id: id,
            domain: domain,
            displayName: displayName,
            favicon: favicon,
            topicID: topicID,
            pageCount: pageCount,
            totalWords: totalWords,
            firstVisit: firstVisit,
            lastVisit: lastVisit,
            createdAt: createdAt
        )
    }

    private func parseTopic(from statement: OpaquePointer?) throws -> Topic {
        let id = String(cString: sqlite3_column_text(statement, 0))
        let name = String(cString: sqlite3_column_text(statement, 1))

        let color = sqlite3_column_type(statement, 2) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(statement, 2)) : nil

        let websiteCount = Int(sqlite3_column_int(statement, 3))
        let createdAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 4)))

        return Topic(
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
