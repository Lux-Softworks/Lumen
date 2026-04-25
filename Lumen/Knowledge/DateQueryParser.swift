import Foundation

enum DateQueryParser {
    struct Parsed {
        let range: DateInterval
        let cleanedQuery: String
        let phrase: String
    }

    static func parse(_ query: String, now: Date = Date(), calendar: Calendar = .current) -> Parsed? {
        let lower = query.lowercased()
        var cal = calendar
        cal.timeZone = TimeZone.current

        if let result = parseBetween(in: lower, query: query, now: now, calendar: cal) {
            return result
        }
        if let result = parseSince(in: lower, query: query, now: now, calendar: cal) {
            return result
        }

        if let (phrase, interval) = resolveAnchor(in: lower, now: now, calendar: cal, allowBareWeekday: false) {
            return makeParsed(query: query, phrase: phrase, range: interval)
        }
        return nil
    }

    private static func parseBetween(in lower: String, query: String, now: Date, calendar: Calendar) -> Parsed? {
        guard let regex = try? NSRegularExpression(
            pattern: #"\bbetween\s+(.+?)\s+and\s+(.+?)(?=[?.!,]|$)"#,
            options: [.caseInsensitive]
        ),
        let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
        match.numberOfRanges >= 3,
        let fullR = Range(match.range, in: lower),
        let aR = Range(match.range(at: 1), in: lower),
        let bR = Range(match.range(at: 2), in: lower) else { return nil }

        let a = String(lower[aR]).trimmingCharacters(in: .whitespaces)
        let b = String(lower[bR]).trimmingCharacters(in: .whitespaces)
        guard let aResolved = resolveAnchor(in: a, now: now, calendar: calendar, allowBareWeekday: true)?.1,
              let bResolved = resolveAnchor(in: b, now: now, calendar: calendar, allowBareWeekday: true)?.1 else {
            return nil
        }

        let start = min(aResolved.start, bResolved.start)
        let end = max(aResolved.end, bResolved.end)
        let phrase = String(lower[fullR]).trimmingCharacters(in: .whitespaces)
        return makeParsed(query: query, phrase: phrase, range: DateInterval(start: start, end: end))
    }

    private static func parseSince(in lower: String, query: String, now: Date, calendar: Calendar) -> Parsed? {
        guard let regex = try? NSRegularExpression(
            pattern: #"\bsince\s+(.+?)(?=[?.!,]|$)"#,
            options: [.caseInsensitive]
        ),
        let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
        match.numberOfRanges >= 2,
        let fullR = Range(match.range, in: lower),
        let inner = Range(match.range(at: 1), in: lower) else { return nil }

        let innerStr = String(lower[inner]).trimmingCharacters(in: .whitespaces)
        guard let (_, anchorInt) = resolveAnchor(in: innerStr, now: now, calendar: calendar, allowBareWeekday: true) else {
            return nil
        }

        let phrase = String(lower[fullR]).trimmingCharacters(in: .whitespaces)
        let interval = DateInterval(start: anchorInt.start, end: max(anchorInt.start, now))
        return makeParsed(query: query, phrase: phrase, range: interval)
    }

    private static func resolveAnchor(
        in text: String,
        now: Date,
        calendar: Calendar,
        allowBareWeekday: Bool
    ) -> (String, DateInterval)? {
        if let r = text.range(
            of: #"\b(?:past|last|previous)\s+(\d{1,3})\s+(?:days?|weeks?|months?|years?)\b"#,
            options: .regularExpression
        ),
           let interval = relativeNUnitInterval(phrase: String(text[r]), now: now, calendar: calendar) {
            return (String(text[r]), interval)
        }

        if let r = text.range(of: #"\b(?:in\s+)?q([1-4])(?:\s+(\d{4}))?\b"#, options: [.regularExpression, .caseInsensitive]) {
            let phrase = String(text[r])
            if let interval = quarterInterval(phrase: phrase, now: now, calendar: calendar) {
                return (phrase, interval)
            }
        }

        if let r = text.range(of: #"\bin\s+may(?:\s+(\d{4}))?\b"#, options: [.regularExpression, .caseInsensitive]) {
            let phrase = String(text[r])
            if let interval = monthInterval(phrase: phrase, now: now, calendar: calendar) {
                return (phrase, interval)
            }
        }

        let unambiguousMonths = monthMap.keys.filter { $0 != "may" }.sorted { $0.count > $1.count }
        let unambiguousMonthPattern = unambiguousMonths.joined(separator: "|")
        let monthRegex = #"\b(?:in\s+)?(?:\#(unambiguousMonthPattern))(?:\s+(\d{4}))?\b"#
        if let r = text.range(of: monthRegex, options: [.regularExpression, .caseInsensitive]) {
            let phrase = String(text[r])
            if let interval = monthInterval(phrase: phrase, now: now, calendar: calendar) {
                return (phrase, interval)
            }
        }

        let weekdayPattern = weekdayMap.keys.sorted { $0.count > $1.count }.joined(separator: "|")
        let modifierWeekdayRegex = #"\b(?:last|past|previous|this|on)\s+(?:\#(weekdayPattern))\b"#
        if let r = text.range(of: modifierWeekdayRegex, options: [.regularExpression, .caseInsensitive]) {
            let phrase = String(text[r])
            if let interval = weekdayInterval(phrase: phrase, now: now, calendar: calendar) {
                return (phrase, interval)
            }
        }

        if let r = text.range(of: #"\b(?:in\s+)?(?:19\d{2}|20\d{2}|21\d{2})\b"#, options: .regularExpression) {
            let phrase = String(text[r])
            if let interval = yearInterval(phrase: phrase, calendar: calendar) {
                return (phrase, interval)
            }
        }

        let candidates: [(pattern: String, build: () -> DateInterval?)] = [
            (#"\byesterday\b"#, {
                guard let y = calendar.date(byAdding: .day, value: -1, to: now) else { return nil }
                return calendar.dateInterval(of: .day, for: y)
            }),
            (#"\btoday\b"#, { calendar.dateInterval(of: .day, for: now) }),
            (#"\b(?:this|current)\s+week\b"#, { calendar.dateInterval(of: .weekOfYear, for: now) }),
            (#"\b(?:last|past|previous)\s+week\b"#, {
                guard let p = calendar.date(byAdding: .weekOfYear, value: -1, to: now) else { return nil }
                return calendar.dateInterval(of: .weekOfYear, for: p)
            }),
            (#"\b(?:this|current)\s+month\b"#, { calendar.dateInterval(of: .month, for: now) }),
            (#"\b(?:last|past|previous)\s+month\b"#, {
                guard let p = calendar.date(byAdding: .month, value: -1, to: now) else { return nil }
                return calendar.dateInterval(of: .month, for: p)
            }),
            (#"\b(?:this|current)\s+year\b"#, { calendar.dateInterval(of: .year, for: now) }),
            (#"\b(?:last|past|previous)\s+year\b"#, {
                guard let p = calendar.date(byAdding: .year, value: -1, to: now) else { return nil }
                return calendar.dateInterval(of: .year, for: p)
            }),
            (#"\brecently\b"#, {
                guard let s = calendar.date(byAdding: .day, value: -7, to: now) else { return nil }
                return DateInterval(start: s, end: now)
            }),
        ]
        for (pattern, build) in candidates {
            if let r = text.range(of: pattern, options: .regularExpression),
               let interval = build() {
                return (String(text[r]), interval)
            }
        }

        if allowBareWeekday {
            let bareWeekdayRegex = #"\b(?:\#(weekdayPattern))\b"#
            if let r = text.range(of: bareWeekdayRegex, options: [.regularExpression, .caseInsensitive]) {
                let phrase = String(text[r])
                if let interval = weekdayInterval(phrase: phrase, now: now, calendar: calendar) {
                    return (phrase, interval)
                }
            }
        }

        return nil
    }

    private static let monthMap: [String: Int] = [
        "january": 1, "jan": 1,
        "february": 2, "feb": 2,
        "march": 3, "mar": 3,
        "april": 4, "apr": 4,
        "may": 5,
        "june": 6, "jun": 6,
        "july": 7, "jul": 7,
        "august": 8, "aug": 8,
        "september": 9, "sept": 9, "sep": 9,
        "october": 10, "oct": 10,
        "november": 11, "nov": 11,
        "december": 12, "dec": 12,
    ]

    private static let weekdayMap: [String: Int] = [
        "sunday": 1, "sun": 1,
        "monday": 2, "mon": 2,
        "tuesday": 3, "tues": 3, "tue": 3,
        "wednesday": 4, "wed": 4,
        "thursday": 5, "thurs": 5, "thu": 5,
        "friday": 6, "fri": 6,
        "saturday": 7, "sat": 7,
    ]

    private static func relativeNUnitInterval(phrase: String, now: Date, calendar: Calendar) -> DateInterval? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d{1,3})\s+(days?|weeks?|months?|years?)"#) else {
            return nil
        }
        let range = NSRange(phrase.startIndex..., in: phrase)
        guard let match = regex.firstMatch(in: phrase, range: range), match.numberOfRanges >= 3,
              let nRange = Range(match.range(at: 1), in: phrase),
              let uRange = Range(match.range(at: 2), in: phrase),
              let n = Int(phrase[nRange]) else {
            return nil
        }
        let unit = String(phrase[uRange])
        let component: Calendar.Component
        if unit.hasPrefix("day") { component = .day }
        else if unit.hasPrefix("week") { component = .weekOfYear }
        else if unit.hasPrefix("month") { component = .month }
        else { component = .year }
        guard let start = calendar.date(byAdding: component, value: -max(1, n), to: now) else {
            return nil
        }
        return DateInterval(start: start, end: now)
    }

    private static func quarterInterval(phrase: String, now: Date, calendar: Calendar) -> DateInterval? {
        guard let regex = try? NSRegularExpression(pattern: #"q([1-4])(?:\s+(\d{4}))?"#, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: phrase, range: NSRange(phrase.startIndex..., in: phrase)),
              match.numberOfRanges >= 2,
              let qR = Range(match.range(at: 1), in: phrase),
              let q = Int(phrase[qR]) else { return nil }

        let curYear = calendar.component(.year, from: now)
        var year = curYear
        if match.numberOfRanges >= 3,
           let yR = Range(match.range(at: 2), in: phrase),
           let y = Int(phrase[yR]) {
            year = y
        }

        let monthsByQ = [(1, 4), (4, 7), (7, 10), (10, 13)]
        let (startMonth, nextStart) = monthsByQ[q - 1]

        var startComps = DateComponents()
        startComps.year = year
        startComps.month = startMonth
        startComps.day = 1

        var endComps = DateComponents()
        endComps.year = (nextStart == 13) ? year + 1 : year
        endComps.month = (nextStart == 13) ? 1 : nextStart
        endComps.day = 1

        guard let start = calendar.date(from: startComps),
              let end = calendar.date(from: endComps) else { return nil }
        return DateInterval(start: start, end: end)
    }

    private static func monthInterval(phrase: String, now: Date, calendar: Calendar) -> DateInterval? {
        let lowerPhrase = phrase.lowercased()
        var matchedMonth: Int?
        for (name, num) in monthMap.sorted(by: { $0.key.count > $1.key.count }) {
            if lowerPhrase.range(of: #"\b\#(name)\b"#, options: .regularExpression) != nil {
                matchedMonth = num

                break
            }
        }
        guard let monthNum = matchedMonth else { return nil }

        let curYear = calendar.component(.year, from: now)
        let curMonth = calendar.component(.month, from: now)
        var year = curMonth >= monthNum ? curYear : curYear - 1
        if let yR = lowerPhrase.range(of: #"\b(?:19\d{2}|20\d{2}|21\d{2})\b"#, options: .regularExpression),
           let y = Int(lowerPhrase[yR]) {
            year = y
        }

        var startComps = DateComponents()
        startComps.year = year
        startComps.month = monthNum
        startComps.day = 1

        guard let start = calendar.date(from: startComps),
              let interval = calendar.dateInterval(of: .month, for: start) else { return nil }
        return interval
    }

    private static func yearInterval(phrase: String, calendar: Calendar) -> DateInterval? {
        guard let yR = phrase.range(of: #"(?:19\d{2}|20\d{2}|21\d{2})"#, options: .regularExpression),
              let y = Int(phrase[yR]) else { return nil }
        var comps = DateComponents()
        comps.year = y
        comps.month = 1
        comps.day = 1

        guard let start = calendar.date(from: comps),
              let interval = calendar.dateInterval(of: .year, for: start) else { return nil }
        return interval
    }

    private static func weekdayInterval(phrase: String, now: Date, calendar: Calendar) -> DateInterval? {
        let lowerPhrase = phrase.lowercased()
        var matched: Int?
        for (name, num) in weekdayMap.sorted(by: { $0.key.count > $1.key.count }) {
            if lowerPhrase.range(of: #"\b\#(name)\b"#, options: .regularExpression) != nil {
                matched = num

                break
            }
        }
        guard let target = matched else { return nil }

        let isLastModifier = lowerPhrase.range(of: #"\b(?:last|past|previous)\b"#, options: .regularExpression) != nil
        let currentWeekday = calendar.component(.weekday, from: now)
        var diff = (currentWeekday - target + 7) % 7

        if diff == 0 && isLastModifier {
            diff = 7
        }

        guard let day = calendar.date(byAdding: .day, value: -diff, to: now) else { return nil }
        return calendar.dateInterval(of: .day, for: day)
    }

    private static func makeParsed(query: String, phrase: String, range: DateInterval) -> Parsed {
        var cleaned = query
        if let r = cleaned.range(of: phrase, options: .caseInsensitive) {
            cleaned.replaceSubrange(r, with: " ")
        }

        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: CharacterSet.whitespaces.union(.punctuationCharacters))

        return Parsed(range: range, cleanedQuery: cleaned, phrase: phrase)
    }
}
