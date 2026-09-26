import Foundation
import JavaScriptCore
import Testing
@testable import Lumen

@MainActor
struct ReadingSignalScriptTests {
    @Test func firstReadEventPostsOnceWhilePollingContinues() throws {
        let page = try ReadingSignalPage()

        page.tick(40)

        #expect(page.postedMessages.count == 1)
    }

    @Test func dwellGrowthPastThirtySecondsAfterFirstReadPostsUpdateOnHide() throws {
        let page = try ReadingSignalPage()

        page.tick(8)
        page.tick(21)
        page.hide()

        #expect(page.postedMessages.count == 2)
        #expect(page.postedMessages.last?["isUpdate"] as? Bool == true)
    }

    @Test func secondHideWithoutFurtherGrowthPostsNoSecondUpdate() throws {
        let page = try ReadingSignalPage()

        page.tick(8)
        page.tick(21)
        page.hide()
        page.show()
        page.hide()

        #expect(page.postedMessages.count == 2)
    }

    @Test func pageHiddenAfterFractionalDwellStillReachesCapture() throws {
        let page = try ReadingSignalPage()
        page.tick(3)
        page.hide()
        let body = try #require(page.postedMessages.first)
        let handler = ReadingSignalHandler()
        var capturedURL: String?
        handler.onReadingSignalTriggered = { payload, _ in capturedURL = payload.url }

        handler.process(body: body, webView: nil)

        #expect(capturedURL == "https://example.com/article")
    }
}

@MainActor
private struct ReadingSignalPage {
    private static let pageStubs = """
        var __posted = [];
        var __intervals = [];
        var __listeners = {};
        function __addListener(type, callback) {
            (__listeners[type] = __listeners[type] || []).push(callback);
        }
        var document = {
            visibilityState: 'visible',
            title: 'Article',
            body: { scrollHeight: 3000 },
            documentElement: { scrollHeight: 3000, scrollTop: 0, clientHeight: 1000 },
            addEventListener: __addListener
        };
        var window = {
            innerHeight: 1000,
            scrollY: 0,
            location: { href: 'https://example.com/article' },
            addEventListener: __addListener,
            getSelection: function() { return null; },
            webkit: { messageHandlers: { readingSignal: { postMessage: function(message) { __posted.push(message); } } } }
        };
        function setInterval(callback) {
            __intervals.push({ callback: callback, active: true });
            return __intervals.length - 1;
        }
        function clearInterval(id) { __intervals[id].active = false; }
        function __tick(count) {
            for (var step = 0; step < count; step++) {
                __intervals.forEach(function(entry) { if (entry.active) { entry.callback(); } });
            }
        }
        function __setVisibility(state) {
            document.visibilityState = state;
            (__listeners['visibilitychange'] || []).forEach(function(callback) { callback(); });
        }
        """

    private let context: JSContext

    init() throws {
        let context = try #require(JSContext())
        context.exceptionHandler = { _, exception in
            Issue.record("JavaScript error: \(exception?.toString() ?? "unknown")")
        }
        context.evaluateScript(Self.pageStubs)
        context.evaluateScript(ReadingSignalScript.makeScript())
        self.context = context
    }

    var postedMessages: [[String: Any]] {
        (context.objectForKeyedSubscript("__posted").toArray() as? [[String: Any]]) ?? []
    }

    func tick(_ count: Int) {
        context.evaluateScript("__tick(\(count))")
    }

    func hide() {
        context.evaluateScript("__setVisibility('hidden')")
    }

    func show() {
        context.evaluateScript("__setVisibility('visible')")
    }
}
