import Foundation
import Testing
@testable import Lumen

@MainActor
struct SearchSuggestionURLTests {
    @Test func googleSuggestionsGoToGoogle() {
        let url = SearchEngine.google.suggestionURL(for: "swift ui")

        #expect(url?.absoluteString == "https://suggestqueries.google.com/complete/search?client=firefox&q=swift%20ui")
    }

    @Test func duckDuckGoSuggestionsGoToDuckDuckGo() {
        let url = SearchEngine.duckDuckGo.suggestionURL(for: "swift ui")

        #expect(url?.absoluteString == "https://duckduckgo.com/ac/?q=swift%20ui&type=list")
    }

    @Test func bingSuggestionsGoToBing() {
        let url = SearchEngine.bing.suggestionURL(for: "swift ui")

        #expect(url?.absoluteString == "https://api.bing.com/osjson.aspx?query=swift%20ui")
    }

    @Test func braveSuggestionsGoToBrave() {
        let url = SearchEngine.brave.suggestionURL(for: "swift ui")

        #expect(url?.absoluteString == "https://search.brave.com/api/suggest?q=swift%20ui")
    }

    @Test func ampersandAndPlusInQueryAreEscaped() {
        let url = SearchEngine.bing.suggestionURL(for: "c++ & rust")

        #expect(url?.absoluteString == "https://api.bing.com/osjson.aspx?query=c%2B%2B%20%26%20rust")
    }

    @Test func requestUsesChosenEngine() {
        let url = SearchSuggestionService.requestURL(
            for: "swift", engine: .brave, isIncognito: false, isEnabled: true
        )

        #expect(url?.host == "search.brave.com")
    }

    @Test func incognitoNeverRequestsSuggestions() {
        let url = SearchSuggestionService.requestURL(
            for: "swift", engine: .google, isIncognito: true, isEnabled: true
        )

        #expect(url == nil)
    }

    @Test func disabledSettingNeverRequestsSuggestions() {
        let url = SearchSuggestionService.requestURL(
            for: "swift", engine: .google, isIncognito: false, isEnabled: false
        )

        #expect(url == nil)
    }

    @Test func blankQueryNeverRequestsSuggestions() {
        let url = SearchSuggestionService.requestURL(
            for: "   ", engine: .google, isIncognito: false, isEnabled: true
        )

        #expect(url == nil)
    }
}

@MainActor
struct SearchSuggestionParsingTests {
    @Test func parsesGoogleResponse() {
        let body = #"["swift ui",["swift ui","swift ui tutorial"],[],{"google:suggestsubtypes":[[512,433],[512]]}]"#

        let suggestions = SearchSuggestionService.parseSuggestions(from: Data(body.utf8))

        #expect(suggestions.map(\.text) == ["swift ui", "swift ui tutorial"])
    }

    @Test func parsesDuckDuckGoListResponse() {
        let body = #"["swift ui",["swift ui","swift ui windows","swift uikit"]]"#

        let suggestions = SearchSuggestionService.parseSuggestions(from: Data(body.utf8))

        #expect(suggestions.map(\.text) == ["swift ui", "swift ui windows", "swift uikit"])
    }

    @Test func parsesBingResponse() {
        let body = #"["swift ui",["swift ui","swift ui tutorial","swift uikit"]]"#

        let suggestions = SearchSuggestionService.parseSuggestions(from: Data(body.utf8))

        #expect(suggestions.map(\.text) == ["swift ui", "swift ui tutorial", "swift uikit"])
    }

    @Test func parsesBraveResponse() {
        let body = #"["swift ui",["swiftui","swiftui tutorial"]]"#

        let suggestions = SearchSuggestionService.parseSuggestions(from: Data(body.utf8))

        #expect(suggestions.map(\.text) == ["swiftui", "swiftui tutorial"])
    }

    @Test func keepsAtMostFiveSuggestions() {
        let body = #"["a",["a1","a2","a3","a4","a5","a6","a7"]]"#

        let suggestions = SearchSuggestionService.parseSuggestions(from: Data(body.utf8))

        #expect(suggestions.count == 5)
    }

    @Test func malformedResponseGivesNoSuggestions() {
        let body = #"{"error":"rate limited"}"#

        let suggestions = SearchSuggestionService.parseSuggestions(from: Data(body.utf8))

        #expect(suggestions.isEmpty)
    }
}
