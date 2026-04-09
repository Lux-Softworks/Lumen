import Foundation
import WebKit

final class FirstPaintHandler: NSObject, WKScriptMessageHandler {
    private weak var viewModel: BrowserViewModel?

    init(viewModel: BrowserViewModel) {
        self.viewModel = viewModel
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "firstPaint" else { return }

        Task { @MainActor in
            viewModel?.firstPaintToken += 1
        }
    }
}
