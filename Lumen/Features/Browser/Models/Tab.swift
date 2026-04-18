import UIKit
import Combine

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

    init(id: UUID = UUID(), url: URL? = nil, isIncognito: Bool = false) {
        self.id = id
        self.url = url
        self.isIncognito = isIncognito
        self.viewModel = BrowserViewModel(url: url, isIncognito: isIncognito)
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
    }
}
