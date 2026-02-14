import SwiftUI
import WebKit

struct HardenedWebView: UIViewRepresentable {
    @ObservedObject var viewModel: BrowserViewModel
    var policy: PrivacyPolicy = PrivacyPolicy()

    class Coordinator: NSObject {
        var parent: HardenedWebView
        var hasAttached = false

        init(_ parent: HardenedWebView) {
            self.parent = parent
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = BrowserEngine.makeWebView(policy: policy)
        viewModel.attachWebView(webView)
        context.coordinator.hasAttached = true
        
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if !context.coordinator.hasAttached {
            viewModel.attachWebView(webView)
            context.coordinator.hasAttached = true
        }
    }
}

#Preview {
    HardenedWebView(viewModel: BrowserViewModel())
}
