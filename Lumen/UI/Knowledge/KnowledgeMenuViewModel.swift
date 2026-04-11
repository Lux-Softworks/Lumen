import Foundation
import Observation

enum KnowledgeMenuLevel: Equatable, Hashable {
    case topics
    case websites(topic: Topic?)
    case pages(website: Website)
    case detail(page: PageContent)
}

@Observable
@MainActor
final class KnowledgeMenuViewModel {
    var navigationPath: [KnowledgeMenuLevel] = []

    var currentLevel: KnowledgeMenuLevel {
        navigationPath.last ?? .topics
    }

    var topics: [Topic] = []
    var websites: [Website] = []
    var pages: [PageContent] = []

    var selectedTopic: Topic? = nil
    var selectedWebsite: Website? = nil
    var selectedPage: PageContent? = nil

    var isLoading = false
    var error: Error? = nil

    func loadTopics() async {
        guard topics.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            topics = try await KnowledgeStorage.shared.fetchAllTopics()
        } catch {
            self.error = error
        }
    }

    func selectTopic(_ topic: Topic?) async {
        selectedTopic = topic
        selectedWebsite = nil
        selectedPage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            if let topic = topic {
                websites = try await KnowledgeStorage.shared.fetchWebsites(for: topic.id)
            } else {
                websites = try await KnowledgeStorage.shared.fetchAllWebsites()
            }
            navigationPath.append(.websites(topic: topic))
        } catch {
            self.error = error
        }
    }

    func selectWebsite(_ website: Website) async {
        selectedWebsite = website
        selectedPage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            pages = try await KnowledgeStorage.shared.fetchPages(websiteID: website.id)
            navigationPath.append(.pages(website: website))
        } catch {
            self.error = error
        }
    }

    func selectPage(_ page: PageContent) {
        selectedPage = page
        navigationPath.append(.detail(page: page))
    }

    func navigateBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()

        switch currentLevel {
        case .topics:
            selectedTopic = nil
            selectedWebsite = nil
            selectedPage = nil
            websites = []
            pages = []
        case .websites:
            selectedWebsite = nil
            selectedPage = nil
            pages = []
        case .pages:
            selectedPage = nil
        case .detail:
            break
        }
    }

    func navigateToRoot() {
        navigationPath.removeAll()
        selectedTopic = nil
        selectedWebsite = nil
        selectedPage = nil
        websites = []
        pages = []
    }

    func clearAllTopics() async {
        do {
            try await KnowledgeStorage.shared.deleteAllTopics()
            topics = []
            websites = []
            pages = []
            navigationPath = []
        } catch {
            self.error = error
        }
    }

    func seedData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await KnowledgeStorage.shared.nukeDatabase()

            self.topics = []
            self.websites = []

            try await KnowledgeStorage.shared.seedTestData()
            topics = try await KnowledgeStorage.shared.fetchAllTopics()
        } catch {
            self.error = error
        }
    }
}
