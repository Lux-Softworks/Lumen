import Foundation
import WebKit

struct BrowserInsetScript {
    static func atDocumentStart(safeTop: Int = 0, safeBottom: Int) -> String {
        return """
            (function() {
                var style = document.getElementById('lumen-safe-area-bridge');
                if (!style) {
                    style = document.createElement('style');
                    style.id = 'lumen-safe-area-bridge';
                    document.documentElement.appendChild(style);
                }

                style.textContent = `
                    :root {
                        --lumen-safe-bottom: \(safeBottom)px;
                    }

                    [data-lumen-sticky-bottom] {
                        bottom: var(--lumen-safe-bottom) !important;
                    }

                    [data-lumen-fixed]:not([data-lumen-sticky-bottom]) {
                        position: sticky !important;
                        top: 0px !important;
                    }
                `;
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
                        var pos = window.getComputedStyle(el).position;
                        if (pos !== 'fixed' && pos !== 'sticky') continue;

                        var rect = el.getBoundingClientRect();

                        el.setAttribute('data-lumen-fixed', 'true');

                        if (!el.hasAttribute('data-lumen-sticky-bottom') &&
                            rect.bottom > window.innerHeight * 2 / 3) {
                            el.setAttribute('data-lumen-sticky-bottom', 'true');
                        }
                    }
                }

                tagElements();

                var observer = new MutationObserver(function() { tagElements(); });
                observer.observe(document.documentElement, {
                    childList: true,
                    subtree: true,
                    attributes: true,
                    attributeFilter: ['style', 'class']
                });

                setTimeout(tagElements, 500);
                setTimeout(tagElements, 1500);
            })();
            """
    }

    static func update(safeTop: Int = 0, safeBottom: Int) -> String {
        return """
            (function() {
                document.documentElement.style.setProperty('--lumen-safe-bottom', '\(safeBottom)px');
            })();
            """
    }
}
