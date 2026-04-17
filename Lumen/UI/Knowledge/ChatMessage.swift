import Foundation

struct ChatMessage: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    enum Role: Equatable, Hashable, Sendable { case user, assistant }
    let role: Role
    let text: String
    let sources: [PageContent]

    init(role: Role, text: String, sources: [PageContent] = []) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.sources = sources
    }
}
