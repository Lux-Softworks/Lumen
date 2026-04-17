import Foundation

enum AnnotationScript {
    static let captureJS: String = """
        (function() {
            if (window.__lumenAnnotInstalled) return;
            window.__lumenAnnotInstalled = true;

            const CTX_LEN = 60;

            window.__lumenCaptureHighlight = function() {
                const sel = window.getSelection();
                if (!sel || sel.rangeCount === 0 || sel.isCollapsed) return;
                const text = sel.toString().trim();
                if (text.length < 3) return;

                const full = document.body.innerText || '';
                const idx = full.indexOf(text);
                let prefix = '';
                let suffix = '';
                if (idx >= 0) {
                    prefix = full.substring(Math.max(0, idx - CTX_LEN), idx);
                    suffix = full.substring(idx + text.length, idx + text.length + CTX_LEN);
                }

                try {
                    window.webkit.messageHandlers.annotation.postMessage({
                        action: 'create',
                        url: window.location.href,
                        text: text,
                        prefix: prefix,
                        suffix: suffix
                    });
                } catch (_) {}

                sel.removeAllRanges();
            };
        })();
        """

    static func applyJS(annotations: [[String: String]]) -> String {
        let json: String
        if let data = try? JSONSerialization.data(withJSONObject: annotations),
           let str = String(data: data, encoding: .utf8) {
            json = str
        } else {
            json = "[]"
        }

        return """
            (function() {
                const items = \(json);
                const MARK_ATTR = 'data-lumen-annot';

                document.querySelectorAll('mark['+MARK_ATTR+']').forEach(el => {
                    const parent = el.parentNode;
                    while (el.firstChild) parent.insertBefore(el.firstChild, el);
                    parent.removeChild(el);
                    parent.normalize();
                });

                function wrapRange(range, id) {
                    const mark = document.createElement('mark');
                    mark.setAttribute(MARK_ATTR, id);
                    mark.style.cssText = 'background:rgba(255,214,102,0.45);color:inherit;padding:0;border-radius:2px;';
                    try { range.surroundContents(mark); return true; }
                    catch (_) {
                        const frag = range.extractContents();
                        mark.appendChild(frag);
                        range.insertNode(mark);
                        return true;
                    }
                }

                function findRangeFor(item) {
                    const text = item.text;
                    if (!text || text.length < 2) return null;
                    const walker = document.createTreeWalker(
                        document.body, NodeFilter.SHOW_TEXT,
                        { acceptNode: (n) => {
                            if (!n.parentElement) return NodeFilter.FILTER_REJECT;
                            const tag = n.parentElement.tagName;
                            if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'NOSCRIPT') return NodeFilter.FILTER_REJECT;
                            return NodeFilter.FILTER_ACCEPT;
                        }}
                    );
                    const nodes = [];
                    let full = '';
                    while (walker.nextNode()) {
                        const n = walker.currentNode;
                        nodes.push({ node: n, start: full.length });
                        full += n.nodeValue;
                    }

                    const prefix = item.prefix || '';
                    const suffix = item.suffix || '';
                    let searchFrom = 0;
                    let best = -1;
                    while (true) {
                        const idx = full.indexOf(text, searchFrom);
                        if (idx < 0) break;
                        const before = full.substring(Math.max(0, idx - prefix.length), idx);
                        const after = full.substring(idx + text.length, idx + text.length + suffix.length);
                        if ((!prefix || before.endsWith(prefix.slice(-20))) &&
                            (!suffix || after.startsWith(suffix.slice(0, 20)))) {
                            best = idx; break;
                        }
                        if (best < 0) best = idx;
                        searchFrom = idx + 1;
                    }
                    if (best < 0) return null;

                    let startNode = null, startOffset = 0, endNode = null, endOffset = 0;
                    for (const entry of nodes) {
                        const endIdx = entry.start + entry.node.nodeValue.length;
                        if (startNode === null && best >= entry.start && best < endIdx) {
                            startNode = entry.node;
                            startOffset = best - entry.start;
                        }
                        const endPos = best + text.length;
                        if (endPos > entry.start && endPos <= endIdx) {
                            endNode = entry.node;
                            endOffset = endPos - entry.start;
                            break;
                        }
                    }
                    if (!startNode || !endNode) return null;

                    const range = document.createRange();
                    try {
                        range.setStart(startNode, startOffset);
                        range.setEnd(endNode, endOffset);
                        return range;
                    } catch (_) { return null; }
                }

                for (const item of items) {
                    const range = findRangeFor(item);
                    if (range) wrapRange(range, item.id);
                }
            })();
            """
    }
}
