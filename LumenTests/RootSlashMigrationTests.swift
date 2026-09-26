import Foundation
import SQLite3
import Testing
@testable import Lumen

struct RootSlashMigrationTests {
    @Test func rootPageWithQueryDropsItsSlash() {
        #expect(PageContent.normalizeURL("https://example.com/?q=lumen") == "example.com?q=lumen")
    }

    @Test func savedRootAddressesLoseTheirSlash() throws {
        let rows = try migratedURLs(from: ["example.com/", "example.com/?q=lumen", "example.com/path"])

        #expect(rows == ["example.com", "example.com/path", "example.com?q=lumen"])
    }

    @Test func savedRootAddressKeepsItsSlashWhenTheNewFormIsTaken() throws {
        let rows = try migratedURLs(from: ["example.com/", "example.com"])

        #expect(rows == ["example.com", "example.com/"])
    }

    private func migratedURLs(from urls: [String]) throws -> [String] {
        var db: OpaquePointer?
        #expect(sqlite3_open(":memory:", &db) == SQLITE_OK)
        defer { sqlite3_close(db) }

        let setup = [
            "CREATE TABLE pages (id INTEGER PRIMARY KEY, normalized_url TEXT NOT NULL UNIQUE)",
            "CREATE TABLE annotations (id INTEGER PRIMARY KEY, normalized_url TEXT NOT NULL)"
        ]
        let inserts = urls.map { "INSERT INTO pages (normalized_url) VALUES ('\($0)')" }
        let statements = setup + inserts + KnowledgeStorage.rootSlashMigrations

        for statement in statements {
            #expect(sqlite3_exec(db, statement, nil, nil, nil) == SQLITE_OK)
        }

        var query: OpaquePointer?
        defer { sqlite3_finalize(query) }
        sqlite3_prepare_v2(db, "SELECT normalized_url FROM pages ORDER BY normalized_url", -1, &query, nil)

        var rows: [String] = []
        while sqlite3_step(query) == SQLITE_ROW {
            rows.append(String(cString: sqlite3_column_text(query, 0)))
        }

        return rows
    }
}
