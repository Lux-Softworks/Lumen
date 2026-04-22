import Foundation
import PDFKit
import SwiftSoup
import Readability

nonisolated struct ExtractedContent: Sendable {
    let url: String
    let title: String?
    let content: String
    let timestamp: Date
    let author: String?
    let description: String?
    let siteName: String?
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

        let cleanedContent = try cleanHTML(article.content)
        let siteName = (try? extractSiteName(from: html)) ?? nil

        return ExtractedContent(
            url: resolvedURL,
            title: article.title,
            content: cleanedContent,
            timestamp: publishedDate,
            author: article.byline,
            description: article.excerpt,
            siteName: siteName
        )
    }

    func extractContent(from pdfUrl: URL) -> ExtractedContent? {
        guard let pdf = PDFDocument(url: pdfUrl) else { return nil }

        var extractedText = ""
        let pageCount = pdf.pageCount
        if pageCount > 0 {
            for index in 0..<pageCount {
                if extractedText.count >= Self.maxContentChars { break }
                if let page = pdf.page(at: index) {
                    extractedText += page.string ?? ""
                    if index < pageCount - 1 { extractedText += "\n\n" }
                }
            }
        }
        if extractedText.count > Self.maxContentChars {
            extractedText = String(extractedText.prefix(Self.maxContentChars))
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
            description: nil,
            siteName: nil
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

    static let maxContentChars = 150_000
    static let blockSelectors = "p, h1, h2, h3, h4, h5, h6, li, blockquote, pre"

    func cleanHTML(_ html: String) throws -> String {
        let doc = try SwiftSoup.parse(html)

        try doc.select("script, style, noscript, nav, header, footer, aside, form, iframe").remove()
        try doc.select("[aria-hidden=true], [hidden]").remove()

        let blocks = try doc.select(Self.blockSelectors)
        var paragraphs: [String] = []
        var totalChars = 0

        for block in blocks {
            guard let text = try? block.text() else { continue }
            let normalized = normalizeWhitespace(text)
            guard normalized.count >= 20 else { continue }
            if totalChars + normalized.count > Self.maxContentChars { break }
            paragraphs.append(normalized)
            totalChars += normalized.count + 2
        }

        if paragraphs.isEmpty {
            let fallback = normalizeWhitespace((try? doc.text()) ?? "")
            return String(fallback.prefix(Self.maxContentChars))
        }

        return paragraphs.joined(separator: "\n\n")
    }

    private func normalizeWhitespace(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func extractSiteName(from html: String) throws -> String? {
        let doc = try SwiftSoup.parse(html)

        let metaQueries: [String] = [
            "meta[property=og:site_name]",
            "meta[name=og:site_name]",
            "meta[name=application-name]",
            "meta[name=apple-mobile-web-app-title]",
            "meta[property=twitter:site]"
        ]

        for query in metaQueries {
            if let element = try doc.select(query).first(),
               let raw = try? element.attr("content"),
               let cleaned = sanitizeSiteName(raw) {
                return cleaned
            }
        }

        return nil
    }

    private func sanitizeSiteName(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("@") { value.removeFirst() }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard value.count >= 2, value.count <= 60 else { return nil }

        let lower = value.lowercased()
        let rejected: Set<String> = [
            "website", "site", "home", "homepage", "page", "untitled",
            "document", "index", "default", "n/a", "none", "unknown"
        ]
        if rejected.contains(lower) { return nil }

        if value.contains("|") || value.contains(" - ") || value.contains(" – ") {
            let separators: [String] = [" | ", " - ", " – ", " — "]
            for separator in separators {
                if let range = value.range(of: separator) {
                    let first = String(value[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let second = String(value[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let pick = (first.count <= second.count && !first.isEmpty) ? first : second
                    if !pick.isEmpty, pick.count <= 60 { value = pick }
                    break
                }
            }
        }

        return value
    }
}
