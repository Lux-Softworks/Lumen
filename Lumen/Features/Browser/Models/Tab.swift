import UIKit
import Combine
import WebKit

@MainActor
final class Tab: Identifiable, ObservableObject {
    let id: UUID
    let url: URL?
    let isIncognito: Bool
    let viewModel: BrowserViewModel
    @Published var snapshot: UIImage?
    @Published var title: String = "New Tab"
    @Published var themeColor: UIColor?

    private var titleCancellable: AnyCancellable?
    private var themeColorCancellable: AnyCancellable?
    private var faviconPrefetchCancellable: AnyCancellable?

    init(id: UUID = UUID(), url: URL? = nil, isIncognito: Bool = false) {
        self.id = id
        self.url = url
        self.isIncognito = isIncognito
        self.viewModel = BrowserViewModel(url: url, isIncognito: isIncognito)
        bindPublishers()
    }

    init(id: UUID = UUID(), preattached webView: WKWebView, isIncognito: Bool) {
        self.id = id
        self.url = nil
        self.isIncognito = isIncognito
        self.viewModel = BrowserViewModel(url: nil, isIncognito: isIncognito)
        self.viewModel.attachWebView(webView)
        bindPublishers()
    }

    private func bindPublishers() {
        titleCancellable = viewModel.$pageTitle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTitle in
                self?.title = newTitle.isEmpty ? "New Tab" : newTitle
            }
        themeColorCancellable = viewModel.$themeColor
            .receive(on: DispatchQueue.main)
            .sink { [weak self] color in
                self?.themeColor = color
            }
        faviconPrefetchCancellable = viewModel.$currentURL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                guard let self, !self.isIncognito, let url else { return }
                FaviconService.prefetchFavicon(for: url)
            }
    }
}
