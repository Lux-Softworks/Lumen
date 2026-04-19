import UIKit
import WebKit

@MainActor
final class BrowserUIDelegate: NSObject, WKUIDelegate {

    var onRequestNewWebView: ((WKWebViewConfiguration, WKNavigationAction) -> WKWebView?)?
    var onWebViewDidClose: ((WKWebView) -> Void)?

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let handler = onRequestNewWebView,
           let popupWebView = handler(configuration, navigationAction) {
            return popupWebView
        }

        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        
        return nil
    }

    func webViewDidClose(_ webView: WKWebView) {
        onWebViewDidClose?(webView)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        presentAlert(host: frame.request.url?.host, message: message, style: .alert) {
            completionHandler()
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        presentConfirm(host: frame.request.url?.host, message: message, completionHandler: completionHandler)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        presentPrompt(
            host: frame.request.url?.host,
            message: prompt,
            defaultText: defaultText,
            completionHandler: completionHandler
        )
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let typeLabel: String
        switch type {
        case .camera: typeLabel = "camera"
        case .microphone: typeLabel = "microphone"
        case .cameraAndMicrophone: typeLabel = "camera and microphone"
        @unknown default: typeLabel = "media devices"
        }

        presentConfirm(
            host: origin.host,
            message: "Allow access to your \(typeLabel)?"
        ) { allowed in
            decisionHandler(allowed ? .grant : .deny)
        }
    }

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else { return nil }
        guard let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? scene.windows.first?.rootViewController
        else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }

    private func presentAlert(host: String?, message: String, style: UIAlertController.Style, completion: @escaping () -> Void) {
        guard let top = topViewController() else { completion(); return }
        let alert = UIAlertController(title: host ?? "", message: message, preferredStyle: style)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completion() })
        top.present(alert, animated: true)
    }

    private func presentConfirm(host: String?, message: String, completionHandler: @escaping (Bool) -> Void) {
        guard let top = topViewController() else { completionHandler(false); return }
        let alert = UIAlertController(title: host ?? "", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "Allow", style: .default) { _ in completionHandler(true) })
        top.present(alert, animated: true)
    }

    private func presentPrompt(host: String?, message: String, defaultText: String?, completionHandler: @escaping (String?) -> Void) {
        guard let top = topViewController() else { completionHandler(nil); return }
        let alert = UIAlertController(title: host ?? "", message: message, preferredStyle: .alert)
        alert.addTextField { field in field.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(alert.textFields?.first?.text ?? defaultText)
        })
        top.present(alert, animated: true)
    }
}
