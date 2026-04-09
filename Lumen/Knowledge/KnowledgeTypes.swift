import Foundation

enum Intent: String, Sendable {
    case knowledge
    case action
    case context
}

enum LocalKnowledgeState: String, Sendable {
    case idle
    case thinking
    case executing
}

struct ProposedAction: Sendable, Identifiable {
    let id: UUID
    let type: ActionType
    let description: String
    let targetElementID: String?

    init(type: ActionType, description: String, targetElementID: String? = nil) {
        self.id = UUID()
        self.type = type
        self.description = description
        self.targetElementID = targetElementID
    }
}

enum ActionType: String, Sendable {
    case click
    case type
    case scroll
    case navigation
    case none
}
