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
    var websiteViewModel: KnowledgeWebsiteViewModel? = nil

    var isLoading = false
    var error: Error? = nil

    func loadTopics() async {
        let wasEmpty = topics.isEmpty
        if wasEmpty { isLoading = true }
        defer { if wasEmpty { isLoading = false } }
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
            websiteViewModel = KnowledgeWebsiteViewModel(website: website, pages: pages)
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
        let removed = navigationPath.removeLast()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(320))
            guard let self else { return }
            switch removed {
            case .detail:
                self.selectedPage = nil
            case .pages:
                self.selectedWebsite = nil
                self.websiteViewModel = nil
            case .websites:
                self.selectedTopic = nil
                self.websites = []
            case .topics:
                break
            }
        }
    }

    func navigateToRoot() {
        navigationPath.removeAll()
        selectedTopic = nil
        selectedWebsite = nil
        selectedPage = nil
        websites = []
        pages = []
        websiteViewModel = nil
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

    func deleteTopic(_ topic: Topic) async {
        do {
            try await KnowledgeStorage.shared.deleteTopic(id: topic.id)
            topics.removeAll { $0.id == topic.id }
            if selectedTopic?.id == topic.id {
                navigateToRoot()
            }
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
