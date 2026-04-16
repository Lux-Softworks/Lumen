import SwiftUI
import UIKit
import WebKit

struct HardenedWebView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    @StateObject private var settings = BrowserSettings.shared
    var bottomInset: CGFloat = 0
    var safeAreaTop: CGFloat = 0

    var policy: PrivacyPolicy {
        settings.policy(for: viewModel.currentURL)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: HardenedWebView
        var hasAttached = false
        var statusBarTintView: UIView?
        var tintHeightConstraint: NSLayoutConstraint?
        var lastBottom: Int = -1
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

        func installStatusBarTint(above webView: WKWebView, height: CGFloat) {
            guard statusBarTintView == nil else { return }

            let tint = UIView()
            tint.translatesAutoresizingMaskIntoConstraints = false
            tint.backgroundColor = .clear
            tint.isUserInteractionEnabled = false

            DispatchQueue.main.async { [weak self] in
                guard let self, let superview = webView.superview else { return }
                let realHeight = webView.window?.safeAreaInsets.top ?? height
                superview.addSubview(tint)

                let heightConstraint = tint.heightAnchor.constraint(equalToConstant: realHeight)
                NSLayoutConstraint.activate([
                    tint.topAnchor.constraint(equalTo: superview.topAnchor),
                    tint.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                    tint.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
                    heightConstraint,
                ])
                self.tintHeightConstraint = heightConstraint
                self.statusBarTintView = tint
            }
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
        webView.isFindInteractionEnabled = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        context.coordinator.installStatusBarTint(above: webView, height: safeAreaTop)

        webView.configuration.userContentController.removeScriptMessageHandler(forName: "insetProvider")
        webView.configuration.userContentController.add(context.coordinator, name: "insetProvider")

        return controller
    }

    func updateUIViewController(_ controller: WebViewHostController, context: Context) {
        if let wv = controller.webView {
            let _ = wv.convert(wv.bounds, to: nil)
        }
        guard let webView = controller.webView else { return }

        context.coordinator.parent = self

        if !context.coordinator.hasAttached {
            viewModel.attachWebView(webView)
            context.coordinator.hasAttached = true
        }

        context.coordinator.installStatusBarTint(above: webView, height: safeAreaTop)
        context.coordinator.updateTintColor(viewModel.themeColor)

        if context.coordinator.lastPageReadyToken != viewModel.pageReadyToken {
            context.coordinator.lastBottom = -1
            context.coordinator.lastPageReadyToken = viewModel.pageReadyToken
        }

        pushCurrentInsets(webView: webView, context: context)
    }

    private func pushCurrentInsets(webView: WKWebView, context: Context?) {
        let bottom = Int(bottomInset)

        let needsUpdate = context == nil || bottom != context?.coordinator.lastBottom

        guard needsUpdate else { return }

        context?.coordinator.lastBottom = bottom

        let insets = UIEdgeInsets(top: 0, left: 0, bottom: CGFloat(bottom), right: 0)
        if webView.scrollView.contentInset != insets {
            webView.scrollView.contentInset = insets
            webView.scrollView.scrollIndicatorInsets = insets
        }

        webView.evaluateJavaScript(BrowserInsetScript.update(safeBottom: bottom))
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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        if let webView = webView {
            setupWebView(webView)
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        let windowTop = view.window?.safeAreaInsets.top
        let _ = view.safeAreaInsets.top
        let top = windowTop ?? 44
        guard topConstraint?.constant != top else {
            return
        }
        topConstraint?.constant = top
        view.layoutIfNeeded()
    }

    private func setupWebView(_ webView: WKWebView) {
        if webView.superview == view { return }

        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = .clear
        webView.isOpaque = false
        view.addSubview(webView)

        let top = webView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0)
        topConstraint = top
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
