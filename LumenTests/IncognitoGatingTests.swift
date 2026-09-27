import Testing
import WebKit
@testable import Lumen

@MainActor
struct IncognitoGatingTests {
    @Test func incognitoFlagSurvivesWebViewCreation() {
        let webView = BrowserEngine.makeWebView(policy: PrivacyPolicy(), isIncognito: true)
        #expect(BrowserEngine.isIncognito(webView))
    }

    @Test func regularWebViewIsNotIncognito() {
        let webView = BrowserEngine.makeWebView(policy: PrivacyPolicy(), isIncognito: false)
        #expect(!BrowserEngine.isIncognito(webView))
    }

    @Test func configurationCopyDropsAssociatedFlag() {
        let webView = BrowserEngine.makeWebView(policy: PrivacyPolicy(), isIncognito: true)
        let flagOnConfigCopy =
            objc_getAssociatedObject(
                webView.configuration,
                &WebViewAssociatedKeys.incognitoFlagKey
            ) as? Bool ?? false
        #expect(!flagOnConfigCopy)
    }
}
