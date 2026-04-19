import Foundation

nonisolated enum SourceMatch: Equatable, Hashable, Sendable {
    case high
    case medium
    case low

    var label: String {
        switch self {
        case .high: return "Well grounded in sources"
        case .medium: return "Partially grounded"
        case .low: return "Weakly grounded"
        }
    }

    static func classify(topScore: Double, resultCount: Int = 0, ftsHits: Int = 0) -> SourceMatch {
        let semantic = min(max(topScore, 0) * 2.5, 1.0)
        let keyword = min(Double(ftsHits) * 0.25, 0.5)
        let breadth: Double = resultCount >= 3 ? 0.2 : (resultCount >= 1 ? 0.1 : 0)
        let confidence = semantic + keyword + breadth

        if confidence >= 0.85 { return .high }
        if confidence >= 0.35 { return .medium }
        return .low
    }
}

struct ChatMessage: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    enum Role: Equatable, Hashable, Sendable { case user, assistant }
    let role: Role
    var text: String
    var sources: [PageContent]
    var sourceMatch: SourceMatch?
    var isStreaming: Bool

    init(
        role: Role,
        text: String,
        sources: [PageContent] = [],
        sourceMatch: SourceMatch? = nil,
        isStreaming: Bool = false
    ) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.sources = sources
        self.sourceMatch = sourceMatch
        self.isStreaming = isStreaming
    }
}
