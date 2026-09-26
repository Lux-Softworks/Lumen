import SQLite3
import Testing
@testable import Lumen

struct WebsiteMoveTests {
    @Test func movedWebsiteStaysWhenOneNewPageVotesForItsOldTopic() {
        let db = openPages()
        defer { sqlite3_close(db) }

        run(KnowledgeStorage.moveWebsitePagesSQL, binding: ["t_film", "site"], in: db)
        sqlite3_exec(db, "INSERT INTO pages VALUES ('p4', 'site', 't_tech')", nil, nil, nil)

        let winner = TopicVote.majority(counts: topicCounts(forWebsite: "site", in: db), current: "t_film")

        #expect(winner == "t_film")
    }

    @Test func movingAWebsiteLeavesOtherWebsitesPagesAlone() {
        let db = openPages()
        defer { sqlite3_close(db) }

        run(KnowledgeStorage.moveWebsitePagesSQL, binding: ["t_film", "site"], in: db)

        #expect(topicCounts(forWebsite: "other", in: db).map(\.topicID) == ["t_tech"])
    }

    @Test func movingAWebsiteToUncategorizedClearsItsPageTopics() {
        let db = openPages()
        defer { sqlite3_close(db) }

        run(KnowledgeStorage.moveWebsitePagesSQL, binding: [nil, "site"], in: db)

        #expect(topicCounts(forWebsite: "site", in: db).isEmpty)
    }

    private func openPages() -> OpaquePointer? {
        var db: OpaquePointer?
        sqlite3_open(":memory:", &db)
        sqlite3_exec(db, "CREATE TABLE pages (id TEXT PRIMARY KEY, website_id TEXT NOT NULL, topic_id TEXT)", nil, nil, nil)
        sqlite3_exec(
            db,
            "INSERT INTO pages VALUES ('p1', 'site', 't_tech'), ('p2', 'site', 't_tech'), ('p3', 'other', 't_tech')",
            nil, nil, nil
        )

        return db
    }

    private func run(_ sql: String, binding values: [String?], in db: OpaquePointer?) {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        sqlite3_prepare_v2(db, sql, -1, &statement, nil)

        for (offset, value) in values.enumerated() {
            if let value {
                sqlite3_bind_text(statement, Int32(offset + 1), value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else {
                sqlite3_bind_null(statement, Int32(offset + 1))
            }
        }

        sqlite3_step(statement)
    }

    private func topicCounts(forWebsite websiteID: String, in db: OpaquePointer?) -> [(topicID: String, count: Int)] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        sqlite3_prepare_v2(
            db,
            "SELECT topic_id, COUNT(*) FROM pages WHERE website_id = '\(websiteID)' AND topic_id IS NOT NULL GROUP BY topic_id",
            -1, &statement, nil
        )

        var counts: [(topicID: String, count: Int)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            counts.append((String(cString: sqlite3_column_text(statement, 0)), Int(sqlite3_column_int(statement, 1))))
        }

        return counts
    }
}
