import Testing
import Foundation
@testable import Lumen

final class KnowledgeStorageWebsiteStatsTests {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    private let storage: KnowledgeStorage

    init() {
        storage = KnowledgeStorage(databasePath: directory.appendingPathComponent("knowledge.sqlite").path)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func savingTheSamePageTwiceCountsItOnce() async throws {
        _ = try await storage.save(url: "https://example.com/actors", title: "Actors", content: "actors isolate state")
        _ = try await storage.save(url: "https://example.com/actors", title: "Actors", content: "actors isolate state")

        let website = try #require(try await storage.fetchWebsite(domain: "example.com"))
        #expect(website.pageCount == 1)
    }

    @Test func savingTwoPagesCountsBothAndSumsTheirWords() async throws {
        _ = try await storage.save(url: "https://example.com/actors", title: "Actors", content: "actors isolate state")
        _ = try await storage.save(url: "https://example.com/tasks", title: "Tasks", content: "tasks run work")

        let website = try #require(try await storage.fetchWebsite(domain: "example.com"))
        #expect(website.pageCount == 2)
        #expect(website.totalWords == 6)
    }

    @Test func savingAPageReplacesAStaleCountWrittenBeforeIt() async throws {
        _ = try await storage.save(url: "https://example.com/actors", title: "Actors", content: "actors isolate state")
        var website = try #require(try await storage.fetchWebsite(domain: "example.com"))
        website.pageCount = 99
        website.totalWords = 999
        try await storage.updateWebsite(website)

        _ = try await storage.save(url: "https://example.com/actors", title: "Actors", content: "actors isolate state")

        let recounted = try #require(try await storage.fetchWebsite(domain: "example.com"))
        #expect(recounted.pageCount == 1)
        #expect(recounted.totalWords == 3)
    }
}
