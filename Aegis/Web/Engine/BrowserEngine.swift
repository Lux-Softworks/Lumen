final class HTTPSOnlyNavigationDelegate: NSObject, WKNavigationDelegate {
    enum NavigationDecision: Equatable {
        case allow, cancel, upgradeToHTTPS(URL)
    }

    private let httpsOnly: Bool
    init(enabled: Bool) { self.httpsOnly = enabled }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, 
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        let decision = Self.policyDecision(for: url, isHTTPSOnly: httpsOnly)
        
        switch decision {
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
        guard let scheme = url.scheme?.lowercased() else { return .cancel }
        
        if scheme == "https" || scheme == "about" { return .allow }
        
        if scheme == "http" {
            if isHTTPSOnly, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                comps.scheme = "https"
                if let httpsURL = comps.url { return .upgradeToHTTPS(httpsURL) }
            }
            return isHTTPSOnly ? .cancel : .allow
        }
        
        return .cancel
    }
}