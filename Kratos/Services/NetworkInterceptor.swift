import Foundation
import WebKit
import os.log

final class NetworkInterceptor: NSObject, WKNavigationDelegate {

    private let detector: ThreatDetector
    private let httpsOnly: Bool
    private let logger = Logger(subsystem: "com.Kratos.browser", category: "NetworkInterceptor")

    private(set) var currentPageURL: URL?
    private(set) var requestLog: [InterceptedRequest] = []
    private(set) var detectedThreats: [ThreatEvent] = []

    var onThreatDetected: ((ThreatEvent) -> Void)?

    init(detector: ThreatDetector, httpsOnly: Bool = true) {
        self.detector = detector
        self.httpsOnly = httpsOnly
        super.init()
        self.detector.delegate = self
    }

    func clearSession() {
        requestLog.removeAll()
        detectedThreats.removeAll()
        currentPageURL = nil
    }

    func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let scheme = url.scheme?.lowercased()

        if navigationAction.navigationType == .linkActivated
            || navigationAction.navigationType == .formSubmitted
            || navigationAction.navigationType == .other
                && navigationAction.targetFrame?.isMainFrame == true
        {
            if scheme == "http" || scheme == "https" {
                currentPageURL = url
            }
        }

        if scheme == "http" && httpsOnly {
            if let httpsURL = upgradeToHTTPS(url) {
                logger.info("HTTPS upgrade: \(url.absoluteString) → \(httpsURL.absoluteString)")
                webView.load(URLRequest(url: httpsURL))
                decisionHandler(.cancel)

                return
            }
            decisionHandler(.cancel)
            return
        }

        if scheme == "https" || scheme == "about" || scheme == "file" {
            let pageURL = currentPageURL ?? url
            let isThirdParty = detector.classifyRequest(requestURL: url, pageURL: pageURL)

            let resourceType = mapResourceType(navigationAction)

            let request = InterceptedRequest(
                url: url,
                pageURL: pageURL,
                headers: navigationAction.request.allHTTPHeaderFields ?? [:],
                isThirdParty: isThirdParty,
                resourceType: resourceType,
                timestamp: Date()
            )

            requestLog.append(request)
            let threats = detector.analyze(request)

            if !threats.isEmpty {
                logger.warning("\(threats.count) threat(s) on \(url.host ?? "unknown")")
            }

            decisionHandler(.allow)
            return
        }

        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if let response = navigationResponse.response as? HTTPURLResponse,
            let url = response.url
        {
            let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? ""

            if navigationResponse.isForMainFrame {
                currentPageURL = url
                logger.info("Main frame loaded: \(url.host ?? "unknown")")
            }

            if contentType.contains("javascript") || url.pathExtension == "js" {
                let pageURL = currentPageURL ?? url
                let isThirdParty = detector.classifyRequest(requestURL: url, pageURL: pageURL)

                let request = InterceptedRequest(
                    url: url,
                    pageURL: pageURL,
                    headers: [:],
                    isThirdParty: isThirdParty,
                    resourceType: .script,
                    timestamp: Date()
                )

                requestLog.append(request)
                let _ = detector.analyze(request)
            }
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let url = webView.url {
            logger.info("Navigation started: \(url.absoluteString)")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            currentPageURL = url
            let threatCount = detectedThreats.count
            let requestCount = requestLog.count
            logger.info(
                "Page loaded: \(url.host ?? "unknown") | \(requestCount) requests | \(threatCount) threats detected"
            )

            if !detectedThreats.isEmpty {
                logThreatSummary()
            }
        }
    }

    func webView(
        _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        logger.error("Navigation failed: \(error.localizedDescription)")
    }

    private func upgradeToHTTPS(_ url: URL) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"

        return components?.url
    }

    private func mapResourceType(_ action: WKNavigationAction) -> InterceptedRequest.ResourceType {
        if action.targetFrame?.isMainFrame == true {
            return .document
        }

        guard let url = action.request.url else { return .other }

        let ext = url.pathExtension.lowercased()

        switch ext {
        case "js":
            return .script

        case "css":
            return .stylesheet

        case "png", "jpg", "jpeg", "gif", "webp", "svg", "ico":
            return .image

        case "woff", "woff2", "ttf", "otf", "eot":
            return .font

        case "mp4", "webm", "m3u8", "mp3":
            return .media

        default:
            break
        }

        let urlString = url.absoluteString.lowercased()

        if urlString.contains("/api/") || urlString.contains("/collect")
            || urlString.contains("/pixel") || urlString.contains("/beacon")
            || urlString.contains("/track") || urlString.contains("/event")
        {
            return .xhr
        }

        return .other
    }

    private func logThreatSummary() {
        var entityCounts: [String: Int] = [:]
        var typeCounts: [ThreatType: Int] = [:]

        for threat in detectedThreats {
            let name = threat.entity?.name ?? threat.sourceDomain
            entityCounts[name, default: 0] += 1
            typeCounts[threat.type, default: 0] += 1
        }

        for (type, count) in typeCounts.sorted(by: { $0.value > $1.value }) {
            logger.warning("\(type.rawValue): \(count)")
        }

        for (entity, count) in entityCounts.sorted(by: { $0.value > $1.value }).prefix(10) {
            logger.warning("\(entity): \(count) event(s)")
        }
    }
}

extension NetworkInterceptor: ThreatDetectorDelegate {
    func threatDetector(_ detector: ThreatDetector, didDetect event: ThreatEvent) {
        detectedThreats.append(event)

        let severityLabel: String
        switch event.severity {
        case .low: severityLabel = "LOW"
        case .medium: severityLabel = "MED"
        case .high: severityLabel = "HIGH"
        case .critical: severityLabel = "CRIT"
        }

        logger.warning(" [\(severityLabel)] \(event.details)")

        onThreatDetected?(event)
    }
}
