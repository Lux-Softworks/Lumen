import Foundation

enum ReadingSignalScript {
    static func makeScript(config: ReadingSignalConfig = .default) -> String {
        """
        (function() {
            if (window.__lumenReadingSignalInstalled) { return; }
            window.__lumenReadingSignalInstalled = true;

            var hasFired = false;
            var dwellSeconds = 0;
            var maxScrollDepth = 0;
            var hasTextSelection = false;

            var DWELL_THRESHOLD = \(config.dwellThresholdSeconds);
            var SCROLL_THRESHOLD = \(config.scrollDepthThreshold);
            var POLL_INTERVAL_MS = \(config.pollIntervalMs);

            function updateScrollDepth() {
                var scrollTop = window.scrollY || document.documentElement.scrollTop || 0;
                var windowHeight = window.innerHeight || 1;
                var docHeight = Math.max(
                    document.body ? document.body.scrollHeight : 1,
                    document.documentElement.scrollHeight || 1,
                    1
                );
                var depth = (scrollTop + windowHeight) / docHeight;
                if (depth > maxScrollDepth) {
                    maxScrollDepth = Math.min(depth, 1.0);
                }
            }

            document.addEventListener('selectionchange', function() {
                var selection = window.getSelection();
                if (selection && selection.toString().length > 0) {
                    hasTextSelection = true;
                }
            });

            window.addEventListener('scroll', updateScrollDepth, { passive: true });
            updateScrollDepth();

            var interval = setInterval(function() {
                if (hasFired) {
                    clearInterval(interval);
                    return;
                }

                if (document.visibilityState === 'visible') {
                    dwellSeconds += POLL_INTERVAL_MS / 1000;
                }

                updateScrollDepth();

                var dwellMet = dwellSeconds >= DWELL_THRESHOLD && maxScrollDepth >= SCROLL_THRESHOLD;

                if (dwellMet || hasTextSelection) {
                    hasFired = true;
                    clearInterval(interval);

                    try {
                        window.webkit.messageHandlers.readingSignal.postMessage({
                            url: window.location.href,
                            title: document.title || '',
                            readingTime: dwellSeconds,
                            scrollDepth: maxScrollDepth,
                            triggered: true
                        });
                    } catch (e) {}
                }
            }, POLL_INTERVAL_MS);
        })();
        """
    }
}
