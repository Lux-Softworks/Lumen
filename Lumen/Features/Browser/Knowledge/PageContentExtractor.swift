import Foundation
import PDFKit
import Readability

// Simple extraction result - storage layer will link to website
struct ExtractedContent {
    let url: String
    let title: String?
    let content: String
    let timestamp: Date
    let author: String?
    let description: String?
}

struct PageContentExtractor {
    let options = Readability.Options(
        keepClasses: false,
        nbTopCandidates: 5,
        charThreshold: 500
    )

    func extractContent(from html: String, baseURL: URL?) async throws -> ExtractedContent {
        let parser = Readability()
        let article = try await parser.parse(html: html, options: options, baseURL: baseURL)

        return ExtractedContent(
            url: article.uri,
            title: article.title,
            content: article.content,
            timestamp: article.datePublished,
            author: article.author,
            description: article.excerpt
        )
    }

    func extractContent(from pdfUrl: URL) -> ExtractedContent? {
        guard let pdf = PDFDocument(url: pdfUrl) else { return nil }

        var extractedText = ""
        let pageCount = pdf.pageCount
        if pageCount > 0 {
            for index in 0..<pageCount {
                if let page = pdf.page(at: index) {
                    extractedText += page.string ?? ""
                    if index < pageCount - 1 { extractedText += "\n" }
                }
            }
        }

        var extractedTitle: String? = nil
        if let attrs = pdf.documentAttributes, let title = attrs[PDFDocumentAttribute.titleAttribute] as? String {
            extractedTitle = title
        }

        return ExtractedContent(
            url: pdfUrl.absoluteString,
            title: extractedTitle,
            content: extractedText,
            timestamp: Date(),
            author: nil,
            description: nil
        )
    }
}
