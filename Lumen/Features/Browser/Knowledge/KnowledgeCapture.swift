import Foundation
import ObjectiveC
import UIKit
import WebKit
import os
import SwiftUI
import Combine

extension Notification.Name {
    static let knowledgeCaptured = Notification.Name("lumen.knowledgeCaptured")
}

@MainActor
class KnowledgeCaptureService: ObservableObject {
    static let shared = KnowledgeCaptureService()

    @Published private(set) var captureToken: Int = 0

    private var backgroundTasks: Set<Task<Void, Never>> = []

    private init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.cancelBackgroundTasks()
            }
        }
    }

    func cancelBackgroundTasks() {
        for task in backgroundTasks { task.cancel() }
        backgroundTasks.removeAll()
    }

    func handleSignal(_ payload: ReadingSignalPayload, webView: WKWebView?) async {
        await capture(payload: payload, webView: webView, force: false)
    }

    func captureForHighlight(url: String, webView: WKWebView?) async {
        let payload = ReadingSignalPayload(
            url: url,
            title: "",
            readingTime: 5,
            scrollDepth: 0.05,
            triggered: true,
            isUpdate: false
        )
        await capture(payload: payload, webView: webView, force: true)
    }

    private func capture(payload: ReadingSignalPayload, webView: WKWebView?, force: Bool) async {
        guard BrowserSettings.shared.collectKnowledge else { return }
        guard let webView = webView else { return }

        let incognito = objc_getAssociatedObject(
            webView.configuration,
            &_WKWebViewAssociatedKeys.incognitoFlagKey
        ) as? Bool ?? false

        guard !incognito else { return }

        await Self.waitForDOMReady(webView: webView)

        let html: String?
        do {
            html = try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String
        } catch {
            KnowledgeLogger.capture.error(
                "outerHTML failed: \(String(describing: error), privacy: .public)"
            )
            return
        }

        guard let html = html else { return }

        let url = webView.url
        let extractor = PageContentExtractor()

        guard let extractedContent = try? await extractor.extractContent(from: html, baseURL: url) else {
            return
        }

        let domain = PageContent.extractDomain(from: extractedContent.url)
        let wordCount = PageContent.countWords(in: extractedContent.content)

        let quality = CaptureQuality.evaluate(
            url: payload.url,
            domain: domain,
            wordCount: wordCount,
            readingTime: payload.readingTime,
            scrollDepth: payload.scrollDepth,
            hasArticleMetadata: extractedContent.title?.isEmpty == false
        )

        guard quality.shouldCapturePage else { return }

        let topicName = await SemanticTopicClassifier.shared.classify(
            title: extractedContent.title,
            content: extractedContent.content
        )

        var resolvedTopicID: String? = nil
        if !topicName.isEmpty {
            do {
                if let existingTopic = try await KnowledgeStorage.shared.fetchTopic(name: topicName) {
                    resolvedTopicID = existingTopic.id
                } else {
                    resolvedTopicID = try await KnowledgeStorage.shared.createTopic(
                        name: topicName,
                        color: TopicColorPalette.hex(for: topicName)
                    )
                }
            } catch {
                KnowledgeLogger.capture.error(
                    "topic resolve failed: \(String(describing: error), privacy: .public)"
                )
            }
        }

        do {
            var newlyCreatedWebsiteID: String? = nil

            if var website = try await KnowledgeStorage.shared.fetchWebsite(domain: domain) {
                website.lastVisit = Date()
                website.pageCount += 1
                website.totalWords += wordCount

                if let meta = extractedContent.siteName?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !meta.isEmpty {
                    website.displayName = meta
                } else if website.displayName.isEmpty || website.displayName == domain {
                    website.displayName = DomainNameFormatter.format(host: domain)
                }

                if website.topicID == nil, let newID = resolvedTopicID {
                    website.topicID = newID
                }

                try await KnowledgeStorage.shared.updateWebsite(website)
            } else if quality.shouldCreateWebsite || force {
                let displayName = Self.resolveSiteName(extracted: extractedContent, domain: domain)
                    ?? DomainNameFormatter.format(host: domain)

                let newWebsite = Website(
                    domain: domain,
                    displayName: displayName,
                    summary: "",
                    topicID: resolvedTopicID,
                    pageCount: 1,
                    totalWords: wordCount,
                    firstVisit: Date(),
                    lastVisit: Date()
                )

                try await KnowledgeStorage.shared.createWebsite(website: newWebsite)
                newlyCreatedWebsiteID = newWebsite.id
            }

            let pageID = try await KnowledgeStorage.shared.save(
                url: payload.url,
                title: extractedContent.title,
                content: extractedContent.content,
                author: extractedContent.author,
                summary: nil,
                description: extractedContent.description,
                readingTime: payload.readingTime,
                scrollDepth: payload.scrollDepth
            )

            captureToken &+= 1
            NotificationCenter.default.post(name: .knowledgeCaptured, object: nil)

            let bgTask = Task.detached(priority: .background) { [extractedContent, newlyCreatedWebsiteID] in
                try? await Task.sleep(nanoseconds: 800_000_000)
                if Task.isCancelled { return }
                if let embedding = await EmbeddingService.shared.generateEmbedding(
                    for: extractedContent.content
                ) {
                    try? await KnowledgeStorage.shared.saveEmbedding(pageID: pageID, vector: embedding)
                }
                if Task.isCancelled { return }
                await Task.yield()
                try? await KnowledgeStorage.shared.saveEntities(
                    pageID: pageID,
                    content: extractedContent.content
                )
                if Task.isCancelled { return }
                await Task.yield()
                await KnowledgeStorage.shared.saveChunkedEmbeddings(
                    pageID: pageID,
                    content: extractedContent.content
                )
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 300_000_000)

                let pageSummary = await KnowledgeClassifier.summarize(
                    content: extractedContent.content,
                    title: extractedContent.title
                )
                if !pageSummary.isEmpty {
                    try? await KnowledgeStorage.shared.updatePageSummary(pageID: pageID, summary: pageSummary)
                }

                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 300_000_000)

                if let newSiteID = newlyCreatedWebsiteID {
                    let websiteSummary = await KnowledgeClassifier.summarizeWebsite(
                        content: extractedContent.content,
                        title: extractedContent.title
                    )
                    if !websiteSummary.isEmpty {
                        try? await KnowledgeStorage.shared.updateWebsiteSynthesis(
                            websiteID: newSiteID,
                            summary: websiteSummary,
                            pageCount: 1
                        )
                    }
                }

                await MainActor.run {
                    NotificationCenter.default.post(name: .knowledgeCaptured, object: nil)
                }
            }
            backgroundTasks.insert(bgTask)
            let trackedTask = bgTask
            Task { @MainActor [weak self] in
                _ = await trackedTask.value
                self?.backgroundTasks.remove(trackedTask)
            }
        } catch {
            KnowledgeLogger.capture.error(
                "capture failed: \(String(describing: error), privacy: .public)"
            )
        }
    }

    private static func waitForDOMReady(webView: WKWebView) async {
        let maxAttempts = 6
        for _ in 0..<maxAttempts {
            let state = try? await webView.evaluateJavaScript("document.readyState") as? String
            if state == "complete" { break }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    private static func resolveSiteName(extracted: ExtractedContent, domain: String) -> String? {
        if let meta = extracted.siteName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !meta.isEmpty {
            return meta
        }

        let formatted = DomainNameFormatter.format(host: domain)
        return formatted.isEmpty ? nil : formatted
    }

    func handleUpdateSignal(_ payload: ReadingSignalPayload) async {
        do {
            try await KnowledgeStorage.shared.updatePageEngagement(
                url: payload.url,
                scrollDepth: payload.scrollDepth,
                readingTime: payload.readingTime
            )
        } catch {
            KnowledgeLogger.capture.error(
                "engagement update failed: \(String(describing: error), privacy: .public)"
            )
        }
    }
}
