import Foundation
import WebKit

struct BrowserInsetScript {
    static func atDocumentStart(safeTop: Int, safeBottom: Int) -> String {
        return """
            (function() {
                var style = document.getElementById('lumen-safe-area-bridge');
                if (!style) {
                    style = document.createElement('style');
                    style.id = 'lumen-safe-area-bridge';
                    document.documentElement.appendChild(style);
                }

                var css = `
                    :root {
                        --lumen-safe-top: \(safeTop)px;
                        --lumen-safe-bottom: \(safeBottom)px;
                    }

                    [data-lumen-sticky-top] {
                        transform: translateY(var(--lumen-safe-top)) !important;
                    }

                    [data-lumen-sticky-bottom] {
                        transform: translateY(calc(-1 * var(--lumen-safe-bottom))) !important;
                    }
                `;
                style.textContent = css;

                var meta = document.querySelector('meta[name="viewport"]');
                if (meta) {
                    var content = meta.getAttribute('content');
                    if (!content.includes('viewport-fit=cover')) {
                        meta.setAttribute('content', content + ', viewport-fit=cover');
                    }
                } else {
                    meta = document.createElement('meta');
                    meta.name = 'viewport';
                    meta.content = 'width=device-width, initial-scale=1, viewport-fit=cover';
                    document.head.appendChild(meta);
                }
            })();
            """
    }

    static var atDocumentEnd: String {
        return """
            (function() {
                function tagElements() {
                    var all = document.querySelectorAll('*');
                    for (var i = 0; i < all.length; i++) {
                        var el = all[i];

                        var s = window.getComputedStyle(el);
                        var pos = s.position;

                        if (pos === 'fixed' || pos === 'sticky') {
                            var rect = el.getBoundingClientRect();

                            if (rect.top < window.innerHeight / 3) {
                                if (!el.hasAttribute('data-lumen-sticky-top')) {
                                    el.setAttribute('data-lumen-sticky-top', 'true');
                                }
                            } else if (rect.bottom > (window.innerHeight * 2/3)) {
                                if (!el.hasAttribute('data-lumen-sticky-bottom')) {
                                    el.setAttribute('data-lumen-sticky-bottom', 'true');
                                }
                            }
                        }
                    }
                }

                tagElements();

                var observer = new MutationObserver(function(mutations) {
                    tagElements();
                });

                observer.observe(document.documentElement, {
                    childList: true,
                    subtree: true,
                    attributes: true,
                    attributeFilter: ['style', 'class']
                });

                // Backup intervals for very dynamic sites
                setTimeout(tagElements, 500);
                setTimeout(tagElements, 1500);
            })();
            """
    }

    static func update(safeTop: Int, safeBottom: Int) -> String {
        return """
            (function() {
                var root = document.documentElement;
                root.style.setProperty('--lumen-safe-top', '\(safeTop)px');
                root.style.setProperty('--lumen-safe-bottom', '\(safeBottom)px');

                var bridge = document.getElementById('lumen-safe-area-bridge');
                if (bridge) {
                    var css = bridge.textContent;
                    css = css.replace(/--lumen-safe-top: [^;]+;/, '--lumen-safe-top: \(safeTop)px;');
                    css = css.replace(/--lumen-safe-bottom: [^;]+;/, '--lumen-safe-bottom: \(safeBottom)px;');
                    bridge.textContent = css;
                }
            })();
            """
    }
}
