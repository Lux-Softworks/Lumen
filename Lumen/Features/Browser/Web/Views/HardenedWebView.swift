import SwiftUI
import UIKit
import WebKit

struct HardenedWebView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    @StateObject private var settings = BrowserSettings.shared
    var bottomInset: CGFloat = 0
    var topBarOffset: CGFloat = 0
    var statusBarInset: CGFloat = 0

    var policy: PrivacyPolicy {
        settings.policy(for: viewModel.currentURL)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: HardenedWebView
        var hasAttached = false
        var statusBarTintView: UIView?
        var lastToolbarHeight: Int = 0
        var lastPageReadyToken: Int = -1

        init(_ parent: HardenedWebView) {
            self.parent = parent
        }

        func userContentController(
            _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            guard message.name == "insetProvider", let webView = message.webView else { return }
            parent.pushCurrentInsets(webView: webView, context: nil)
        }

        func installStatusBarTint(above webView: WKWebView) {
            guard statusBarTintView == nil else { return }

            let tint = UIView()
            tint.translatesAutoresizingMaskIntoConstraints = false
            tint.backgroundColor = .clear
            tint.isUserInteractionEnabled = false

            DispatchQueue.main.async {
                guard let superview = webView.superview else { return }
                superview.addSubview(tint)

                NSLayoutConstraint.activate([
                    tint.topAnchor.constraint(equalTo: superview.topAnchor),
                    tint.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                    tint.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
                    tint.bottomAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.topAnchor),
                ])
            }

            self.statusBarTintView = tint
        }

        func updateTintColor(_ color: UIColor?) {
            guard let tint = statusBarTintView else { return }
            let target = color ?? .clear

            guard tint.backgroundColor != target else { return }

            UIView.animate(withDuration: 0.25) {
                tint.backgroundColor = target
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> WebViewHostController {
        let controller = WebViewHostController()

        let webView: WKWebView
        if let existingWebView = viewModel.webView {
            webView = existingWebView
            webView.removeFromSuperview()
        } else {
            webView = BrowserEngine.makeWebView(policy: policy)
            viewModel.attachWebView(webView)
            context.coordinator.hasAttached = true
        }

        controller.webView = webView
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.installStatusBarTint(above: webView)

        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: "insetProvider")
        webView.configuration.userContentController.add(context.coordinator, name: "insetProvider")

        return controller
    }

    func updateUIViewController(_ controller: WebViewHostController, context: Context) {
        guard let webView = controller.webView else { return }

        context.coordinator.parent = self

        if !context.coordinator.hasAttached {
            viewModel.attachWebView(webView)
            context.coordinator.hasAttached = true
            context.coordinator.lastToolbarHeight = -1
        }

        context.coordinator.installStatusBarTint(above: webView)
        context.coordinator.updateTintColor(viewModel.themeColor)

        controller.updateTopOffset(topBarOffset)

        if context.coordinator.lastPageReadyToken != viewModel.pageReadyToken {
            context.coordinator.lastToolbarHeight = -1
            context.coordinator.lastPageReadyToken = viewModel.pageReadyToken
        }

        pushCurrentInsets(webView: webView, controller: controller, context: context)
    }

    private func pushCurrentInsets(
        webView: WKWebView, controller: UIViewController? = nil, context: Context? = nil
    ) {
        let targetToolbarHeight = Int(bottomInset)
        let effectiveSafeTop = Int(statusBarInset)

        let toolbarNeedsUpdate =
            context == nil || targetToolbarHeight != context?.coordinator.lastToolbarHeight
        guard toolbarNeedsUpdate else { return }

        if let coordinator = context?.coordinator {
            coordinator.lastToolbarHeight = targetToolbarHeight
        }
        webView.scrollView.contentInset.bottom = bottomInset
        webView.scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
        webView.evaluateJavaScript(
            "(function(){ if(window.__updateStatusBarHeight) window.__updateStatusBarHeight(\(effectiveSafeTop)); if(window.__updateToolbarHeight) window.__updateToolbarHeight(\(targetToolbarHeight)); })();"
        )
    }
}

final class WebViewHostController: UIViewController {
    var webView: WKWebView? {
        didSet {
            guard let webView = webView, isViewLoaded else { return }
            setupWebView(webView)
        }
    }

    private var topConstraint: NSLayoutConstraint?

    func updateTopOffset(_ offset: CGFloat) {
        if topConstraint?.constant != offset {
            topConstraint?.constant = offset
            view.layoutIfNeeded()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        if let webView = webView {
            setupWebView(webView)
        }
    }

    private func setupWebView(_ webView: WKWebView) {
        if webView.superview == view {
            return
        }

        webView.removeFromSuperview()

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = .clear
        webView.isOpaque = false
        view.addSubview(webView)

        let top = webView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0)
        self.topConstraint = top

        NSLayoutConstraint.activate([
            top,
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

}

#Preview {
    HardenedWebView(viewModel: BrowserViewModel())
}
