import ObjectiveC
import SwiftUI
import UIKit
import WebKit

enum BrowserEngine {
    static func makeConfiguration(policy: PrivacyPolicy) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        config.websiteDataStore = .nonPersistent()

        config.allowsInlineMediaPlayback = policy.allowsInlineMediaPlayback
        config.allowsAirPlayForMediaPlayback = policy.allowsAirPlayForMediaPlayback
        config.allowsPictureInPictureMediaPlayback = policy.allowsPictureInPictureMediaPlayback

        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = policy.allowsMediaAutoPlay ? [] : .all
        } else {
            config.requiresUserActionForMediaPlayback = !policy.allowsMediaAutoPlay
        }

        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = policy.allowsJavaScript
        } else {
            config.preferences.javaScriptEnabled = policy.allowsJavaScript
        }

        config.preferences.javaScriptCanOpenWindowsAutomatically =
            policy.javaScriptCanOpenWindowsAutomatically
        config.suppressesIncrementalRendering = policy.suppressesIncrementalRendering

        if let ua = policy.customUserAgent {
            config.applicationNameForUserAgent = ua
        }

        let insetStartScript = WKUserScript(
            source: BrowserInsetScript.atDocumentStart(safeBottom: 0),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(insetStartScript)

        let insetEndScript = WKUserScript(
            source: BrowserInsetScript.atDocumentEnd,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(insetEndScript)

        let fingerprintingScript = WKUserScript(
            source: """
                (function() {
                    function getScriptUrl() {
                        try { throw new Error(); } catch(e) {
                            var stack = e.stack || '';
                            var match = stack.match(/https?:\\/\\/[^\\s:"']+/);
                            if (match) return match[0];
                        }
                        return window.location.href;
                    }

                    function report(api) {
                        window.webkit.messageHandlers.fingerprintObserver.postMessage({
                            pageUrl: window.location.href,
                            scriptUrl: getScriptUrl(),
                            api: api
                        });
                    }

                    var origToDataURL = HTMLCanvasElement.prototype.toDataURL;
                    HTMLCanvasElement.prototype.toDataURL = function() {
                        report('canvas.toDataURL');
                        return origToDataURL.apply(this, arguments);
                    };

                    var origGetImageData = CanvasRenderingContext2D.prototype.getImageData;
                    CanvasRenderingContext2D.prototype.getImageData = function() {
                        report('getImageData');
                        return origGetImageData.apply(this, arguments);
                    };

                    var origGetParameter = WebGLRenderingContext.prototype.getParameter;
                    WebGLRenderingContext.prototype.getParameter = function() {
                        report('webgl.getParameter');
                        return origGetParameter.apply(this, arguments);
                    };

                    if (window.AudioContext) {
                        var origCreateOscillator = AudioContext.prototype.createOscillator;
                        AudioContext.prototype.createOscillator = function() {
                            report('createOscillator');
                            return origCreateOscillator.apply(this, arguments);
                        };
                    }
                })();
                """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(fingerprintingScript)

        let fingerprintMessageHandler = FingerprintMessageHandler()
        config.userContentController.add(fingerprintMessageHandler, name: "fingerprintObserver")

        objc_setAssociatedObject(
            config, &_WKWebViewAssociatedKeys.fingerprintHandlerKey, fingerprintMessageHandler,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let readingSignalConfig = ReadingSignalConfig.default
        let readingSignalScript = WKUserScript(
            source: ReadingSignalScript.makeScript(config: readingSignalConfig),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(readingSignalScript)

        let readingSignalHandler = ReadingSignalHandler(config: readingSignalConfig)
        readingSignalHandler.onReadingSignalTriggered = { payload, webView in
            Task {
                await KnowledgeCaptureService.shared.handleSignal(payload, webView: webView)
            }
        }
        config.userContentController.add(readingSignalHandler, name: "readingSignal")

        objc_setAssociatedObject(
            config, &_WKWebViewAssociatedKeys.readingSignalHandlerKey, readingSignalHandler,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        return config
    }

    static func makeWebView(policy: PrivacyPolicy) -> WKWebView {
        let config = makeConfiguration(policy: policy)
        let webView = WKWebView(frame: .zero, configuration: config)

        if #available(iOS 13.0, *) {
            webView.allowsLinkPreview = false
        }

        if #available(iOS 16.4, *) {
            webView.isInspectable = false
        }

        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        let detector = ThreatDetector()
        let interceptor = NetworkInterceptor(
            detector: detector, httpsOnly: policy.limitsNavigationToHTTPS)
        webView.navigationDelegate = interceptor
        webView.retainedDelegate = interceptor

        Task.detached(priority: .utility) {
            let entries = await TrackerDatabase.shared.allEntries()
            await MainActor.run {
                detector.loadTrackerDatabase(entries)
                webView.navigationDelegate = interceptor
                webView.retainedDelegate = interceptor
            }
        }

        if let handler = objc_getAssociatedObject(
            config, &_WKWebViewAssociatedKeys.fingerprintHandlerKey) as? FingerprintMessageHandler
        {
            handler.interceptor = interceptor
            objc_setAssociatedObject(
                webView, &_WKWebViewAssociatedKeys.fingerprintHandlerKey, handler,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }

        return webView
    }

    static func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy)
        request.timeoutInterval = 30
        return request
    }
}

private enum _WKWebViewAssociatedKeys {
    static var retainedNavigationDelegateKey: UInt8 = 0
    static var fingerprintHandlerKey: UInt8 = 1
    static var readingSignalHandlerKey: UInt8 = 2
}

final class FingerprintMessageHandler: NSObject, WKScriptMessageHandler {
    weak var interceptor: NetworkInterceptor?

    func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        guard message.name == "fingerprintObserver",
            let body = message.body as? [String: Any],
            let pageUrlString = body["pageUrl"] as? String,
            let scriptUrlString = body["scriptUrl"] as? String,
            let api = body["api"] as? String,
            let pageUrl = URL(string: pageUrlString),
            let scriptUrl = URL(string: scriptUrlString)
        else {
            return
        }

        interceptor?.reportFingerprintingEvent(scriptUrl: scriptUrl, pageUrl: pageUrl, api: api)
    }
}

extension WKWebView {
    fileprivate var retainedDelegate: WKNavigationDelegate? {
        get {
            objc_getAssociatedObject(self, &_WKWebViewAssociatedKeys.retainedNavigationDelegateKey)
                as? WKNavigationDelegate
        }
        set {
            objc_setAssociatedObject(
                self,
                &_WKWebViewAssociatedKeys.retainedNavigationDelegateKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

final class HTTPSOnlyNavigationDelegate: NSObject, WKNavigationDelegate {
    private let httpsOnly: Bool

    init(enabled: Bool) {
        self.httpsOnly = enabled
    }

    func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let action = HTTPSUpgradeLogic.decidePolicy(for: url, httpsOnly: httpsOnly)

        switch action {
        case .allow:
            decisionHandler(.allow)
        case .upgrade(let httpsURL):
            webView.load(BrowserEngine.makeRequest(url: httpsURL))
            decisionHandler(.cancel)
        case .cancel:
            decisionHandler(.cancel)
        }
    }
}
