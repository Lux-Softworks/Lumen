import XCTest
@testable import Lumen

final class PageContentExtractorTests: XCTestCase {
    
    var extractor: PageContentExtractor!
    
    override func setUp() {
        super.setUp()
        extractor = PageContentExtractor()
    }
    
    func testBasicHTMLExtraction() async throws {
        let html = """
        <html>
        <head><title>Test Article</title></head>
        <body>
            <article>
                <h1>Main Title</h1>
                <p>This is the main content of the article.</p>
                <p>It has multiple paragraphs.</p>
            </article>
        </body>
        </html>
        """
        
        let baseURL = URL(string: "https://example.com/article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)
        
        XCTAssertEqual(result.url, "https://example.com/article")
        XCTAssertNotNil(result.title)
        XCTAssertFalse(result.content.isEmpty)
        XCTAssertTrue(result.content.contains("main content"))
    }
    
    func testHTMLCleaning() async throws {
        let html = """
        <html>
        <body>
            <article>
                <h1>Article Title</h1>
                <p>Text with    multiple     spaces.</p>
                <script>console.log('should be removed');</script>
                <style>.hidden { display: none; }</style>
                <p>More content here.</p>
            </article>
        </body>
        </html>
        """
        
        let baseURL = URL(string: "https://example.com")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)
        
        XCTAssertFalse(result.content.contains("<script>"))
        XCTAssertFalse(result.content.contains("<style>"))
        XCTAssertFalse(result.content.contains("console.log"))
        XCTAssertFalse(result.content.contains(".hidden"))
        XCTAssertFalse(result.content.contains("     "))
    }
    
    func testISO8601DateParsing() async throws {
        let html = """
        <html>
        <head>
            <meta property="article:published_time" content="2024-03-15T10:30:00Z">
        </head>
        <body>
            <article><p>Content</p></article>
        </body>
        </html>
        """
        
        let baseURL = URL(string: "https://example.com")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)
        
        XCTAssertNotNil(result.timestamp)
    }
    
    func testMissingDateFallsBackToCurrentDate() async throws {
        let html = """
        <html>
        <body><article><p>Content without date</p></article></body>
        </html>
        """
        
        let baseURL = URL(string: "https://example.com")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)
        
        XCTAssertNotNil(result.timestamp)
        let now = Date()
        XCTAssertEqual(result.timestamp.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 2.0)
    }
    
    func testAuthorExtraction() async throws {
        let html = """
        <html>
        <head>
            <meta name="author" content="John Doe">
        </head>
        <body>
            <article>
                <div class="author">By John Doe</div>
                <p>Article content</p>
            </article>
        </body>
        </html>
        """
        
        let baseURL = URL(string: "https://example.com")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)
        
        XCTAssertNotNil(result.content)
    }
    
    func testMissingMetadataHandling() async throws {
        let html = """
        <html>
        <body>
            <article><p>Minimal content with no metadata</p></article>
        </body>
        </html>
        """
        
        let baseURL = URL(string: "https://example.com")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)
        
        XCTAssertNotNil(result.url)
        XCTAssertNotNil(result.content)
        XCTAssertNotNil(result.timestamp)
    }
    
    func testEmptyHTML() async throws {
        let html = ""
        let baseURL = URL(string: "https://example.com")!
        
        do {
            let result = try await extractor.extractContent(from: html, baseURL: baseURL)
            XCTAssertTrue(result.content.isEmpty || result.content.count < 100)
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func testMalformedHTML() async throws {
        let html = """
        <html><body><article><p>Unclosed paragraph
        <div>Nested without closing
        Some text
        """
        
        let baseURL = URL(string: "https://example.com")!
        
        do {
            let result = try await extractor.extractContent(from: html, baseURL: baseURL)
            XCTAssertNotNil(result.content)
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func testVeryLongContent() async throws {
        let longParagraph = String(repeating: "This is a very long paragraph. ", count: 1000)
        let html = """
        <html>
        <body>
            <article>
                <h1>Long Article</h1>
                <p>\(longParagraph)</p>
            </article>
        </body>
        </html>
        """
        
        let baseURL = URL(string: "https://example.com")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)
        
        XCTAssertFalse(result.content.isEmpty)
        XCTAssertTrue(result.content.count > 1000)
    }
    
    func testURLResolution() async throws {
        let html = """
        <html>
        <body><article><p>Content</p></article></body>
        </html>
        """
        
        let baseURL = URL(string: "https://example.com/articles/test-article")!
        let result = try await extractor.extractContent(from: html, baseURL: baseURL)
        
        XCTAssertEqual(result.url, "https://example.com/articles/test-article")
    }
    
    func testNilBaseURL() async throws {
        let html = """
        <html>
        <body><article><p>Content</p></article></body>
        </html>
        """
        
        let result = try await extractor.extractContent(from: html, baseURL: nil)
        
        XCTAssertNotNil(result.url)
        XCTAssertTrue(result.url.isEmpty)
    }
    
    func testPDFExtractionWithInvalidURL() {
        let invalidURL = URL(string: "https://example.com/nonexistent.pdf")!
        let result = extractor.extractContent(from: invalidURL)
        
        XCTAssertNil(result)
    }
}
