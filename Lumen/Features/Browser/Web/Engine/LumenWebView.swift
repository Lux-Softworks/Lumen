import UIKit
import WebKit

final class LumenWebView: WKWebView {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(lumenHighlight(_:)) {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }

    @objc func lumenHighlight(_ sender: Any?) {
        evaluateJavaScript(
            "window.__lumenCaptureHighlight && window.__lumenCaptureHighlight()",
            completionHandler: nil
        )
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        if #available(iOS 16.0, *) {
            let cmd = UICommand(
                title: "Highlight",
                action: #selector(lumenHighlight(_:))
            )
            builder.insertChild(
                UIMenu(options: .displayInline, children: [cmd]),
                atStartOfMenu: .standardEdit
            )
        }
        super.buildMenu(with: builder)
    }
}
