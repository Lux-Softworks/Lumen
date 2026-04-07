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

        let bottomInsetScript = WKUserScript(
            source: """
                (function() {
                    var toolbarHeight = 80;
                    var statusBarHeight = 0;
                    var topStickyElements = [];

                    document.documentElement.style.setProperty(
                        '--toolbar-height', toolbarHeight + 'px');
                    document.documentElement.style.setProperty(
                        '--status-bar-height', statusBarHeight + 'px');

                    var style = document.createElement('style');
                    style.textContent =
                        '[data-kr-bumped-bottom] { transition: bottom 0.2s ease !important; }' +
                        '[data-kr-bumped-top] { transition: top 0.2s ease !important; }' +
                        '[data-kr-bounce-track] { will-change: transform; }';
                    document.head.appendChild(style);

                    var meta = document.querySelector('meta[name="viewport"]');
                    if (meta) {
                        var content = meta.getAttribute('content') || '';
                        if (content.indexOf('viewport-fit') === -1) {
                            meta.setAttribute('content', content + ', viewport-fit=cover');
                        }
                    } else {
                        meta = document.createElement('meta');
                        meta.name = 'viewport';
                        meta.content = 'width=device-width, initial-scale=1, viewport-fit=cover';
                        document.head.appendChild(meta);
                    }

                    function refreshTopStickyElements() {
                        topStickyElements = [];
                        var all = document.querySelectorAll('*');
                        for (var i = 0; i < all.length; i++) {
                            var el = all[i];
                            var s = getComputedStyle(el);
                            if (s.position !== 'fixed' && s.position !== 'sticky') continue;

                            var rect = el.getBoundingClientRect();
                            if (rect.top < window.innerHeight / 2) {
                                el.setAttribute('data-kr-bounce-track', '1');
                                topStickyElements.push(el);
                            }
                        }
                    }

                    function bumpElements() {
                        var all = document.querySelectorAll('*');
                        for (var i = 0; i < all.length; i++) {
                            var el = all[i];
                            var s = getComputedStyle(el);
                            if (s.position !== 'fixed' && s.position !== 'sticky') continue;

                            var rect = el.getBoundingClientRect();

                            if (!el.hasAttribute('data-kr-bumped-bottom') &&
                                rect.top > window.innerHeight / 2) {
                                var bottomVal = parseFloat(s.bottom);
                                if (s.bottom !== 'auto' && s.bottom !== '' &&
                                    !isNaN(bottomVal)) {
                                    el.setAttribute('data-kr-orig-bottom', String(bottomVal));
                                    el.style.setProperty('bottom',
                                        (bottomVal + toolbarHeight) + 'px', 'important');
                                    el.setAttribute('data-kr-bumped-bottom', '1');
                                }
                            }

                            if (!el.hasAttribute('data-kr-bumped-top') &&
                                statusBarHeight > 0 &&
                                rect.top < window.innerHeight / 3) {
                                var topVal = parseFloat(s.top);

                                if (s.top !== 'auto' && s.top !== '' &&
                                    !isNaN(topVal) && topVal < 60) {
                                    el.setAttribute('data-kr-orig-top', String(topVal));
                                    el.style.setProperty('top',
                                        (topVal + statusBarHeight) + 'px', 'important');
                                    el.setAttribute('data-kr-bumped-top', '1');
                                }
                            }
                        }
                        requestAnimationFrame(refreshTopStickyElements);
                    }

                    var lastBounceOffset = 0;

                    window.__nativeBounce = function(offset) {
                        if (offset > 0) {
                            var transform = 'translateY(' + offset + 'px)';
                            for (var i = 0; i < topStickyElements.length; i++) {
                                topStickyElements[i].style.transform = transform;
                            }
                            lastBounceOffset = offset;
                        } else if (lastBounceOffset > 0) {
                            for (var i = 0; i < topStickyElements.length; i++) {
                                topStickyElements[i].style.transform = '';
                            }
                            lastBounceOffset = 0;
                        }
                    };

                    window.__updateToolbarHeight = function(h) {
                        toolbarHeight = h;
                        document.documentElement.style.setProperty(
                            '--toolbar-height', h + 'px');
                        var bumped = document.querySelectorAll('[data-kr-bumped-bottom]');
                        for (var i = 0; i < bumped.length; i++) {
                            var orig = parseFloat(
                                bumped[i].getAttribute('data-kr-orig-bottom')) || 0;
                            bumped[i].style.setProperty('bottom',
                                (orig + h) + 'px', 'important');
                        }
                    };

                    window.__updateStatusBarHeight = function(h) {
                        statusBarHeight = h;
                        document.documentElement.style.setProperty(
                            '--status-bar-height', h + 'px');
                        var bumped = document.querySelectorAll('[data-kr-bumped-top]');
                        for (var i = 0; i < bumped.length; i++) {
                            var orig = parseFloat(
                                bumped[i].getAttribute('data-kr-orig-top')) || 0;
                            bumped[i].style.setProperty('top',
                                (orig + h) + 'px', 'important');
                        }
                        requestAnimationFrame(bumpElements);
                    };

                    if (document.readyState === 'complete') {
                        bumpElements();
                    } else {
                        window.addEventListener('load', bumpElements);
                    }

                    setTimeout(bumpElements, 500);
                    setTimeout(bumpElements, 1500);
                    setTimeout(bumpElements, 3000);

                    var debounceTimer;
                    var observer = new MutationObserver(function() {
                        clearTimeout(debounceTimer);
                        debounceTimer = setTimeout(function() {
                            requestAnimationFrame(bumpElements);
                        }, 100);
                    });
                    observer.observe(document.documentElement,
                        { childList: true, subtree: true, attributes: true,
                          attributeFilter: ['style', 'class'] });
                })();
                """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(bottomInsetScript)

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
            let entries = TrackerDatabase.shared.allEntries()
            detector.loadTrackerDatabase(entries)

            await MainActor.run {
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
