import Foundation

nonisolated enum MarkdownVaultWriter {
    static func write(
        payload: ExportPayload,
        toggles: ExportCoordinator.Request.Toggles,
        into vaultDir: URL,
        onProgress: (Int, Int) -> Void,
        shouldCancel: () -> Bool
    ) throws {
        let topicsDir = vaultDir.appendingPathComponent("Topics")
        let sitesDir = vaultDir.appendingPathComponent("Sites")
        let pagesDir = vaultDir.appendingPathComponent("Pages")
        try FileManager.default.createDirectory(at: topicsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sitesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: pagesDir, withIntermediateDirectories: true)

        let filenamesByPageID = precomputeFilenames(pages: payload.pages)

        try writeReadme(into: vaultDir, payload: payload)
        try writeTopics(into: topicsDir, payload: payload, toggles: toggles)
        try writeSites(into: sitesDir, payload: payload, toggles: toggles, filenamesByPageID: filenamesByPageID)
        try writePages(
            into: pagesDir,
            payload: payload,
            toggles: toggles,
            filenamesByPageID: filenamesByPageID,
            onProgress: onProgress,
            shouldCancel: shouldCancel
        )
    }

    private static func precomputeFilenames(pages: [PageContent]) -> [String: String] {
        var result: [String: String] = [:]
        var usedPerDomain: [String: Set<String>] = [:]
        for page in pages {
            let domain = page.domain.isEmpty ? "unknown" : page.domain
            var set = usedPerDomain[domain] ?? []
            let name = allocateFilename(for: page, existing: &set)
            usedPerDomain[domain] = set
            result[page.id] = name
        }
        return result
    }

    private static func allocateFilename(for page: PageContent, existing: inout Set<String>) -> String {
        let date = DateFormatters.ymd.string(from: page.timestamp)
        let titleSeed = page.displayTitle
        let base = "\(date)-\(slug(titleSeed))"
        var candidate = base
        var suffix = 2
        while existing.contains(candidate) {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }
        existing.insert(candidate)

        return candidate + ".md"
    }

    private static func writeReadme(into dir: URL, payload: ExportPayload) throws {
        var lines: [String] = []
        lines.append("# Lumen Knowledge Export")
        lines.append("")
        lines.append("\(payload.pages.count) pages · \(payload.websites.count) sites · \(payload.topics.count) topics")
        lines.append("")

        if !payload.topics.isEmpty {
            lines.append("## Topics")
            lines.append("")
            for topic in payload.topics.sorted(by: { $0.name < $1.name }) {
                let slugName = slug(topic.name)
                lines.append("- [[Topics/\(slugName)|\(topic.name)]]")
            }
            lines.append("")
        }

        let readme = lines.joined(separator: "\n")
        try readme.data(using: .utf8)?.write(to: dir.appendingPathComponent("README.md"), options: .atomic)
    }

    private static func writeTopics(
        into dir: URL,
        payload: ExportPayload,
        toggles: ExportCoordinator.Request.Toggles
    ) throws {
        for topic in payload.topics {
            var lines: [String] = []
            lines.append("---")
            lines.append("name: \(yamlEscape(topic.name))")

            if let color = topic.color { lines.append("color: \(yamlEscape(color))") }
            lines.append("website_count: \(topic.websiteCount)")
            if toggles.includeTimestamps {
                lines.append("created_at: \(iso(topic.createdAt))")
            }

            lines.append("---")
            lines.append("")
            lines.append("# \(topic.name)")
            lines.append("")

            let sites = payload.websites.filter { $0.topicID == topic.id }
            if !sites.isEmpty {
                lines.append("## Sites")
                lines.append("")
                for site in sites.sorted(by: { $0.displayName < $1.displayName }) {
                    lines.append("- [[Sites/\(slug(site.domain))|\(site.displayName)]]")
                }
            }

            let body = lines.joined(separator: "\n")
            let filename = slug(topic.name) + ".md"
            try body.data(using: .utf8)?.write(to: dir.appendingPathComponent(filename), options: .atomic)
        }
    }

    private static func writeSites(
        into dir: URL,
        payload: ExportPayload,
        toggles: ExportCoordinator.Request.Toggles,
        filenamesByPageID: [String: String]
    ) throws {
        let topicByID = Dictionary(uniqueKeysWithValues: payload.topics.map { ($0.id, $0) })

        for site in payload.websites {
            var lines: [String] = []
            lines.append("---")
            lines.append("domain: \(yamlEscape(site.domain))")
            lines.append("display_name: \(yamlEscape(site.displayName))")
            if let tID = site.topicID, let topic = topicByID[tID] {
                lines.append("topic: \(yamlEscape(topic.name))")
            }

            lines.append("page_count: \(site.pageCount)")
            lines.append("total_words: \(site.totalWords)")
            if toggles.includeTimestamps {
                lines.append("first_visit: \(iso(site.firstVisit))")
                lines.append("last_visit: \(iso(site.lastVisit))")
            }

            lines.append("---")
            lines.append("")
            lines.append("# \(site.displayName)")
            lines.append("")

            if toggles.includeAISummaries, let summary = site.summary, !summary.isEmpty {
                lines.append(summary)
                lines.append("")
            }

            let pages = payload.pages.filter { $0.websiteID == site.id }
            if !pages.isEmpty {
                lines.append("## Pages")
                lines.append("")

                for page in pages.sorted(by: { $0.timestamp > $1.timestamp }) {
                    guard let fname = filenamesByPageID[page.id] else { continue }
                    let label = page.displayTitle
                    let stem = String(fname.dropLast(3))
                    lines.append("- [[Pages/\(slug(site.domain))/\(stem)|\(label)]]")
                }
            }

            let body = lines.joined(separator: "\n")
            let filename = slug(site.domain) + ".md"
            try body.data(using: .utf8)?.write(to: dir.appendingPathComponent(filename), options: .atomic)
        }
    }

    private static func writePages(
        into dir: URL,
        payload: ExportPayload,
        toggles: ExportCoordinator.Request.Toggles,
        filenamesByPageID: [String: String],
        onProgress: (Int, Int) -> Void,
        shouldCancel: () -> Bool
    ) throws {
        let total = payload.pages.count
        let topicByID = Dictionary(uniqueKeysWithValues: payload.topics.map { ($0.id, $0) })
        let siteByID = Dictionary(uniqueKeysWithValues: payload.websites.map { ($0.id, $0) })
        let annotationsByPageID: [String: [Annotation]] = Dictionary(grouping: payload.annotations, by: { $0.pageID ?? "" })

        for (index, page) in payload.pages.enumerated() {
            if shouldCancel() { throw CancellationError() }

            let domain = page.domain.isEmpty ? "unknown" : page.domain
            let domainDir = dir.appendingPathComponent(slug(domain))
            try FileManager.default.createDirectory(at: domainDir, withIntermediateDirectories: true)

            guard let filename = filenamesByPageID[page.id] else { continue }

            let site = siteByID[page.websiteID]
            let topic = site?.topicID.flatMap { topicByID[$0] }

            var lines: [String] = []
            lines.append("---")

            if let title = page.title, !title.isEmpty {
                lines.append("title: \(yamlEscape(title))")
            } else {
                lines.append("title: \(yamlEscape(page.url))")
            }
            lines.append("url: \(yamlEscape(page.url))")
            lines.append("domain: \(yamlEscape(domain))")

            if let topic = topic { lines.append("topic: \(yamlEscape(topic.name))") }
            if toggles.includeTimestamps {
                lines.append("date: \(iso(page.timestamp))")
            }
            if let author = page.author, !author.isEmpty {
                lines.append("author: \(yamlEscape(author))")
            }
            if let rt = page.readingTime {
                lines.append("reading_time: \(rt)")
            }
            lines.append("word_count: \(page.wordCount)")
            if toggles.includeAISummaries, let summary = page.summary, !summary.isEmpty {
                lines.append("summary: \(yamlEscape(summary))")
            }

            lines.append("---")
            lines.append("")
            lines.append("# \(page.displayTitle)")
            lines.append("")

            var crumbs: [String] = []
            crumbs.append("[[Sites/\(slug(domain))|\(domain)]]")
            if let topic = topic {
                crumbs.append("[[Topics/\(slug(topic.name))|\(topic.name)]]")
            }
            lines.append(crumbs.joined(separator: " · "))
            lines.append("")

            lines.append(page.content)

            if toggles.includeAnnotations {
                let anns = annotationsByPageID[page.id] ?? []
                if !anns.isEmpty {
                    lines.append("")
                    lines.append("## Highlights")
                    lines.append("")
                    for ann in anns {
                        let quote = ann.text.replacingOccurrences(of: "\n", with: " ")
                        lines.append("> \(quote)")
                        lines.append("")
                    }
                }
            }

            let body = lines.joined(separator: "\n")
            try body.data(using: .utf8)?.write(
                to: domainDir.appendingPathComponent(filename),
                options: .atomic
            )

            onProgress(index + 1, total)
        }
    }

    private static let illegal: Set<Character> = ["/", "\\", ":", "?", "*", "\"", "<", ">", "|"]

    private static func slug(_ raw: String) -> String {
        var cleaned = String(raw.unicodeScalars.map { scalar -> Character in
            let char = Character(scalar)
            return illegal.contains(char) ? "-" : char
        })
        cleaned = cleaned
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "- "))
        if cleaned.isEmpty { return "untitled" }

        return cleaned
    }

    private static func yamlEscape(_ raw: String) -> String {
        let needsQuote = raw.contains(":") || raw.contains("#") || raw.contains("\"") || raw.hasPrefix("-") || raw.contains("\n")
        if !needsQuote { return raw }
        let escaped = raw.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: " ")
        return "\"\(escaped)\""
    }

    private static func iso(_ date: Date) -> String {
        DateFormatters.iso8601.string(from: date)
    }
}
