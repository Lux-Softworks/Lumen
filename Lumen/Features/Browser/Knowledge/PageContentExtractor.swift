import Foundation
import PDFKit
import SwiftSoup
import Readability

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
        nbTopCandidates: 5,
        charThreshold: 500,
        keepClasses: false,
    )

    func extractContent(from html: String, baseURL: URL?) async throws -> ExtractedContent {
        let parser = Readability()
        let article = try await parser.parse(html: html, options: options, baseURL: baseURL)

        let resolvedURL: String = baseURL?.absoluteString ?? ""

        let publishedDate: Date = {
            if let publishedTimeString = article.publishedTime {
                if let parsed = PageContentExtractor.parseDate(from: publishedTimeString) {
                    return parsed
                }
            }

            return Date()
        }()

        // Clean HTML to plain text
        let cleanedContent = try cleanHTML(article.content)
        
        return ExtractedContent(
            url: resolvedURL,
            title: article.title,
            content: cleanedContent,
            timestamp: publishedDate,
            author: article.byline,
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

private extension PageContentExtractor {
    static func parseDate(from string: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mmXXXXX",
            "EEE, dd MMM yyyy HH:mm:ss ZZZZZ",
            "yyyy-MM-dd"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
    
    func cleanHTML(_ html: String) throws -> String {
        let doc = try SwiftSoup.parse(html)
        
        // Remove script and style tags
        try doc.select("script, style").remove()
        
        // Get text content with proper spacing
        let text = try doc.text()
        
        // Clean up extra whitespace
        let cleaned = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        return cleaned
    }
}
