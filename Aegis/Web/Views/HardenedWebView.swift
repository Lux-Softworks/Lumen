import SwiftUI
import WebKit

struct HardenedWebView: UIViewRepresentable {
    let url: URL
    var policy: PrivacyPolicy = PrivacyPolicy()

    func makeUIView(context: Context) -> WKWebView {
        let webView = BrowserEngine.makeWebView(policy: policy)
        let request = BrowserEngine.makeRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            let request = BrowserEngine.makeRequest(url: url)
            webView.load(request)
        }
    }
}

#Preview {
    HardenedWebView(url: URL(string: "https://apple.com")!)
}
