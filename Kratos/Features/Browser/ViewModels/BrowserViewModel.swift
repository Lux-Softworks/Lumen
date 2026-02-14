import Combine
import Foundation
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

    private(set) var webView: WKWebView?
    private var interceptor: NetworkInterceptor?

    private var observations: [NSKeyValueObservation] = []
    private let logger = Logger(subsystem: "com.Kratos.browser", category: "BrowserViewModel")

    static let defaultURL = URL(string: "https://www.google.com")!
    static let searchEngineTemplate = "https://www.google.com/search?q=%@"

    private var brain: LocalBrain?

    func initializeBrain() {
        if brain == nil {
            brain = LocalBrain()

            Task {
                try? await brain?.loadModel()
            }
        }
    }

    func processUserInput(_ input: String) async {
        initializeBrain()
        guard let brain = brain else { return }

        if input.starts(with: "/debug") {
            let prompt = String(input.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            logger.info("Debug Command Received: \(prompt)")

            guard let initialized: Bool? = (brain != nil) else {
                logger.error("Brain not initialized")
                return
            }

            Task {
                let response = await brain.debugRun(
                    prompt: prompt.isEmpty ? "Hello, system check." : prompt)
                await MainActor.run {
                    self.pageTitle = "AI: \(response)"
                    logger.info("AI Response: \(response)")
                }
            }
            return
        }

        let intent = await brain.route(input)

        await MainActor.run {
            switch intent {
            case .action:
                logger.info("Agent Action Detected for: \(input)")

            case .context:
                logger.info("Context Request Detected for: \(input)")

            case .knowledge:
                logger.info("Knowledge Query aka Standard Navigation: \(input)")

                navigate(to: input)
            }
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
    }

    func navigate(to input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let url: URL

        if let parsed = URL(string: trimmed), parsed.scheme != nil,
            parsed.host != nil || parsed.scheme == "about"
        {
            url = parsed
        } else if trimmed.contains(".") && !trimmed.contains(" ") {
            url = URL(string: "https://\(trimmed)") ?? Self.defaultURL
        } else {
            let encoded =
                trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed

            url = URL(string: String(format: Self.searchEngineTemplate, encoded)) ?? Self.defaultURL
        }

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
                MainActor.assumeIsolated {
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
                MainActor.assumeIsolated {
                    self?.pageTitle = webView.title ?? ""
                }
            }
        )

        observations.append(
            webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                MainActor.assumeIsolated {
                    self?.isLoading = webView.isLoading
                }
            }
        )

        observations.append(
            webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                MainActor.assumeIsolated {
                    self?.canGoBack = webView.canGoBack
                }
            }
        )

        observations.append(
            webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
                MainActor.assumeIsolated {
                    self?.canGoForward = webView.canGoForward
                }
            }
        )

        observations.append(
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                MainActor.assumeIsolated {
                    self?.estimatedProgress = webView.estimatedProgress
                }
            }
        )
    }
}
