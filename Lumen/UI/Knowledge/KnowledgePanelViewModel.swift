import Foundation
import Observation

enum KnowledgeTab {
    case ai
    case folder
}

@Observable
@MainActor
final class KnowledgePanelViewModel {
    var activeTab: KnowledgeTab = .ai
    let aiViewModel = KnowledgeAIViewModel()
    let menuViewModel = KnowledgeMenuViewModel()
}
