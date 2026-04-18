import Combine
import Foundation
import UIKit
import WebKit
import os.log

@MainActor
final class BrowserViewModel: NSObject, ObservableObject {
    @Published var urlString: String = ""
    @Published var currentURL: URL?
    @Published var pageTitle: String = ""
    @Published var pageReadyToken: Int = 0
    @Published var firstPaintToken: Int = 0
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var estimatedProgress: Double = 0.0
    @Published var isSecure: Bool = false
    @Published var threatEvents: [ThreatEvent] = []
    @Published var blockedTrackersCount: Int = 0

    @Published var searchSuggestions: [SearchSuggestion] = []
    private var searchCancellable: AnyCancellable?

    private(set) var webView: WKWebView?
    private var interceptor: NetworkInterceptor?
    private var pendingRequest: URLRequest?

    private var observations: [NSKeyValueObservation] = []
    private let logger = Logger(
        subsystem: "com.luxsoftworks.Lumen", category: "BrowserViewModel")

    private var defaultURL: URL {
        BrowserSettings.shared.searchEngine.homePage
    }

    private var searchEngineTemplate: String {
        BrowserSettings.shared.searchEngine.templateURL
    }

    private var knowledgeProvider: LocalKnowledgeProvider?
    let isIncognito: Bool

    func initializeKnowledgeProvider() {}

    func processUserInput(_ input: String) async {
        await MainActor.run {
            navigate(to: input)
        }
    }

    init(url: URL? = nil, isIncognito: Bool = false) {
        self.isIncognito = isIncognito
        super.init()
        self.currentURL = url
        self.urlString = url?.absoluteString ?? defaultURL.absoluteString
    }

    func attachWebView(_ webView: WKWebView) {
        observations.removeAll()
        self.webView = webView

        webView.configuration.userContentController.removeScriptMessageHandler(forName: "firstPaint")
        webView.configuration.userContentController.add(FirstPaintHandler(viewModel: self), name: "firstPaint")

        if let nav = webView.navigationDelegate as? NetworkInterceptor {
            self.interceptor = nav

            nav.onThreatDetected = { [weak self] event in
                self?.threatEvents.append(event)
                self?.blockedTrackersCount =
                    self?.threatEvents.filter { $0.type == .tracker }.count ?? 0
            }
        }

        observeWebView(webView)
        observeSearch()

        if let pending = pendingRequest {
            webView.load(pending)
            pendingRequest = nil
        }
    }

    private func observeSearch() {
        searchCancellable =
            $urlString
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                guard !query.isEmpty, !query.hasPrefix("http") else {
                    self.searchSuggestions = []
                    return
                }

                Task {
                    do {
                        async let semanticResults = KnowledgeStorage.shared.searchSemantic(query: query)
                        let local = try await semanticResults

                        let web: [SearchSuggestion]
                        if self.isIncognito {
                            web = []
                        } else {
                            web = try await SearchSuggestionService.shared.fetchSuggestions(for: query)
                        }

                        await MainActor.run {
                            if !self.urlString.isEmpty {
                                let localSuggestions = local.map { SearchSuggestion(text: $0.url) }
                                self.searchSuggestions = localSuggestions + web
                            }
                        }
                    } catch {
                        await MainActor.run {
                            self.searchSuggestions = []
                        }
                    }
                }
            }
    }

    func captureSnapshot() async -> UIImage? {
        guard let webView = webView else { return nil }
        let config = WKSnapshotConfiguration()
        config.rect = webView.bounds
        return try? await webView.takeSnapshot(configuration: config)
    }

    func navigate(to input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let url = self.classifyInput(trimmed)
        loadURL(url)
    }

    func loadURL(_ url: URL) {
        clearPageState()
        urlString = url.absoluteString

        let request = BrowserEngine.makeRequest(url: url)
        if let webView = webView {
            webView.load(request)
        } else {
            pendingRequest = request
        }

        logger.info("Loading: \(url.absoluteString)")
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        webView?.reload()
    }

    func stopLoading() {
        webView?.stopLoading()
    }

    private(set) var currentZoomPercent: Int = 100
    private(set) var isDesktopMode: Bool = false

    func applyZoom(_ percent: Int) {
        currentZoomPercent = percent
        webView?.evaluateJavaScript("document.body.style.zoom='\(percent)%'")
    }

    func setDesktopMode(_ on: Bool) {
        isDesktopMode = on
        let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView?.customUserAgent = on ? ua : nil
        webView?.reload()
    }

    func activateFindOnPage() {
        webView?.findInteraction?.presentFindNavigator(showingReplace: false)
    }

    func loadHomePage() {
        loadURL(defaultURL)
    }

    func clearPageState() {
        threatEvents.removeAll()
        blockedTrackersCount = 0
        themeColor = nil
        interceptor?.clearSession()
    }

    var privacySummary: String {
        let trackers = threatEvents.filter { $0.type == .tracker }.count
        let fingerprinters = threatEvents.filter { $0.type == .fingerprinter }.count
        let miners = threatEvents.filter { $0.type == .cryptominer }.count

        var parts: [String] = []
        if trackers > 0 { parts.append("\(trackers) tracker\(trackers == 1 ? "" : "s")") }

        if fingerprinters > 0 {
            parts.append("\(fingerprinters) fingerprinter\(fingerprinters == 1 ? "" : "s")")
        }

        if miners > 0 { parts.append("\(miners) miner\(miners == 1 ? "" : "s")") }

        return parts.isEmpty ? "No threats detected" : parts.joined(separator: ", ")
    }

    func classifyInput(_ input: String) -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultURL }

        if let parsed = URL(string: trimmed), parsed.scheme != nil,
            parsed.host != nil || parsed.scheme == "about"
        {
            return parsed
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            return URL(string: "https://\(trimmed)") ?? defaultURL
        } else {
            let encoded =
                trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            return URL(string: String(format: searchEngineTemplate, encoded)) ?? defaultURL
        }
    }

    private func observeWebView(_ webView: WKWebView) {
        observations.append(
            webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor [weak self] in
                    self?.currentURL = webView.url

                    if let url = webView.url {
                        self?.urlString = url.absoluteString
                        self?.isSecure = url.scheme == "https"
                    }
                }
            }
        )

        observations.append(
            webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor [weak self] in
                    self?.pageTitle = webView.title ?? ""
                }
            }
        )

        observations.append(
            webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor [weak self] in
                    self?.isLoading = webView.isLoading

                    if !webView.isLoading {
                        self?.pageReadyToken += 1
                        self?.updateThemeColorManually(webView)

                        _ = try? await webView.evaluateJavaScript("""
                            requestAnimationFrame(() => {
                                requestAnimationFrame(() => {
                                    window.webkit.messageHandlers.firstPaint.postMessage({});
                                });
                            });
                        """)

                        if let self,
                            !self.isIncognito,
                            let url = webView.url?.absoluteString,
                            let title = webView.title, !title.isEmpty
                        {
                            HistoryStore.shared.record(url: url, title: title)
                        }
                    }
                }
            }
        )

        observations.append(
            webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor [weak self] in
                    self?.canGoBack = webView.canGoBack
                }
            }
        )

        observations.append(
            webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor [weak self] in
                    self?.canGoForward = webView.canGoForward
                }
            }
        )

        observations.append(
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor [weak self] in
                    self?.estimatedProgress = webView.estimatedProgress
                }
            }
        )

        if #available(iOS 15.0, *) {
            observations.append(
                webView.observe(\.themeColor, options: [.new]) { [weak self] webView, _ in
                    Task { @MainActor [weak self] in
                        if let newColor = webView.themeColor {
                            self?.themeColor = newColor
                        } else {
                            self?.updateThemeColorManually(webView)
                        }
                    }
                }
            )
        }

        startScrollObservation(webView)
    }

    private func updateThemeColorManually(_ webView: WKWebView) {
        let script = """
                (function() {
                    var meta = document.querySelector('meta[name="theme-color"]');
                    if (meta) {
                        return meta.content;
                    }

                    function getBackgroundColor(element) {
                        if (!element) return null;
                        var style = window.getComputedStyle(element);
                        var color = style.backgroundColor;

                        if (color === 'rgba(0, 0, 0, 0)' || color === 'transparent') {
                            return null;
                        }
                        return color;
                    }

                    var elements = document.elementsFromPoint(window.innerWidth / 2, 5);
                    for (var i = 0; i < elements.length; i++) {
                        var el = elements[i];
                        var bg = getBackgroundColor(el);
                        if (bg) return bg;
                    }

                    var bodyColor = getBackgroundColor(document.body);
                    if (bodyColor) return bodyColor;

                    var htmlColor = getBackgroundColor(document.documentElement);
                    if (htmlColor) return htmlColor;

                    return "white";
                })();
            """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let colorString = result as? String else { return }

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let color = UIColor.fromAnyString(colorString)
                self.themeColor = color
            }
        }
    }

    @Published var themeColor: UIColor? = nil

    var onScrollUpdate: ((CGFloat, CGFloat, CGFloat, CGFloat) -> Void)?

    private func startScrollObservation(_ webView: WKWebView) {
        observations.append(
            webView.scrollView.observe(\.contentOffset, options: [.old, .new]) { [weak self, weak webView] _, change in
                guard let self = self,
                      let newY = change.newValue?.y,
                      let oldY = change.oldValue?.y else { return }

                MainActor.assumeIsolated {
                    let delta = newY - oldY
                    self.onScrollUpdate?(newY, delta, webView?.scrollView.contentSize.height ?? 0, webView?.scrollView.bounds.height ?? 0)
                }
            }
        )
    }

    deinit {
        observations.forEach { $0.invalidate() }
    }
}
