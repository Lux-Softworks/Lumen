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
            var scrollDepthAtFire = 0;
            var readingTimeAtFire = 0;

            var BASE_DWELL = \(config.dwellThresholdSeconds);
            var BASE_SCROLL = \(config.scrollDepthThreshold);
            var POLL_INTERVAL_MS = \(config.pollIntervalMs);

            function docHeightPx() {
                return Math.max(
                    document.body ? document.body.scrollHeight : 1,
                    document.documentElement.scrollHeight || 1,
                    1
                );
            }

            function viewportHeightPx() {
                return window.innerHeight || document.documentElement.clientHeight || 1;
            }

            function effectiveThresholds() {
                var dh = docHeightPx();
                var vh = viewportHeightPx();
                var ratio = dh / vh;
                var dwell = BASE_DWELL;
                var scroll = BASE_SCROLL;
                if (ratio < 1.4) {
                    scroll = 0.85;
                    dwell = Math.max(12, BASE_DWELL * 0.5);
                } else if (ratio < 2.5) {
                    scroll = 0.55;
                    dwell = Math.max(18, BASE_DWELL * 0.7);
                } else if (ratio > 6.0) {
                    scroll = 0.2;
                    dwell = BASE_DWELL;
                } else if (ratio > 3.5) {
                    scroll = 0.3;
                    dwell = BASE_DWELL;
                }
                return { dwell: dwell, scroll: scroll };
            }

            function updateScrollDepth() {
                var scrollTop = window.scrollY || document.documentElement.scrollTop || 0;
                var vh = viewportHeightPx();
                var dh = docHeightPx();
                var depth = (scrollTop + vh) / dh;
                if (depth > maxScrollDepth) {
                    maxScrollDepth = Math.min(depth, 1.0);
                }
            }

            function checkSelection() {
                try {
                    var sel = window.getSelection && window.getSelection();
                    if (!sel || sel.isCollapsed) return;
                    var text = sel.toString();
                    if (text && text.trim().length >= 4) {
                        hasTextSelection = true;
                    }
                } catch (_) {}
            }

            document.addEventListener('selectionchange', checkSelection);
            document.addEventListener('pointerup', checkSelection, { passive: true });
            document.addEventListener('touchend', checkSelection, { passive: true });
            document.addEventListener('mouseup', checkSelection, { passive: true });
            document.addEventListener('copy', function() { hasTextSelection = true; });

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
                checkSelection();

                var thresholds = effectiveThresholds();
                var dwellMet = dwellSeconds >= thresholds.dwell && maxScrollDepth >= thresholds.scroll;
                var longDwell = dwellSeconds >= thresholds.dwell * 2.5;

                if (dwellMet || hasTextSelection || longDwell) {
                    hasFired = true;
                    scrollDepthAtFire = maxScrollDepth;
                    readingTimeAtFire = dwellSeconds;
                    clearInterval(interval);

                    try {
                        window.webkit.messageHandlers.readingSignal.postMessage({
                            url: window.location.href,
                            title: document.title || '',
                            readingTime: dwellSeconds,
                            scrollDepth: maxScrollDepth,
                            triggered: true,
                            isUpdate: false
                        });
                    } catch (e) {}
                }
            }, POLL_INTERVAL_MS);

            document.addEventListener('visibilitychange', function() {
                if (document.visibilityState !== 'hidden') { return; }
                if (!hasFired) { return; }

                updateScrollDepth();

                var depthGrew = maxScrollDepth - scrollDepthAtFire > 0.10;
                var timeGrew = dwellSeconds - readingTimeAtFire > 30;

                if (depthGrew || timeGrew) {
                    try {
                        window.webkit.messageHandlers.readingSignal.postMessage({
                            url: window.location.href,
                            title: document.title || '',
                            readingTime: dwellSeconds,
                            scrollDepth: maxScrollDepth,
                            triggered: true,
                            isUpdate: true
                        });
                    } catch (e) {}
                }
            });
        })();
        """
    }
}
