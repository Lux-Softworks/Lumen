import Foundation
import WebKit

enum TrackerScanScript {
    static let handlerName = "trackerScan"

    static let source = """
        (function() {
            if (window.__lumenTrackerScan) { return; }
            window.__lumenTrackerScan = true;

            var selector = 'script[src],img[src],iframe[src],frame[src],link[href],source[src],video[src],audio[src],embed[src],object[data]';
            var reported = new Set();
            var queue = [];
            var timer = null;

            function flush() {
                timer = null;
                if (queue.length === 0) { return; }
                var batch = queue.splice(0, 500);
                try { window.webkit.messageHandlers.\(handlerName).postMessage({ urls: batch }); } catch (_) {}
                if (queue.length > 0) { schedule(); }
            }

            function schedule() {
                if (timer === null) { timer = setTimeout(flush, 300); }
            }

            function note(value) {
                if (typeof value !== 'string' || value.indexOf('http') !== 0) { return; }
                if (reported.has(value) || reported.size >= 5000) { return; }
                reported.add(value);
                queue.push(value);
                schedule();
            }

            function collect(element) {
                note(element.src || element.href || element.data);
            }

            function scan(root) {
                if (root.matches && root.matches(selector)) { collect(root); }
                if (root.querySelectorAll) { root.querySelectorAll(selector).forEach(collect); }
            }

            scan(document);

            new MutationObserver(function(mutations) {
                mutations.forEach(function(mutation) {
                    if (mutation.type === 'attributes') {
                        if (mutation.target.matches && mutation.target.matches(selector)) { collect(mutation.target); }
                        return;
                    }
                    mutation.addedNodes.forEach(function(node) {
                        if (node.nodeType === 1) { scan(node); }
                    });
                });
            }).observe(document.documentElement, {
                childList: true,
                subtree: true,
                attributes: true,
                attributeFilter: ['src', 'href', 'data']
            });
        })();
        """
}

final class TrackerScanMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        guard message.name == TrackerScanScript.handlerName,
            let body = message.body as? [String: Any],
            let urlStrings = body["urls"] as? [String],
            let interceptor = message.webView?.navigationDelegate as? NetworkInterceptor
        else {
            return
        }

        interceptor.recordResourceURLs(urlStrings.compactMap(URL.init(string:)))
    }
}
