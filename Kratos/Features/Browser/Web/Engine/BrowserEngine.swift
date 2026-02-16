import ObjectiveC
import SwiftUI
import UIKit
import WebKit

struct PrivacyPolicy {
    var blocksThirdPartyCookies: Bool = true
    var allowsJavaScript: Bool = true
    var allowsInlineMediaPlayback: Bool = false
    var allowsPictureInPictureMediaPlayback: Bool = false
    var allowsAirPlayForMediaPlayback: Bool = false
    var allowsMediaAutoPlay: Bool = false
    var javaScriptCanOpenWindowsAutomatically: Bool = false
    var suppressesIncrementalRendering: Bool = true
    var limitsNavigationToHTTPS: Bool = true
    var customUserAgent: String? = nil
}

enum HTTPSUpgradeLogic {
    enum PolicyAction: Equatable {
        case allow
        case upgrade(URL)
        case cancel
    }

    static func decidePolicy(for url: URL, httpsOnly: Bool) -> PolicyAction {
        guard let scheme = url.scheme?.lowercased() else {
            return .allow
        }

        switch scheme {
        case "https", "about":
            return .allow
        case "http":
            if httpsOnly {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.scheme = "https"

                if let httpsURL = components?.url {
                    return .upgrade(httpsURL)
                }

                return .cancel
            }

            return .allow
        default:
            return httpsOnly ? .cancel : .allow
        }
    }
}

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
                    document.documentElement.style.setProperty(
                        '--toolbar-height', toolbarHeight + 'px');

                    var style = document.createElement('style');
                    style.textContent = '[data-bumped] { transition: bottom 0.2s ease-in-out !important; }';
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

                    function bumpBottomElements() {
                        var all = document.querySelectorAll('*');
                        for (var i = 0; i < all.length; i++) {
                            var el = all[i];
                            if (el.hasAttribute('data-bumped')) continue;

                            var s = getComputedStyle(el);
                            if (s.position !== 'fixed' && s.position !== 'sticky') continue;

                            if (s.bottom === 'auto' || s.bottom === '') continue;

                            var bottomVal = parseFloat(s.bottom);
                            if (isNaN(bottomVal) || bottomVal > 100) continue;

                            var rect = el.getBoundingClientRect();
                            if (rect.top < window.innerHeight / 2) continue;

                            el.setAttribute('data-original-bottom', String(bottomVal));
                            el.style.setProperty('bottom',
                                (bottomVal + toolbarHeight) + 'px', 'important');
                            el.setAttribute('data-bumped', '1');
                        }
                    }

                    // Global function called from Swift to update toolbar height
                    window.__updateToolbarHeight = function(h) {
                        toolbarHeight = h;
                        document.documentElement.style.setProperty(
                            '--toolbar-height', h + 'px');
                        var bumped = document.querySelectorAll('[data-bumped]');
                        for (var i = 0; i < bumped.length; i++) {
                            var orig = parseFloat(bumped[i].getAttribute('data-original-bottom')) || 0;
                            bumped[i].style.setProperty('bottom',
                                (orig + h) + 'px', 'important');
                        }
                    };

                    if (document.readyState === 'complete') {
                        bumpBottomElements();
                    } else {
                        window.addEventListener('load', bumpBottomElements);
                    }

                    setTimeout(bumpBottomElements, 1000);
                    setTimeout(bumpBottomElements, 3000);

                    var observer = new MutationObserver(function() {
                        requestAnimationFrame(bumpBottomElements);
                    });
                    observer.observe(document.documentElement,
                        { childList: true, subtree: true });
                })();
                """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(bottomInsetScript)

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
        detector.loadTrackerDatabase(TrackerDatabase.shared.allEntries())

        let interceptor = NetworkInterceptor(
            detector: detector, httpsOnly: policy.limitsNavigationToHTTPS)
        webView.navigationDelegate = interceptor
        webView.retainedDelegate = interceptor

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
