import Foundation
import WebKit

final class ReadingSignalHandler: NSObject, WKScriptMessageHandler {

    private let config: ReadingSignalConfig

    var onReadingSignalTriggered: ((ReadingSignalPayload) -> Void)?

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
        process(body: body)
    }

    func process(body: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: body),
              let payload = try? JSONDecoder().decode(ReadingSignalPayload.self, from: data)
        else { return }

        guard payload.triggered else { return }
        guard !isExcluded(urlString: payload.url) else { return }

        onReadingSignalTriggered?(payload)
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
