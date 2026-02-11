import SwiftUI
import WebKit

struct HardenedWebView: UIViewRepresentable {
    let url: URL
    var policy: PrivacyPolicy = PrivacyPolicy()

    class Coordinator: NSObject {
        var lastLoadedURL: URL?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = BrowserEngine.makeWebView(policy: policy)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastLoadedURL != url {
            context.coordinator.lastLoadedURL = url
            let request = BrowserEngine.makeRequest(url: url)
            webView.load(request)
        }
    }
}

#Preview {
    HardenedWebView(url: URL(string: "https://apple.com")!)
}
