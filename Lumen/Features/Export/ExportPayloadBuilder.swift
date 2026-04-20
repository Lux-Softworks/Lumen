import Foundation

struct ExportPayload: Sendable {
    let topics: [Topic]
    let websites: [Website]
    let pages: [PageContent]
    let annotations: [Annotation]
    let embeddings: [PageEmbedding]

    struct PageEmbedding: Sendable, Codable {
        let pageID: String
        let vector: [Double]
    }
}

enum ExportPayloadBuilder {
    static func build(
        scope: ExportCoordinator.Request.Scope,
        includeEmbeddings: Bool,
        storage: KnowledgeStorage = .shared
    ) async throws -> ExportPayload {
        switch scope {
        case .wholeBase:
            return try await assembleWholeBase(storage: storage, includeEmbeddings: includeEmbeddings)
        case .topic(let id):
            return try await assembleTopic(topicID: id, storage: storage, includeEmbeddings: includeEmbeddings)
        case .site(let id):
            return try await assembleSite(websiteID: id, storage: storage, includeEmbeddings: includeEmbeddings)
        case .page(let id):
            return try await assemblePage(pageID: id, storage: storage, includeEmbeddings: includeEmbeddings)
        case .dateRange(let start, let end):
            return try await assembleDateRange(start: start, end: end, storage: storage, includeEmbeddings: includeEmbeddings)
        }
    }

    private static func assembleWholeBase(storage: KnowledgeStorage, includeEmbeddings: Bool) async throws -> ExportPayload {
        let pages = try await storage.fetchAllPages()
        let websites = try await storage.fetchAllWebsites()
        let topics = try await storage.fetchAllTopics()
        let annotations = try await aggregateAnnotations(for: pages, storage: storage)
        let embeddings = includeEmbeddings ? try await fetchEmbeddings(for: pages, storage: storage) : []

        return ExportPayload(
            topics: topics,
            websites: websites,
            pages: pages,
            annotations: annotations,
            embeddings: embeddings
        )
    }

    private static func assembleTopic(topicID: String, storage: KnowledgeStorage, includeEmbeddings: Bool) async throws -> ExportPayload {
        let websites = try await storage.fetchWebsites(for: topicID)
        let pages = try await aggregatePages(for: websites, storage: storage)
        let topicsAll = try await storage.fetchAllTopics()
        let topics = topicsAll.filter { $0.id == topicID }
        let annotations = try await aggregateAnnotations(for: pages, storage: storage)
        let embeddings = includeEmbeddings ? try await fetchEmbeddings(for: pages, storage: storage) : []

        return ExportPayload(
            topics: topics,
            websites: websites,
            pages: pages,
            annotations: annotations,
            embeddings: embeddings
        )
    }

    private static func assembleSite(websiteID: String, storage: KnowledgeStorage, includeEmbeddings: Bool) async throws -> ExportPayload {
        guard let website = try await storage.fetchWebsite(id: websiteID) else {
            return ExportPayload(topics: [], websites: [], pages: [], annotations: [], embeddings: [])
        }
        let pages = try await storage.fetchPages(websiteID: websiteID)
        let topics = try await resolveTopics(for: [website], storage: storage)
        let annotations = try await aggregateAnnotations(for: pages, storage: storage)
        let embeddings = includeEmbeddings ? try await fetchEmbeddings(for: pages, storage: storage) : []

        return ExportPayload(
            topics: topics,
            websites: [website],
            pages: pages,
            annotations: annotations,
            embeddings: embeddings
        )
    }

    private static func assemblePage(pageID: String, storage: KnowledgeStorage, includeEmbeddings: Bool) async throws -> ExportPayload {
        guard let page = try await storage.fetchPage(pageID: pageID) else {
            return ExportPayload(topics: [], websites: [], pages: [], annotations: [], embeddings: [])
        }
        let website = try await storage.fetchWebsite(id: page.websiteID)
        let websites = website.map { [$0] } ?? []
        let topics = try await resolveTopics(for: websites, storage: storage)
        let annotations = try await storage.fetchAnnotations(pageID: pageID)
        let embeddings = includeEmbeddings ? try await storage.fetchPageEmbeddings(pageIDs: [pageID]).map {
            ExportPayload.PageEmbedding(pageID: $0.pageID, vector: $0.vector)
        } : []

        return ExportPayload(
            topics: topics,
            websites: websites,
            pages: [page],
            annotations: annotations,
            embeddings: embeddings
        )
    }

    private static func assembleDateRange(start: Date, end: Date, storage: KnowledgeStorage, includeEmbeddings: Bool) async throws -> ExportPayload {
        let pages = try await storage.fetchPagesInDateRange(start: start, end: end)
        let websiteIDs = Set(pages.map { $0.websiteID })
        let allWebsites = try await storage.fetchAllWebsites()
        let websites = allWebsites.filter { websiteIDs.contains($0.id) }
        let topics = try await resolveTopics(for: websites, storage: storage)
        let annotations = try await aggregateAnnotations(for: pages, storage: storage)
        let embeddings = includeEmbeddings ? try await fetchEmbeddings(for: pages, storage: storage) : []

        return ExportPayload(
            topics: topics,
            websites: websites,
            pages: pages,
            annotations: annotations,
            embeddings: embeddings
        )
    }

    private static func aggregatePages(for websites: [Website], storage: KnowledgeStorage) async throws -> [PageContent] {
        guard !websites.isEmpty else { return [] }
        return try await storage.fetchPages(websiteIDs: websites.map { $0.id })
    }

    private static func aggregateAnnotations(for pages: [PageContent], storage: KnowledgeStorage) async throws -> [Annotation] {
        guard !pages.isEmpty else { return [] }
        return try await storage.fetchAnnotations(pageIDs: pages.map { $0.id })
    }

    private static func resolveTopics(for websites: [Website], storage: KnowledgeStorage) async throws -> [Topic] {
        let topicIDs = Set(websites.compactMap { $0.topicID })
        guard !topicIDs.isEmpty else { return [] }
        let allTopics = try await storage.fetchAllTopics()

        return allTopics.filter { topicIDs.contains($0.id) }
    }

    private static func fetchEmbeddings(for pages: [PageContent], storage: KnowledgeStorage) async throws -> [ExportPayload.PageEmbedding] {
        let ids = pages.map { $0.id }
        let rows = try await storage.fetchPageEmbeddings(pageIDs: ids)

        return rows.map { ExportPayload.PageEmbedding(pageID: $0.pageID, vector: $0.vector) }
    }
}
