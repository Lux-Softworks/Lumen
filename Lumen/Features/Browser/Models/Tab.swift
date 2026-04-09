import UIKit
import Combine

@MainActor
final class Tab: Identifiable, ObservableObject {
    let id: UUID
    let url: URL?
    let viewModel: BrowserViewModel
    @Published var snapshot: UIImage?
    @Published var title: String = "New Tab"
    @Published var themeColor: UIColor?

    private var titleCancellable: AnyCancellable?
    private var themeColorCancellable: AnyCancellable?

    init(id: UUID = UUID(), url: URL? = nil) {
        self.id = id
        self.url = url
        self.viewModel = BrowserViewModel(url: url)
        titleCancellable = viewModel.$pageTitle
            .receive(on: RunLoop.main)
            .sink { [weak self] newTitle in
                if !newTitle.isEmpty {
                    self?.title = newTitle
                }
            }
        themeColorCancellable = viewModel.$themeColor
            .receive(on: RunLoop.main)
            .sink { [weak self] color in
                self?.themeColor = color
            }
    }
}
