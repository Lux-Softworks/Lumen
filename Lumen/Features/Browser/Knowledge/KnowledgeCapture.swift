import Foundation
import ObjectiveC
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

    private init() {}

    func handleSignal(_ payload: ReadingSignalPayload, webView: WKWebView?) async {
        guard BrowserSettings.shared.collectKnowledge else { return }
        guard let webView = webView else { return }

        let incognito = objc_getAssociatedObject(
            webView.configuration,
            &_WKWebViewAssociatedKeys.incognitoFlagKey
        ) as? Bool ?? false

        guard !incognito else { return }

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

        let topicName = SemanticTopicClassifier.shared.classify(
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
            } else if quality.shouldCreateWebsite {
                let displayName = Self.resolveSiteName(extracted: extractedContent, domain: domain)
                    ?? DomainNameFormatter.format(host: domain)

                let websiteSummary = await KnowledgeClassifier.summarizeWebsite(
                    content: extractedContent.content,
                    title: extractedContent.title
                )

                let newWebsite = Website(
                    domain: domain,
                    displayName: displayName,
                    summary: websiteSummary,
                    topicID: resolvedTopicID,
                    pageCount: 1,
                    totalWords: wordCount,
                    firstVisit: Date(),
                    lastVisit: Date()
                )

                try await KnowledgeStorage.shared.createWebsite(website: newWebsite)
            }

            let pageSummary = await KnowledgeClassifier.summarize(
                content: extractedContent.content,
                title: extractedContent.title
            )

            let pageID = try await KnowledgeStorage.shared.save(
                url: payload.url,
                title: extractedContent.title,
                content: extractedContent.content,
                author: extractedContent.author,
                summary: pageSummary,
                description: extractedContent.description,
                readingTime: payload.readingTime,
                scrollDepth: payload.scrollDepth
            )

            Task.detached(priority: .utility) {
                if let embedding = await EmbeddingService.shared.generateEmbedding(
                    for: extractedContent.content
                ) {
                    try? await KnowledgeStorage.shared.saveEmbedding(pageID: pageID, vector: embedding)
                }
            }

            captureToken &+= 1
            NotificationCenter.default.post(name: .knowledgeCaptured, object: nil)
        } catch {
            KnowledgeLogger.capture.error(
                "capture failed: \(String(describing: error), privacy: .public)"
            )
        }
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
