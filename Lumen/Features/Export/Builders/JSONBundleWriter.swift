import Foundation

nonisolated enum JSONBundleWriter {
    static let schemaVersion = 1

    struct Bundle: Encodable {
        let schemaVersion: Int
        let exportedAt: String?
        let scope: ScopeDescriptor
        let topics: [TopicOut]
        let websites: [WebsiteOut]
        let pages: [PageOut]
        let annotations: [AnnotationOut]
        let embeddings: [ExportPayload.PageEmbedding]
    }

    struct ScopeDescriptor: Encodable {
        let type: String
        let id: String?
        let dateRange: DateRange?
        struct DateRange: Encodable { let start: String; let end: String }
    }

    struct TopicOut: Encodable {
        let id, name: String
        let color: String?
        let websiteCount: Int
        let createdAt: String?
    }

    struct WebsiteOut: Encodable {
        let id, domain, displayName: String
        let summary: String?
        let topicID: String?
        let pageCount, totalWords: Int
        let firstVisit, lastVisit: String?
    }

    struct PageOut: Encodable {
        let id, websiteID, url, title, content: String
        let summary: String?
        let timestamp: String?
        let author: String?
        let wordCount: Int
        let readingTime: Int?
    }

    struct AnnotationOut: Encodable {
        let id: String
        let pageID: String?
        let url: String
        let text, prefix, suffix: String
        let createdAt: String?
    }

    static func write(
        payload: ExportPayload,
        scope: ExportCoordinator.Request.Scope,
        toggles: ExportCoordinator.Request.Toggles,
        to url: URL
    ) throws {
        let bundle = makeBundle(payload: payload, scope: scope, toggles: toggles)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(bundle)
        try data.write(to: url, options: .atomic)
    }

    private static func makeBundle(
        payload: ExportPayload,
        scope: ExportCoordinator.Request.Scope,
        toggles: ExportCoordinator.Request.Toggles
    ) -> Bundle {
        let includeTS = toggles.includeTimestamps
        let includeAI = toggles.includeAISummaries

        let topics = payload.topics.map {
            TopicOut(
                id: $0.id,
                name: $0.name,
                color: $0.color,
                websiteCount: $0.websiteCount,
                createdAt: includeTS ? iso($0.createdAt) : nil
            )
        }

        let websites = payload.websites.map {
            WebsiteOut(
                id: $0.id,
                domain: $0.domain,
                displayName: $0.displayName,
                summary: includeAI ? $0.summary : nil,
                topicID: $0.topicID,
                pageCount: $0.pageCount,
                totalWords: $0.totalWords,
                firstVisit: includeTS ? iso($0.firstVisit) : nil,
                lastVisit: includeTS ? iso($0.lastVisit) : nil
            )
        }

        let pages = payload.pages.map {
            PageOut(
                id: $0.id,
                websiteID: $0.websiteID,
                url: $0.url,
                title: $0.title ?? "",
                content: $0.content,
                summary: includeAI ? $0.summary : nil,
                timestamp: includeTS ? iso($0.timestamp) : nil,
                author: $0.author,
                wordCount: $0.wordCount,
                readingTime: $0.readingTime
            )
        }

        let annotations: [AnnotationOut] = toggles.includeAnnotations
            ? payload.annotations.map {
                AnnotationOut(
                    id: $0.id,
                    pageID: $0.pageID,
                    url: $0.url,
                    text: $0.text,
                    prefix: $0.prefix,
                    suffix: $0.suffix,
                    createdAt: includeTS ? iso($0.createdAt) : nil
                )
            }
            : []

        let embeddings = toggles.includeEmbeddings ? payload.embeddings : []

        return Bundle(
            schemaVersion: schemaVersion,
            exportedAt: includeTS ? iso(Date()) : nil,
            scope: descriptor(for: scope),
            topics: topics,
            websites: websites,
            pages: pages,
            annotations: annotations,
            embeddings: embeddings
        )
    }

    private static func descriptor(for scope: ExportCoordinator.Request.Scope) -> ScopeDescriptor {
        switch scope {
        case .wholeBase:
            return ScopeDescriptor(type: "wholeBase", id: nil, dateRange: nil)
        case .topic(let id):
            return ScopeDescriptor(type: "topic", id: id, dateRange: nil)
        case .site(let id):
            return ScopeDescriptor(type: "site", id: id, dateRange: nil)
        case .page(let id):
            return ScopeDescriptor(type: "page", id: id, dateRange: nil)
        case .dateRange(let start, let end):
            return ScopeDescriptor(
                type: "dateRange",
                id: nil,
                dateRange: .init(start: iso(start), end: iso(end))
            )
        }
    }

    private static func iso(_ date: Date) -> String {
        DateFormatters.iso8601.string(from: date)
    }
}
