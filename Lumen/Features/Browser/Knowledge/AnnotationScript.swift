import Foundation

enum AnnotationScript {
    private static let sharedHelpers: String = """
        function __lumenIsSpaceCode(c) {
            return c === 32 || c === 9 || c === 10 || c === 13 || c === 11 || c === 12 || c === 0xa0 || c === 0x2028 || c === 0x2029;
        }

        function __lumenNormalizeText(s) {
            if (!s) return '';
            let out = '';
            let prevSpace = false;
            for (let i = 0; i < s.length; i++) {
                const c = s.charCodeAt(i);
                if (__lumenIsSpaceCode(c)) {
                    if (!prevSpace && out.length > 0) out += ' ';
                    prevSpace = true;
                } else {
                    out += s[i];
                    prevSpace = false;
                }
            }
            while (out.endsWith(' ')) out = out.slice(0, -1);
            return out;
        }

        function __lumenBuildHaystack() {
            const walker = document.createTreeWalker(
                document.body, NodeFilter.SHOW_TEXT,
                { acceptNode: function(n) {
                    if (!n.parentElement) return NodeFilter.FILTER_REJECT;
                    const tag = n.parentElement.tagName;
                    if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'NOSCRIPT' || tag === 'TEMPLATE') return NodeFilter.FILTER_REJECT;
                    try {
                        const cs = window.getComputedStyle(n.parentElement);
                        if (cs && (cs.display === 'none' || cs.visibility === 'hidden')) return NodeFilter.FILTER_REJECT;
                    } catch (_) {}
                    return NodeFilter.FILTER_ACCEPT;
                }}
            );
            const segments = [];
            let normalized = '';
            let prevSpace = true;
            while (walker.nextNode()) {
                const node = walker.currentNode;
                const v = node.nodeValue || '';
                const segNormStart = normalized.length;
                const charMap = [];
                for (let i = 0; i < v.length; i++) {
                    const c = v.charCodeAt(i);
                    if (__lumenIsSpaceCode(c)) {
                        if (!prevSpace) {
                            normalized += ' ';
                            charMap.push(i);
                            prevSpace = true;
                        }
                    } else {
                        normalized += v[i];
                        charMap.push(i);
                        prevSpace = false;
                    }
                }
                segments.push({
                    node: node,
                    rawLength: v.length,
                    normStart: segNormStart,
                    normEnd: normalized.length,
                    charMap: charMap
                });
            }
            while (normalized.endsWith(' ')) {
                normalized = normalized.slice(0, -1);
                if (segments.length > 0) {
                    const last = segments[segments.length - 1];
                    if (last.charMap.length > 0 && last.normEnd > normalized.length) {
                        last.charMap.pop();
                        last.normEnd = normalized.length;
                    }
                }
            }
            return { normalized: normalized, segments: segments };
        }

        function __lumenLocateOffset(segments, normIdx, atEnd) {
            for (let s = 0; s < segments.length; s++) {
                const seg = segments[s];
                if (normIdx >= seg.normStart && normIdx < seg.normEnd) {
                    const local = normIdx - seg.normStart;
                    return { node: seg.node, offset: seg.charMap[local] };
                }
                if (normIdx === seg.normEnd) {
                    if (atEnd) {
                        if (seg.charMap.length > 0) {
                            const lastLocal = seg.charMap[seg.charMap.length - 1];
                            return { node: seg.node, offset: lastLocal + 1 };
                        }
                        return { node: seg.node, offset: seg.rawLength };
                    } else if (s + 1 < segments.length) {
                        const next = segments[s + 1];
                        if (next.charMap.length > 0) {
                            return { node: next.node, offset: next.charMap[0] };
                        }
                    } else {
                        if (seg.charMap.length > 0) {
                            const lastLocal = seg.charMap[seg.charMap.length - 1];
                            return { node: seg.node, offset: lastLocal + 1 };
                        }
                        return { node: seg.node, offset: seg.rawLength };
                    }
                }
            }
            return null;
        }
        """

    static let captureJS: String = """
        (function() {
            if (window.__lumenAnnotInstalled) return;
            window.__lumenAnnotInstalled = true;

            const CTX_LEN = 60;

            \(sharedHelpers)

            window.__lumenCaptureHighlight = function() {
                const sel = window.getSelection();
                if (!sel || sel.rangeCount === 0 || sel.isCollapsed) return;
                const rawText = sel.toString();
                const text = __lumenNormalizeText(rawText);
                if (text.length < 3) return;

                let prefix = '';
                let suffix = '';
                try {
                    const built = __lumenBuildHaystack();
                    const full = built.normalized;
                    const idx = full.indexOf(text);
                    if (idx >= 0) {
                        prefix = full.substring(Math.max(0, idx - CTX_LEN), idx);
                        suffix = full.substring(idx + text.length, idx + text.length + CTX_LEN);
                    }
                } catch (_) {}

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

                document.querySelectorAll('mark['+MARK_ATTR+']').forEach(function(el) {
                    const parent = el.parentNode;
                    while (el.firstChild) parent.insertBefore(el.firstChild, el);
                    parent.removeChild(el);
                    parent.normalize();
                });

                \(sharedHelpers)

                function requestDelete(mark, id) {
                    const rect = mark.getBoundingClientRect();
                    try {
                        window.webkit.messageHandlers.annotation.postMessage({
                            action: 'request-delete',
                            id: id,
                            url: window.location.href,
                            x: rect.left,
                            y: rect.top,
                            w: rect.width,
                            h: rect.height
                        });
                    } catch (_) {}
                }

                function attachClick(mark, id) {
                    mark.addEventListener('click', function(e) {
                        const sel = window.getSelection();
                        if (sel && !sel.isCollapsed && sel.toString().length > 0) return;
                        e.preventDefault();
                        e.stopPropagation();
                        requestDelete(mark, id);
                    }, true);
                }

                function styleMark(mark, id) {
                    mark.setAttribute(MARK_ATTR, id);
                    mark.style.cssText = 'background:rgba(255,214,102,0.45);color:inherit;padding:0;border-radius:2px;cursor:pointer;';
                }

                function wrapRangeCleanly(range, id) {
                    try {
                        const mark = document.createElement('mark');
                        styleMark(mark, id);
                        range.surroundContents(mark);
                        attachClick(mark, id);
                        return true;
                    } catch (_) {
                        return wrapRangeAcrossElements(range, id);
                    }
                }

                function wrapRangeAcrossElements(range, id) {
                    try {
                        const allMarks = [];
                        const startContainer = range.startContainer;
                        const endContainer = range.endContainer;
                        const startOffset = range.startOffset;
                        const endOffset = range.endOffset;

                        const walker = document.createTreeWalker(
                            range.commonAncestorContainer,
                            NodeFilter.SHOW_TEXT,
                            { acceptNode: function(n) {
                                if (!n.parentElement) return NodeFilter.FILTER_REJECT;
                                const tag = n.parentElement.tagName;
                                if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'NOSCRIPT' || tag === 'TEMPLATE') return NodeFilter.FILTER_REJECT;
                                if (!range.intersectsNode(n)) return NodeFilter.FILTER_REJECT;
                                return NodeFilter.FILTER_ACCEPT;
                            }}
                        );

                        const textNodes = [];
                        while (walker.nextNode()) {
                            textNodes.push(walker.currentNode);
                        }

                        for (const tn of textNodes) {
                            const v = tn.nodeValue || '';
                            let from = 0;
                            let to = v.length;
                            if (tn === startContainer) from = startOffset;
                            if (tn === endContainer) to = endOffset;
                            if (from >= to) continue;

                            const before = v.substring(0, from);
                            const middle = v.substring(from, to);
                            const after = v.substring(to);

                            const parent = tn.parentNode;
                            if (!parent) continue;

                            const mark = document.createElement('mark');
                            styleMark(mark, id);
                            mark.appendChild(document.createTextNode(middle));

                            const beforeNode = before.length > 0 ? document.createTextNode(before) : null;
                            const afterNode = after.length > 0 ? document.createTextNode(after) : null;

                            if (beforeNode) parent.insertBefore(beforeNode, tn);
                            parent.insertBefore(mark, tn);
                            if (afterNode) parent.insertBefore(afterNode, tn);
                            parent.removeChild(tn);

                            attachClick(mark, id);
                            allMarks.push(mark);
                        }
                        return allMarks.length > 0;
                    } catch (_) { return false; }
                }

                function findAndApply(item, haystack) {
                    const rawText = item.text || '';
                    const itemText = __lumenNormalizeText(rawText);
                    if (itemText.length < 2) return false;

                    const itemPrefix = __lumenNormalizeText(item.prefix || '');
                    const itemSuffix = __lumenNormalizeText(item.suffix || '');
                    const full = haystack.normalized;

                    let best = -1;
                    let searchFrom = 0;
                    const PFX_WIN = 20;
                    while (true) {
                        const idx = full.indexOf(itemText, searchFrom);
                        if (idx < 0) break;
                        const before = full.substring(Math.max(0, idx - itemPrefix.length), idx);
                        const after = full.substring(idx + itemText.length, idx + itemText.length + itemSuffix.length);
                        const prefixOK = !itemPrefix || before.endsWith(itemPrefix.slice(-PFX_WIN));
                        const suffixOK = !itemSuffix || after.startsWith(itemSuffix.slice(0, PFX_WIN));
                        if (prefixOK && suffixOK) { best = idx; break; }
                        if (best < 0) best = idx;
                        searchFrom = idx + 1;
                    }
                    if (best < 0) return false;

                    const startInfo = __lumenLocateOffset(haystack.segments, best, false);
                    const endInfo = __lumenLocateOffset(haystack.segments, best + itemText.length, true);
                    if (!startInfo || !endInfo) return false;

                    const range = document.createRange();
                    try {
                        range.setStart(startInfo.node, startInfo.offset);
                        range.setEnd(endInfo.node, endInfo.offset);
                    } catch (_) { return false; }

                    return wrapRangeCleanly(range, item.id);
                }

                if (items.length === 0) return;
                const haystack = __lumenBuildHaystack();
                for (const item of items) {
                    findAndApply(item, haystack);
                }
            })();
            """
    }
}
