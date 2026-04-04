import SwiftUI
import UIKit
import WebKit

struct HardenedWebView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    @StateObject private var settings = BrowserSettings.shared
    var bottomInset: CGFloat = 0
    
    var policy: PrivacyPolicy {
        settings.policy(for: viewModel.currentURL)
    }

    class Coordinator: NSObject {
        var parent: HardenedWebView
        var hasAttached = false
        var statusBarTintView: UIView?
        var lastStatusBarHeight: Int = 0

        init(_ parent: HardenedWebView) {
            self.parent = parent
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
        let webView = BrowserEngine.makeWebView(policy: policy)
        controller.webView = webView
        controller.additionalSafeAreaInsets.bottom = bottomInset

        viewModel.attachWebView(webView)
        context.coordinator.hasAttached = true
        context.coordinator.installStatusBarTint(above: webView)

        return controller
    }

    func updateUIViewController(_ controller: WebViewHostController, context: Context) {
        guard let webView = controller.webView else { return }

        if !context.coordinator.hasAttached {
            viewModel.attachWebView(webView)
            context.coordinator.hasAttached = true
        }

        context.coordinator.installStatusBarTint(above: webView)
        context.coordinator.updateTintColor(viewModel.themeColor)

        if controller.additionalSafeAreaInsets.bottom != bottomInset {
            UIView.animate(withDuration: 0.2) {
                controller.additionalSafeAreaInsets.bottom = bottomInset
            }

            webView.evaluateJavaScript(
                "window.__updateToolbarHeight && window.__updateToolbarHeight(\(Int(bottomInset)))"
            )
        }

        let safeTop = Int(webView.safeAreaInsets.top)
        if safeTop > 0 && context.coordinator.lastStatusBarHeight != safeTop {
            context.coordinator.lastStatusBarHeight = safeTop
            webView.evaluateJavaScript(
                "window.__updateStatusBarHeight && window.__updateStatusBarHeight(\(safeTop))"
            )
        }
    }
}

final class WebViewHostController: UIViewController {
    var webView: WKWebView?

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let webView = webView else { return }

        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

#Preview {
    HardenedWebView(viewModel: BrowserViewModel())
}
