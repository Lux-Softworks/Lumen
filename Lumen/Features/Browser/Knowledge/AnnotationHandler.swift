import Foundation
import ObjectiveC
import WebKit
import os

final class AnnotationHandler: NSObject, WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "annotation",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String,
              let webView = message.webView else { return }

        switch action {
        case "create":
            guard let url = body["url"] as? String,
                  let text = body["text"] as? String,
                  !text.isEmpty else { return }
            let incognito = objc_getAssociatedObject(
                webView.configuration,
                &_WKWebViewAssociatedKeys.incognitoFlagKey
            ) as? Bool ?? false
            if incognito { return }
            let prefix = body["prefix"] as? String ?? ""
            let suffix = body["suffix"] as? String ?? ""

            Task { [weak webView] in
                do {
                    _ = try await KnowledgeStorage.shared.saveAnnotation(
                        url: url, text: text, prefix: prefix, suffix: suffix
                    )
                    if let wv = webView {
                        await MainActor.run { Self.applyAll(webView: wv) }
                    }
                } catch {
                    KnowledgeLogger.storage.error("annotation save failed: \(String(describing: error), privacy: .public)")
                }
            }

            Task { [weak webView] in
                if let wv = webView {
                    await KnowledgeCaptureService.shared.captureForHighlight(url: url, webView: wv)
                }
            }

        default:
            break
        }
    }

    @MainActor
    static func applyAll(webView: WKWebView) {
        guard let urlString = webView.url?.absoluteString else { return }
        let normalized = PageContent.normalizeURL(urlString)

        Task { [weak webView] in
            let annotations: [Annotation]
            do {
                annotations = try await KnowledgeStorage.shared.fetchAnnotations(normalizedURL: normalized)
            } catch { return }

            guard !annotations.isEmpty, let wv = webView else { return }

            let payload = annotations.map { ann in
                [
                    "id": ann.id,
                    "text": ann.text,
                    "prefix": ann.prefix,
                    "suffix": ann.suffix,
                ]
            }
            let script = AnnotationScript.applyJS(annotations: payload)
            await MainActor.run {
                wv.evaluateJavaScript(script, completionHandler: nil)
            }
        }
    }
}
