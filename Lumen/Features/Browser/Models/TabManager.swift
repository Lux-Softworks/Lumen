import Combine
import UIKit

@MainActor
final class TabManager: ObservableObject {
    @Published private(set) var tabs: [Tab] = []
    @Published private(set) var activeTabId: UUID

    var activeTab: Tab? {
        guard !tabs.isEmpty else { return nil }
        return tabs.first { $0.id == activeTabId } ?? tabs.first
    }

    private var activeViewModelCancellable: AnyCancellable?

    init(createDefaultTab: Bool = true) {
        if createDefaultTab {
            let defaultTab = Tab()
            self.tabs = [defaultTab]
            self.activeTabId = defaultTab.id
        } else {
            self.tabs = []
            self.activeTabId = UUID()
        }

        if createDefaultTab {
            observeActiveViewModel()
        }
    }

    func newTab(incognito: Bool = false) {
        let tab = Tab(isIncognito: incognito)
        tabs.append(tab)
        activeTabId = tab.id
        observeActiveViewModel()
    }

    func newIncognitoTab() {
        newTab(incognito: true)
    }

    func switchTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabId = id
        observeActiveViewModel()
    }

    func moveActiveTabToTop() {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabId }) else { return }
        let tab = tabs.remove(at: index)
        tabs.append(tab)
    }

    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        if activeTabId == id && tabs.count > 1 {
            let newIndex = (index > 0) ? index - 1 : (index + 1 < tabs.count ? index + 1 : 0)
            if newIndex < tabs.count {
                activeTabId = tabs[newIndex].id
            }
        }

        tabs.remove(at: index)

        if tabs.isEmpty {
            activeTabId = UUID()
            activeViewModelCancellable = nil
        } else {
            if !tabs.contains(where: { $0.id == activeTabId }) {
                activeTabId = tabs[max(0, min(index, tabs.count - 1))].id
            }
            observeActiveViewModel()
        }
    }

    func updateSnapshot(_ snapshot: UIImage, for id: UUID) {
        tabs.first { $0.id == id }?.snapshot = snapshot
    }

    private func observeActiveViewModel() {
        guard let activeTab else { return }
        activeViewModelCancellable = activeTab.viewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

}
