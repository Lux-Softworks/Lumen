import Foundation
import UIKit
import WebKit
import os.log

final class NetworkInterceptor: NSObject, WKNavigationDelegate {

    private let detector: ThreatDetector
    private let httpsOnly: Bool
    private let logger = AppLogger.make("NetworkInterceptor")

    private static let xhrKeywords = ["/api/", "/collect", "/pixel", "/beacon", "/track", "/event"]
    private static let requestLogCap = 500
    private static let fingerprintBlockThreshold = 3
    private static let fingerprintBlockWindow: TimeInterval = 10

    private(set) var currentPageURL: URL?
    private(set) var requestLog: [InterceptedRequest] = []
    private(set) var detectedThreats: [ThreatEvent] = []
    private var fingerprintEventsByScript: [URL: [Date]] = [:]
    private(set) var blockedFingerprintingScripts: Set<URL> = []

    private func appendRequest(_ request: InterceptedRequest) {
        requestLog.append(request)
        if requestLog.count > Self.requestLogCap {
            requestLog.removeFirst(requestLog.count - Self.requestLogCap)
        }
    }

    var onThreatDetected: ((ThreatEvent) -> Void)?
    var onDidCommit: ((WKWebView) -> Void)?
    var onDidFinishLoad: ((WKWebView) -> Void)?

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
        fingerprintEventsByScript.removeAll()
        blockedFingerprintingScripts.removeAll()
    }

    func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        if blockedFingerprintingScripts.contains(url) {
            logger.warning("Blocking fingerprinting script: \(url.absoluteString, privacy: .private)")
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

        let action = HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: httpsOnly)

        switch action {
        case .upgrade(let httpsURL):
            logger.info("HTTPS upgrade: \(url.absoluteString, privacy: .private) → \(httpsURL.absoluteString, privacy: .private)")
            webView.load(URLRequest(url: httpsURL))
            decisionHandler(.cancel)
            return

        case .cancel:
            if navigationAction.navigationType == .linkActivated,
                let scheme, scheme != "http", scheme != "https",
                UIApplication.shared.canOpenURL(url)
            {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            logger.warning("Blocking request with unauthorized scheme: \(scheme ?? "none", privacy: .public)")
            decisionHandler(.cancel)
            return

        case .allow:
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

            appendRequest(request)
            let threats = detector.analyze(request)

            if !threats.isEmpty {
                logger.warning("\(threats.count, privacy: .public) threat(s) on \(url.host ?? "unknown", privacy: .private)")
            }

            decisionHandler(.allow)
        }
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
                logger.info("Main frame loaded: \(url.host ?? "unknown", privacy: .private)")
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

                appendRequest(request)
                let _ = detector.analyze(request)
            }
        }

        if #available(iOS 14.5, *) {
            let shouldDownload = !navigationResponse.canShowMIMEType
                || DownloadHandler.shouldDownload(response: navigationResponse.response)
            if shouldDownload {
                decisionHandler(.download)
                return
            }
        }

        decisionHandler(.allow)
    }

    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = DownloadHandler.shared
    }

    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = DownloadHandler.shared
    }

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let method = challenge.protectionSpace.authenticationMethod

        if method == NSURLAuthenticationMethodServerTrust {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if method == NSURLAuthenticationMethodHTTPBasic
            || method == NSURLAuthenticationMethodHTTPDigest
            || method == NSURLAuthenticationMethodNTLM
        {
            Task { @MainActor in
                let credential = await Self.promptForCredential(
                    host: challenge.protectionSpace.host,
                    realm: challenge.protectionSpace.realm
                )
                if let credential {
                    completionHandler(.useCredential, credential)
                } else {
                    completionHandler(.cancelAuthenticationChallenge, nil)
                }
            }
            return
        }

        completionHandler(.performDefaultHandling, nil)
    }

    @MainActor
    private static func promptForCredential(host: String, realm: String?) async -> URLCredential? {
        await withCheckedContinuation { continuation in
            guard let top = topViewController() else {
                continuation.resume(returning: nil)
                return
            }

            let title = "Sign in to \(host)"
            let message = realm.flatMap { $0.isEmpty ? nil : "Realm: \($0)" } ?? "Enter your credentials"
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

            alert.addTextField { $0.placeholder = "User" }
            alert.addTextField {
                $0.placeholder = "Password"
                $0.isSecureTextEntry = true
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                continuation.resume(returning: nil)
            })
            alert.addAction(UIAlertAction(title: "Sign In", style: .default) { _ in
                let fields = alert.textFields ?? []
                let user = fields.count > 0 ? fields[0].text ?? "" : ""
                let password = fields.count > 1 ? fields[1].text ?? "" : ""
                let credential = URLCredential(user: user, password: password, persistence: .forSession)
                continuation.resume(returning: credential)
            })
            top.present(alert, animated: true)
        }
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
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

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        onDidCommit?(webView)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let url = webView.url {
            logger.info("Navigation started: \(url.absoluteString, privacy: .private)")
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            currentPageURL = url
            let threatCount = detectedThreats.count
            let requestCount = requestLog.count
            logger.info(
                "Page loaded: \(url.host ?? "unknown", privacy: .private) | \(requestCount, privacy: .public) requests | \(threatCount, privacy: .public) threats detected"
            )

            if !detectedThreats.isEmpty {
                logThreatSummary()
            }
        }
        onDidFinishLoad?(webView)
    }

    func webView(
        _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        logger.error("Navigation failed: \(error.localizedDescription, privacy: .public)")
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

        var haystack = url.path.lowercased()
        if let query = url.query {
            haystack.append("?")
            haystack.append(query.lowercased())
        }

        for keyword in Self.xhrKeywords {
            if haystack.contains(keyword) {
                return .xhr
            }
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
            logger.warning("\(type.rawValue, privacy: .public): \(count, privacy: .public)")
        }

        for (entity, count) in entityCounts.sorted(by: { $0.value > $1.value }).prefix(10) {
            logger.warning("\(entity, privacy: .private): \(count, privacy: .public) event(s)")
        }
    }

    func reportFingerprintingEvent(scriptUrl: URL, pageUrl: URL, api: String, webView: WKWebView?) {
        let isThirdParty = detector.classifyRequest(requestURL: scriptUrl, pageURL: pageUrl)

        let request = InterceptedRequest(
            url: scriptUrl,
            pageURL: pageUrl,
            headers: [:],
            isThirdParty: isThirdParty,
            resourceType: InterceptedRequest.ResourceType.script,
            timestamp: Date()
        )

        detector.analyzeHookedFingerprint(request: request, api: api)

        guard isThirdParty else { return }

        let now = Date()
        var events = fingerprintEventsByScript[scriptUrl, default: []]
        events = events.filter { now.timeIntervalSince($0) < Self.fingerprintBlockWindow }
        events.append(now)
        fingerprintEventsByScript[scriptUrl] = events

        if events.count >= Self.fingerprintBlockThreshold,
            !blockedFingerprintingScripts.contains(scriptUrl)
        {
            blockedFingerprintingScripts.insert(scriptUrl)
            logger.warning("Blocked fingerprinter: \(scriptUrl.absoluteString, privacy: .private)")
            neutralizeFingerprinting(in: webView)
        }
    }

    private func neutralizeFingerprinting(in webView: WKWebView?) {
        guard let webView else { return }
        let js = """
            (function() {
                try { HTMLCanvasElement.prototype.toDataURL = function() { return 'data:,'; }; } catch(_) {}
                try {
                    CanvasRenderingContext2D.prototype.getImageData = function(x, y, w, h) {
                        var width = (w | 0) || 1;
                        var height = (h | 0) || 1;
                        try { return new ImageData(width, height); } catch(_) {
                            return { data: new Uint8ClampedArray(width * height * 4), width: width, height: height };
                        }
                    };
                } catch(_) {}
                try { WebGLRenderingContext.prototype.getParameter = function() { return null; }; } catch(_) {}
                try {
                    if (window.AudioContext && AudioContext.prototype.createOscillator) {
                        AudioContext.prototype.createOscillator = function() { throw new Error('blocked'); };
                    }
                } catch(_) {}
            })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
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

        logger.warning(" [\(severityLabel, privacy: .public)] \(event.details, privacy: .private)")

        onThreatDetected?(event)
    }
}
