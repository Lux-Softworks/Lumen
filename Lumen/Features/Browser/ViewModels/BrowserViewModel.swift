import Combine
import Foundation
import UIKit
import WebKit
import os.log

final class BrowserViewModel: NSObject, ObservableObject {
    @Published var urlString: String = ""
    @Published var currentURL: URL?
    @Published var pageTitle: String = ""
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

    private var observations: [NSKeyValueObservation] = []
    private let logger = Logger(
        subsystem: "com.luxsoftworks.Lumen", category: "BrowserViewModel")

    static let defaultURL = URL(string: "https://www.google.com")!
    static let searchEngineTemplate = "https://www.google.com/search?q=%@"

    private var brain: LocalBrain?

    func initializeBrain() {
        /* if brain == nil {
            brain = LocalBrain()
        
            Task {
                try? await brain?.loadModel()
            }
        } */
    }

    func processUserInput(_ input: String) async {
        await MainActor.run {
            navigate(to: input)
        }
    }

    func attachWebView(_ webView: WKWebView) {
        observations.removeAll()
        self.webView = webView

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
                        let results = try await SearchSuggestionService.shared.fetchSuggestions(
                            for: query)
                        await MainActor.run {
                            if !self.urlString.isEmpty {
                                self.searchSuggestions = results
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

    func navigate(to input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let url = Self.classifyInput(trimmed)
        loadURL(url)
    }

    func loadURL(_ url: URL) {
        clearPageState()
        urlString = url.absoluteString

        let request = BrowserEngine.makeRequest(url: url)
        webView?.load(request)

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

    func loadHomePage() {
        loadURL(Self.defaultURL)
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

    static func classifyInput(_ input: String) -> URL {
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
                        self?.updateThemeColorManually(webView)

                        if let url = webView.url?.absoluteString,
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
                webView.scrollView.backgroundColor = color ?? .systemBackground
            }
        }
    }

    private var lastContentOffset: CGFloat = 0
    @Published var scrollDelta: CGFloat = 0
    @Published var scrollOffset: CGFloat = 0
    @Published var themeColor: UIColor? = nil

    private func startScrollObservation(_ webView: WKWebView) {
        observations.append(
            webView.scrollView.observe(\.contentOffset, options: [.new]) {
                [weak self] scrollView, _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    let currentOffset = scrollView.contentOffset.y

                    let maxOffset = scrollView.contentSize.height - scrollView.frame.height

                    if currentOffset < 0 || currentOffset > maxOffset {
                        return
                    }

                    let delta = currentOffset - self.lastContentOffset
                    self.scrollDelta = delta
                    self.scrollOffset = currentOffset
                    self.lastContentOffset = currentOffset
                }
            }
        )
    }
}
