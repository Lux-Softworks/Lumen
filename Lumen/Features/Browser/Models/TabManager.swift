import Combine
import UIKit
import WebKit

@MainActor
final class TabManager: ObservableObject {
    @Published private(set) var tabs: [Tab] = [] {
        didSet { rebuildIndex() }
    }
    @Published private(set) var activeTabId: UUID

    private var indexById: [UUID: Int] = [:]

    var activeTab: Tab? {
        if let i = indexById[activeTabId], i < tabs.count {
            return tabs[i]
        }
        return tabs.first
    }

    private var activeViewModelCancellable: AnyCancellable?

    init(createDefaultTab: Bool = true) {
        if createDefaultTab {
            let defaultTab = Tab()
            self.tabs = [defaultTab]
            self.activeTabId = defaultTab.id
            wirePopupHandler(for: defaultTab)
        } else {
            self.tabs = []
            self.activeTabId = UUID()
        }

        rebuildIndex()

        if createDefaultTab {
            observeActiveViewModel()
        }
    }

    private func rebuildIndex() {
        indexById.removeAll(keepingCapacity: true)
        for (i, t) in tabs.enumerated() { indexById[t.id] = i }
    }

    func newTab(incognito: Bool = false) {
        let tab = Tab(isIncognito: incognito)
        wirePopupHandler(for: tab)
        tabs.append(tab)
        activeTabId = tab.id
        observeActiveViewModel()
    }

    func adoptPopup(config: WKWebViewConfiguration, parentIsIncognito: Bool) -> WKWebView? {
        let policy = BrowserSettings.shared.policy(for: nil)
        let webView = BrowserEngine.makePopupWebView(
            parentConfig: config,
            policy: policy,
            isIncognito: parentIsIncognito
        )
        let tab = Tab(preattached: webView, isIncognito: parentIsIncognito)
        wirePopupHandler(for: tab)
        tabs.append(tab)
        activeTabId = tab.id
        observeActiveViewModel()
        return webView
    }

    private func wirePopupHandler(for tab: Tab) {
        tab.viewModel.onRequestPopup = { [weak self, weak tab] config, _ in
            guard let self, let tab else { return nil }
            return self.adoptPopup(config: config, parentIsIncognito: tab.isIncognito)
        }
        tab.viewModel.onWindowClose = { [weak self, weak tab] in
            guard let self, let tab else { return }
            self.closeTab(id: tab.id)
        }
    }

    func newIncognitoTab() {
        newTab(incognito: true)
    }

    func openExternalURL(_ url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else { return }

        if let active = activeTab, !active.isIncognito {
            active.viewModel.loadURL(url)
            return
        }

        let tab = Tab(url: url)
        wirePopupHandler(for: tab)
        tabs.append(tab)
        activeTabId = tab.id
        observeActiveViewModel()
        tab.viewModel.loadURL(url)
    }

    func switchTab(id: UUID) {
        guard indexById[id] != nil else { return }
        activeTabId = id
        observeActiveViewModel()
    }

    func moveActiveTabToTop() {
        guard let index = indexById[activeTabId] else { return }
        let tab = tabs.remove(at: index)
        tabs.append(tab)
    }

    var tabBelowActive: Tab? {
        guard tabs.count > 1 else { return nil }
        guard let activeIndex = indexById[activeTabId] else { return nil }
        let belowIndex = activeIndex == 0 ? tabs.count - 1 : activeIndex - 1
        return tabs[belowIndex]
    }

    func closeTab(id: UUID) {
        guard let index = indexById[id] else { return }

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
            if indexById[activeTabId] == nil {
                activeTabId = tabs[max(0, min(index, tabs.count - 1))].id
            }
            observeActiveViewModel()
        }
    }

    func updateSnapshot(_ snapshot: UIImage, for id: UUID) {
        if let i = indexById[id] {
            tabs[i].snapshot = snapshot
        }
    }

    private func observeActiveViewModel() {
        guard let activeTab else { return }
        activeViewModelCancellable = activeTab.viewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

}
