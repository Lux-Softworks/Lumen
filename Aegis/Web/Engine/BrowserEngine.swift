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

enum BrowserEngine {
    static func makeConfiguration(policy: PrivacyPolicy) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        config.websiteDataStore = .nonPersistent()

        let contentController = WKUserContentController()
        
        config.userContentController = contentController

        config.allowsInlineMediaPlayback = policy.allowsInlineMediaPlayback
        config.mediaTypesRequiringUserActionForPlayback = policy.allowsMediaAutoPlay ? [] : .all

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

        if #available(iOS 15.0, *) {
            webView.isInspectable = false
        }

        let httpsDelegate = HTTPSOnlyNavigationDelegate(enabled: policy.limitsNavigationToHTTPS)
        webView.navigationDelegate = httpsDelegate
        webView._retainedNavigationDelegate = httpsDelegate

        return webView
    }
}

private enum _WKWebViewAssociatedKeys {
    static var retainedNavigationDelegateKey: UInt8 = 0
}

private extension WKWebView {
    var _retainedNavigationDelegate: WKNavigationDelegate? {
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

enum HTTPSUpgradeAction: Equatable {
    case allow
    case cancel
    case upgrade(URL)
}

struct HTTPSUpgradeLogic {
    static func decidePolicy(for url: URL, httpsOnly: Bool) -> HTTPSUpgradeAction {
        guard httpsOnly else { return .allow }

        if let scheme = url.scheme?.lowercased(), scheme == "http" {
            if var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                comps.scheme = "https"
                if let httpsURL = comps.url {
                    return .upgrade(httpsURL)
                }
            }
            return .cancel
        }
        return .allow
    }
}

final class HTTPSOnlyNavigationDelegate: NSObject, WKNavigationDelegate {
    enum NavigationDecision: Equatable {
        case allow
        case cancel
        case upgradeToHTTPS(URL)
    }

    private let httpsOnly: Bool

    init(enabled: Bool) {
        self.httpsOnly = enabled
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        switch Self.policyDecision(for: url, isHTTPSOnly: httpsOnly) {
        case .allow:
            decisionHandler(.allow)
          
        case .cancel:
            decisionHandler(.cancel)
          
        case .upgradeToHTTPS(let httpsURL):
            webView.load(URLRequest(url: httpsURL))
            decisionHandler(.cancel)
        }
    }

    static func policyDecision(for url: URL, isHTTPSOnly: Bool) -> NavigationDecision {
        guard isHTTPSOnly else { return .allow }

        guard let scheme = url.scheme?.lowercased() else {
            return .cancel
        }

        switch scheme {
        case "https", "about":
            return .allow
        case "http":
            if var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                comps.scheme = "https"
                if let httpsURL = comps.url {
                    return .upgradeToHTTPS(httpsURL)
                }
            }
            return .cancel
        default:
            return .cancel
        }
    }
}

// wrapper for immediate use
struct HardenedWebView: UIViewRepresentable {
    let url: URL
    var policy: PrivacyPolicy = PrivacyPolicy()

    func makeUIView(context: Context) -> WKWebView {
        BrowserEngine.makeWebView(policy: policy)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil || webView.url?.absoluteString != url.absoluteString {
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
            request.timeoutInterval = 30
            webView.load(request)
        }
    }
}

