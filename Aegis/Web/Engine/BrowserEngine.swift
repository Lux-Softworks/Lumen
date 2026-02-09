private extension WKWebView {
    var retainedDelegate: WKNavigationDelegate? {
        get { objc_getAssociatedObject(self, &_WKWebViewAssociatedKeys.retainedNavigationDelegateKey) as? WKNavigationDelegate }
        set { objc_setAssociatedObject(self, &_WKWebViewAssociatedKeys.retainedNavigationDelegateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

final class HTTPSOnlyNavigationDelegate: NSObject, WKNavigationDelegate {
    private let httpsOnly: Bool
    init(enabled: Bool) { self.httpsOnly = enabled }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        if url.scheme?.lowercased() == "https" || url.scheme?.lowercased() == "about" {
            decisionHandler(.allow)
            return
        }

        if httpsOnly && url.scheme?.lowercased() == "http" {
            if let httpsURL = upgradeToHTTPS(url) {
                webView.load(URLRequest(url: httpsURL))
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }

    private func upgradeToHTTPS(_ url: URL) -> URL? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url
    }
}