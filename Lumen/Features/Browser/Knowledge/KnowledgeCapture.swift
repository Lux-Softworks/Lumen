import Foundation
import WebKit

@MainActor
class KnowledgeCaptureService {
    static let shared = KnowledgeCaptureService()

    private init() {}

    func handleSignal(_ payload: ReadingSignalPayload, webView: WKWebView?) async {
        guard BrowserSettings.shared.collectKnowledge else { return }
        guard let webView = webView else { return }

        let html: String?
        do {
            html = try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String
        } catch {
            return
        }

        guard let html = html else { return }
        let url = webView.url

        let extractor = PageContentExtractor()
        guard let extractedContent = try? await extractor.extractContent(from: html, baseURL: url) else { return }

        let domain = PageContent.extractDomain(from: extractedContent.url)
        let wordCount = PageContent.countWords(in: extractedContent.content)

        do {
            if var website = try await KnowledgeStorage.shared.fetchWebsite(domain: domain) {
                website.lastVisit = Date()
                website.pageCount += 1
                website.totalWords += wordCount

                try await KnowledgeStorage.shared.updateWebsite(website)
            } else if payload.triggered {
                let websiteSummary = await KnowledgeClassifier.summarizeWebsite(content: extractedContent.content, title: extractedContent.title)
                let topicName = await KnowledgeClassifier.classify(content: extractedContent.content, title: extractedContent.title)

                var topicID: String? = nil
                if !topicName.isEmpty && topicName != "Other" {
                    if let existingTopic = try await KnowledgeStorage.shared.fetchTopic(name: topicName) {
                        topicID = existingTopic.id
                    } else {
                        topicID = try await KnowledgeStorage.shared.createTopic(name: topicName)
                    }
                }

                let newWebsite = Website(
                    domain: domain,
                    displayName: extractedContent.title,
                    summary: websiteSummary,
                    topicID: topicID,
                    pageCount: 1,
                    totalWords: wordCount,
                    firstVisit: Date(),
                    lastVisit: Date()
                )
                try await KnowledgeStorage.shared.createWebsite(website: newWebsite)
            }

            let pageSummary = await KnowledgeClassifier.summarize(content: extractedContent.content, title: extractedContent.title)

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
                if let embedding = await EmbeddingService.shared.generateEmbedding(for: extractedContent.content) {
                    try? await KnowledgeStorage.shared.saveEmbedding(pageID: pageID, vector: embedding)
                }
            }
        } catch {
            print("Knowledge capture failed: \(error)")
        }
    }

    func handleUpdateSignal(_ payload: ReadingSignalPayload) async {
        do {
            try await KnowledgeStorage.shared.updatePageEngagement(
                url: payload.url,
                scrollDepth: payload.scrollDepth,
                readingTime: payload.readingTime
            )
        } catch {
            print("Knowledge engagement update failed: \(error)")
        }
    }
}
