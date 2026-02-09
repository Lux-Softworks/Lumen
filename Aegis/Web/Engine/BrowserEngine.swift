import SwiftUI
import WebKit
import ObjectiveC

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
        case "https", "about", "file":
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
            return .allow
        }
    }
}


enum BrowserEngine {
    static func makeConfiguration(policy: PrivacyPolicy) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        config.websiteDataStore = .nonPersistent()

        config.allowsInlineMediaPlayback = policy.allowsInlineMediaPlayback

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

        config.preferences.javaScriptCanOpenWindowsAutomatically = policy.javaScriptCanOpenWindowsAutomatically
        config.suppressesIncrementalRendering = policy.suppressesIncrementalRendering

        if let ua = policy.customUserAgent {
            config.applicationNameForUserAgent = ua
        }

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

        let httpsDelegate = HTTPSOnlyNavigationDelegate(enabled: policy.limitsNavigationToHTTPS)
        webView.navigationDelegate = httpsDelegate
        webView.retainedDelegate = httpsDelegate

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

private extension WKWebView {
    var retainedDelegate: WKNavigationDelegate? {
        get {
            objc_getAssociatedObject(self, &_WKWebViewAssociatedKeys.retainedNavigationDelegateKey) as? WKNavigationDelegate
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

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let scheme = url.scheme?.lowercased()

        if scheme == "https" || scheme == "about" {
            decisionHandler(.allow)
            return
        }

        if scheme == "http" {
            if httpsOnly {
                if let httpsURL = upgradeToHTTPS(url) {
                    webView.load(URLRequest(url: httpsURL))
                    decisionHandler(.cancel)
                    return
                }
                decisionHandler(.cancel)
                return
            } else {
                decisionHandler(.allow)
                return
            }
        }

        decisionHandler(.allow)
    }

    private func upgradeToHTTPS(_ url: URL) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url
    }
}
