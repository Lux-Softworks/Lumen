import SwiftUI
import UIKit
import WebKit

struct HardenedWebView: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    var policy: PrivacyPolicy = PrivacyPolicy()

    class Coordinator: NSObject {
        var parent: HardenedWebView
        var hasAttached = false
        var statusBarTintView: UIView?

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

                let safeTop = webView.safeAreaInsets.top
                let height: CGFloat = safeTop > 0 ? safeTop : 59

                NSLayoutConstraint.activate([
                    tint.topAnchor.constraint(equalTo: superview.topAnchor),
                    tint.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                    tint.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
                    tint.heightAnchor.constraint(equalToConstant: height),
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

    func makeUIView(context: Context) -> WKWebView {
        let webView = BrowserEngine.makeWebView(policy: policy)

        viewModel.attachWebView(webView)
        context.coordinator.hasAttached = true
        context.coordinator.installStatusBarTint(above: webView)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if !context.coordinator.hasAttached {
            viewModel.attachWebView(webView)
            context.coordinator.hasAttached = true
        }

        context.coordinator.installStatusBarTint(above: webView)

        context.coordinator.updateTintColor(viewModel.themeColor)
    }
}

#Preview {
    HardenedWebView(viewModel: BrowserViewModel())
}
