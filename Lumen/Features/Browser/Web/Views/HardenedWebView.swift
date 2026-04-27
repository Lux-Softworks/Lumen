import SwiftUI
import UIKit
import WebKit

struct HardenedWebView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    @ObservedObject private var settings = BrowserSettings.shared
    var bottomInset: CGFloat = 0
    var safeAreaTop: CGFloat = 0

    var policy: PrivacyPolicy {
        settings.policy(for: viewModel.currentURL)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: HardenedWebView
        var hasAttached = false
        var lastBottom: Int = -1
        var lastPageReadyToken: Int = -1
        weak var refreshControl: UIRefreshControl?
        weak var starView: UIImageView?
        var scrollObservation: NSKeyValueObservation?
        var isRefreshing = false

        init(_ parent: HardenedWebView) {
            self.parent = parent
        }

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            isRefreshing = true
            parent.viewModel.reload()
            Task { @MainActor in Haptics.fire(.snap) }
            starView?.alpha = 1
            startSpinning()
        }

        func startSpinning() {
            guard let starView = starView else { return }
            let currentAngle = (starView.layer.presentation()?.value(forKeyPath: "transform.rotation.z") as? CGFloat) ?? 0
            starView.transform = .identity
            let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.fromValue = currentAngle
            rotation.toValue = currentAngle + Double.pi * 2
            rotation.duration = 0.9
            rotation.repeatCount = .infinity
            starView.layer.add(rotation, forKey: "spin")
        }

        func stopSpinning() {
            isRefreshing = false
            starView?.layer.removeAnimation(forKey: "spin")
            starView?.transform = .identity
        }

        func observeScrollOffset(_ scrollView: UIScrollView) {
            scrollObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] sv, _ in
                guard let self, !self.isRefreshing else { return }
                let y = sv.contentOffset.y
                guard y < 0 else {
                    if self.starView?.alpha != 0 {
                        UIView.animate(withDuration: 0.3, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
                            self.starView?.alpha = 0
                            self.starView?.transform = .identity
                        }
                    }
                    return
                }
                guard self.starView?.layer.animation(forKey: "spin") == nil else { return }
                let progress = min(-y / 100.0, 1.0)
                self.starView?.alpha = progress
                self.starView?.transform = CGAffineTransform(rotationAngle: CGFloat(progress * .pi * 2))
            }
        }

        func userContentController(
            _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            guard message.name == "insetProvider", let webView = message.webView else { return }
            parent.pushCurrentInsets(webView: webView, context: nil)
        }

        func updateTintColor(_ color: UIColor?, controller: WebViewHostController?) {
            controller?.tintColor = color
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
            webView = BrowserEngine.makeWebView(policy: policy, isIncognito: viewModel.isIncognito)
            viewModel.attachWebView(webView)
            context.coordinator.hasAttached = true
        }

        controller.webView = webView
        webView.isFindInteractionEnabled = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .clear
        refreshControl.backgroundColor = .clear

        let starConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        let starImageView = UIImageView(image: UIImage(systemName: "sparkle", withConfiguration: starConfig))
        starImageView.tintColor = .white
        starImageView.alpha = 0
        starImageView.layer.shadowColor = UIColor.white.cgColor
        starImageView.layer.shadowRadius = 8
        starImageView.layer.shadowOpacity = 0.45
        starImageView.layer.shadowOffset = .zero
        starImageView.translatesAutoresizingMaskIntoConstraints = false
        refreshControl.addSubview(starImageView)
        NSLayoutConstraint.activate([
            starImageView.centerXAnchor.constraint(equalTo: refreshControl.centerXAnchor),
            starImageView.centerYAnchor.constraint(equalTo: refreshControl.centerYAnchor),
        ])
        context.coordinator.starView = starImageView

        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
        webView.scrollView.backgroundColor = viewModel.themeColor ?? .black
        context.coordinator.refreshControl = refreshControl

        context.coordinator.observeScrollOffset(webView.scrollView)
        webView.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        controller.installStatusBarTint(height: safeAreaTop)

        webView.configuration.userContentController.removeScriptMessageHandler(forName: "insetProvider")
        webView.configuration.userContentController.add(context.coordinator, name: "insetProvider")

        return controller
    }

    func updateUIViewController(_ controller: WebViewHostController, context: Context) {
        guard let webView = controller.webView else { return }

        context.coordinator.parent = self

        if !context.coordinator.hasAttached {
            viewModel.attachWebView(webView)
            context.coordinator.hasAttached = true
        }

        controller.installStatusBarTint(height: safeAreaTop)
        context.coordinator.updateTintColor(viewModel.themeColor, controller: controller)
        webView.scrollView.backgroundColor = viewModel.themeColor ?? .black
        webView.backgroundColor = viewModel.themeColor ?? .black

        if context.coordinator.lastPageReadyToken != viewModel.pageReadyToken {
            context.coordinator.lastBottom = -1
            context.coordinator.lastPageReadyToken = viewModel.pageReadyToken
            if !viewModel.isLoading {
                context.coordinator.refreshControl?.endRefreshing()
                context.coordinator.stopSpinning()
            }
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

    var statusBarTintView: UIView?
    private var tintHeightConstraint: NSLayoutConstraint?
    private var topConstraint: NSLayoutConstraint?

    var tintColor: UIColor? {
        didSet {
            let target = tintColor ?? .clear
            guard statusBarTintView?.backgroundColor != target else { return }
            UIView.animate(withDuration: 0.25) {
                self.statusBarTintView?.backgroundColor = target
            }
        }
    }

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
        let top = windowTop ?? 44

        topConstraint?.constant = top
        tintHeightConstraint?.constant = top
        view.layoutIfNeeded()
    }

    func installStatusBarTint(height: CGFloat) {
        guard statusBarTintView == nil else {
            if view.window == nil && tintHeightConstraint?.constant != height {
                tintHeightConstraint?.constant = height
            }
            return
        }

        let tint = UIView()
        tint.translatesAutoresizingMaskIntoConstraints = false
        tint.backgroundColor = .clear
        tint.isUserInteractionEnabled = false
        view.addSubview(tint)

        let realHeight = view.window?.safeAreaInsets.top ?? height
        let heightConstraint = tint.heightAnchor.constraint(equalToConstant: realHeight)
        NSLayoutConstraint.activate([
            tint.topAnchor.constraint(equalTo: view.topAnchor),
            tint.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            heightConstraint,
        ])
        self.tintHeightConstraint = heightConstraint
        self.statusBarTintView = tint
    }

    private func setupWebView(_ webView: WKWebView) {
        if webView.superview == view {
            webView.backgroundColor = tintColor ?? .black
            return
        }

        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.backgroundColor = tintColor ?? .black
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
