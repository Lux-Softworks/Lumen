import Testing
@testable import Lumen

struct PageContentNormalizationTests {
    @Test func normalizeStripsSchemeAndWww() {
        #expect(PageContent.normalizeURL("https://www.example.com/path") == "example.com/path")
    }

    @Test func normalizeStripsTrailingSlash() {
        #expect(PageContent.normalizeURL("https://example.com/") == "example.com")
    }

    @Test func extractDomainReturnsHost() {
        #expect(PageContent.extractDomain(from: "https://example.com/page") == "example.com")
    }

    @Test func extractDomainStripsWww() {
        #expect(PageContent.extractDomain(from: "https://www.example.com") == "example.com")
    }

    @Test func extractDomainEmptyForInvalid() {
        #expect(PageContent.extractDomain(from: "notaurl") == "")
    }

    @Test func countWordsIgnoresWhitespace() {
        #expect(PageContent.countWords(in: "one  two\tthree\nfour") == 4)
    }

    @Test func countWordsEmptyString() {
        #expect(PageContent.countWords(in: "   ") == 0)
    }
}
