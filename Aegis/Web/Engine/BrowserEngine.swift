import SwiftUI
import WebKit
import ObjectiveC

struct PrivacyPolicy {
    var blocksThirdPartyCookies: Bool = true
    var allowsJavaScript: Bool = true
    var allowsInlineMediaPlayback: Bool = false
    var allowsPictureInPictureMediaPlayback: Bool = false
    var allowsAirPlayForMediaPlayback: Bool = false
    var javaScriptCanOpenWindowsAutomatically: Bool = false
    var suppressesIncrementalRendering: Bool = true
    var limitsNavigationToHTTPS: Bool = true
    var customUserAgent: String? = nil
}

// MARK: - build hardened instances
enum BrowserEngine {
    static func makeConfiguration(policy: PrivacyPolicy) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        config.websiteDataStore = .nonPersistent()

        let contentController = WKUserContentController()
        
        config.userContentController = contentController

        config.allowsInlineMediaPlayback = policy.allowsInlineMediaPlayback
        
        if #available(iOS 16.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        } else {
            config.requiresUserActionForMediaPlayback = true
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

        if #available(iOS 15.0, *) {
            webView.isInspectable = false
        }

        let httpsDelegate = HTTPSOnlyNavigationDelegate(enabled: policy.limitsNavigationToHTTPS)
        webView.navigationDelegate = httpsDelegate
        webView._retainedNavigationDelegate = httpsDelegate

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

final class HTTPSOnlyNavigationDelegate: NSObject, WKNavigationDelegate {
    private let httpsOnly: Bool

    init(enabled: Bool) {
        self.httpsOnly = enabled
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard httpsOnly, let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        if let scheme = url.scheme?.lowercased(), scheme == "http" {
            if var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                comps.scheme = "https"
                if let httpsURL = comps.url {
                    webView.load(URLRequest(url: httpsURL))
                }
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
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
            let request = BrowserEngine.makeRequest(url: url)
            webView.load(request)
        }
    }
}

