import Foundation
import Testing
import WebKit
@testable import Lumen

@MainActor
struct ContentRuleCompilationTests {
    @Test func bundledTrackingRulesCompileInWebKit() async throws {
        let url = try #require(Bundle.main.url(forResource: "disconnect-services", withExtension: "json"))
        let list = TrackerBlockList(entries: DisconnectList.entries(from: try Data(contentsOf: url)))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try #require(WKContentRuleListStore(url: directory))

        let compiled = try await store.compileContentRuleList(
            forIdentifier: "test.tracking",
            encodedContentRuleList: TrackerBlockList.encode(list.contentRules())
        )

        #expect(compiled != nil)
    }

    @Test func mixedContentRulesCompileInWebKit() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try #require(WKContentRuleListStore(url: directory))

        let compiled = try await store.compileContentRuleList(
            forIdentifier: "test.mixed-content",
            encodedContentRuleList: TrackerBlockList.encode(TrackerBlockList.mixedContentRules)
        )

        #expect(compiled != nil)
    }

    @Test func bundledListStaysWellUnderWebKitsRuleLimit() throws {
        let url = try #require(Bundle.main.url(forResource: "disconnect-services", withExtension: "json"))
        let list = TrackerBlockList(entries: DisconnectList.entries(from: try Data(contentsOf: url)))

        #expect(list.contentRules().count > 2_000)
        #expect(list.contentRules().count < 150_000)
    }

    @Test func ruleListIdentifierChangesWhenTheRulesChange() {
        let first = ContentBlockingRules.identifier(prefix: "lumen.tracking", encodedRules: #"[{"a":1}]"#)
        let second = ContentBlockingRules.identifier(prefix: "lumen.tracking", encodedRules: #"[{"a":2}]"#)

        #expect(first != second)
    }
}

@MainActor
struct BrowserEnginePolicyTests {
    @Test func newWebViewHasItsNavigationInterceptorImmediately() {
        let webView = BrowserEngine.makeWebView(policy: PrivacyPolicy())

        #expect(webView.navigationDelegate is NetworkInterceptor)
    }

    @Test func sitePolicyTurnsJavaScriptOffForTheNavigation() {
        let webView = BrowserEngine.makeWebView(policy: PrivacyPolicy())
        let preferences = WKWebpagePreferences()
        var policy = PrivacyPolicy()
        policy.allowsJavaScript = false

        BrowserEngine.applyPagePolicy(policy, to: preferences, in: webView)

        #expect(preferences.allowsContentJavaScript == false)
    }

    @Test func sitePolicyAllowsPopupsInAnAlreadyOpenWebView() {
        var creationPolicy = PrivacyPolicy()
        creationPolicy.javaScriptCanOpenWindowsAutomatically = false
        let webView = BrowserEngine.makeWebView(policy: creationPolicy)
        var sitePolicy = PrivacyPolicy()
        sitePolicy.javaScriptCanOpenWindowsAutomatically = true

        BrowserEngine.applyPagePolicy(sitePolicy, to: WKWebpagePreferences(), in: webView)

        #expect(webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically)
    }
}

@MainActor
struct BlockedTrackerCountTests {
    @Test func trackersOnAPageWithBlockingOnAreCountedByHost() throws {
        let interceptor = NetworkInterceptor(detector: ThreatDetector())
        interceptor.trackerBlockList = TrackerBlockList(entries: [
            DisconnectEntry(categoryKey: "Advertising", entityName: "AdCo", domains: ["adco.net"])
        ])
        interceptor.beginPage(try #require(URL(string: "https://news.example/")), blocksTrackers: true)

        interceptor.recordResourceURLs([
            try #require(URL(string: "https://px.adco.net/a.gif")),
            try #require(URL(string: "https://px.adco.net/b.gif"))
        ])

        #expect(interceptor.blockedTrackerHosts == ["px.adco.net"])
    }

    @Test func trackersOnAPageWithBlockingOffAreNotCounted() throws {
        let interceptor = NetworkInterceptor(detector: ThreatDetector())
        interceptor.trackerBlockList = TrackerBlockList(entries: [
            DisconnectEntry(categoryKey: "Advertising", entityName: "AdCo", domains: ["adco.net"])
        ])
        interceptor.beginPage(try #require(URL(string: "https://news.example/")), blocksTrackers: false)

        interceptor.recordResourceURLs([try #require(URL(string: "https://px.adco.net/a.gif"))])

        #expect(interceptor.blockedTrackerHosts.isEmpty)
    }

    @Test func startingANewPageResetsTheCount() throws {
        let interceptor = NetworkInterceptor(detector: ThreatDetector())
        interceptor.trackerBlockList = TrackerBlockList(entries: [
            DisconnectEntry(categoryKey: "Advertising", entityName: "AdCo", domains: ["adco.net"])
        ])
        interceptor.beginPage(try #require(URL(string: "https://news.example/")), blocksTrackers: true)
        interceptor.recordResourceURLs([try #require(URL(string: "https://px.adco.net/a.gif"))])

        interceptor.beginPage(try #require(URL(string: "https://blog.example/")), blocksTrackers: true)

        #expect(interceptor.blockedTrackerHosts.isEmpty)
    }
}
