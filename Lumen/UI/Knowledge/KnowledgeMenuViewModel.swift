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

    var selectedTopic: Topic?
    var selectedWebsite: Website?
    var selectedPage: PageContent?
    var websiteViewModel: KnowledgeWebsiteViewModel?

    var isLoading = false
    var error: Error?

    func loadTopics() async {
        let wasEmpty = topics.isEmpty
        if wasEmpty { isLoading = true }
        defer { if wasEmpty { isLoading = false } }

        do {
            var loaded = try await KnowledgeStorage.shared.fetchAllTopics()
            let uncategorizedCount = try await KnowledgeStorage.shared.uncategorizedWebsiteCount()

            if uncategorizedCount > 0 {
                loaded.append(
                    Topic(
                        id: Topic.uncategorizedID,
                        name: Topic.uncategorizedName,
                        color: nil,
                        websiteCount: uncategorizedCount
                    )
                )
            }

            topics = loaded
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
                if topic.isUncategorized {
                    websites = try await KnowledgeStorage.shared.fetchUncategorizedWebsites()
                } else {
                    websites = try await KnowledgeStorage.shared.fetchWebsites(for: topic.id)
                }
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
        let depthAfterPop = navigationPath.count
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(320))
            guard let self, self.navigationPath.count <= depthAfterPop else { return }

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

    static func moveDestinations(for website: Website, among topics: [Topic]) -> [Topic] {
        let namedTopics = topics.filter { !$0.isUncategorized && $0.id != website.topicID }
        guard website.topicID != nil else { return namedTopics }

        return namedTopics + [Topic(id: Topic.uncategorizedID, name: Topic.uncategorizedName)]
    }

    func deleteWebsite(_ website: Website) async {
        do {
            try await KnowledgeStorage.shared.deleteWebsite(websiteID: website.id)
            try await KnowledgeStorage.shared.refreshTopicWebsiteCounts()
            websites.removeAll { $0.id == website.id }
            await loadTopics()
        } catch {
            self.error = error
        }
    }

    func deletePage(_ page: PageContent) async {
        do {
            try await KnowledgeStorage.shared.deletePage(pageID: page.id)
            pages.removeAll { $0.id == page.id }
            websiteViewModel?.removePage(id: page.id)

            if let refreshedWebsite = try await KnowledgeStorage.shared.fetchWebsite(id: page.websiteID),
                let index = websites.firstIndex(where: { $0.id == refreshedWebsite.id }) {
                websites[index] = refreshedWebsite
            }
        } catch {
            self.error = error
        }
    }

    func moveWebsite(_ website: Website, to topic: Topic) async {
        let destinationID = topic.isUncategorized ? nil : topic.id

        do {
            try await KnowledgeStorage.shared.moveWebsite(websiteID: website.id, toTopic: destinationID)

            if selectedTopic == nil {
                if let index = websites.firstIndex(where: { $0.id == website.id }) {
                    websites[index].topicID = destinationID
                }
            } else {
                websites.removeAll { $0.id == website.id }
            }

            await loadTopics()
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
