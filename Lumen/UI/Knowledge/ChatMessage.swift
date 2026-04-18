import Foundation

enum SourceMatch: Equatable, Hashable, Sendable {
    case high
    case medium
    case low

    var label: String {
        switch self {
        case .high: return "Strong source match"
        case .medium: return "Partial source match"
        case .low: return "Weak source match"
        }
    }

    static func classify(topScore: Double) -> SourceMatch {
        if topScore >= 0.30 { return .high }
        if topScore >= 0.12 { return .medium }
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
