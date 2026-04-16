import Foundation
import WebKit

final class ReadingSignalHandler: NSObject, WKScriptMessageHandler {

    private let config: ReadingSignalConfig

    var onReadingSignalTriggered: ((ReadingSignalPayload, WKWebView?) -> Void)?
    var onReadingSignalUpdated: ((ReadingSignalPayload, WKWebView?) -> Void)?

    init(config: ReadingSignalConfig = .default) {
        self.config = config
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "readingSignal",
              let body = message.body as? [String: Any]
        else { return }
        process(body: body, webView: message.webView)
    }

    func process(body: [String: Any], webView: WKWebView?) {
        guard let data = try? JSONSerialization.data(withJSONObject: body),
              let payload = try? JSONDecoder().decode(ReadingSignalPayload.self, from: data)
        else { return }

        guard payload.triggered else { return }
        guard !isExcluded(urlString: payload.url) else { return }

        if payload.isUpdate {
            onReadingSignalUpdated?(payload, webView)
        } else {
            onReadingSignalTriggered?(payload, webView)
        }
    }

    func isExcluded(urlString: String) -> Bool {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return true }

        for excluded in config.excludedHosts where host == excluded {
            return true
        }

        for keyword in config.excludedHostKeywords where host.contains(keyword) {
            return true
        }

        return false
    }
}
