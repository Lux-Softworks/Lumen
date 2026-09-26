import Foundation

nonisolated struct ContentRule: Codable, Equatable, Sendable {
    nonisolated struct Trigger: Codable, Equatable, Sendable {
        var urlFilter: String
        var loadType: [String]?
        var unlessDomain: [String]?

        init(urlFilter: String, loadType: [String]? = nil, unlessDomain: [String]? = nil) {
            self.urlFilter = urlFilter
            self.loadType = loadType
            self.unlessDomain = unlessDomain
        }
    }

    nonisolated struct Action: Codable, Equatable, Sendable {
        var type: ActionType
    }

    nonisolated enum ActionType: String, Codable, Sendable {
        case block
        case blockCookies = "block-cookies"
        case makeHTTPS = "make-https"
    }

    var trigger: Trigger
    var action: Action
}

nonisolated extension ContentRule.Trigger {
    enum CodingKeys: String, CodingKey {
        case urlFilter = "url-filter"
        case loadType = "load-type"
        case unlessDomain = "unless-domain"
    }
}

nonisolated struct TrackerBlockList: Sendable {
    nonisolated struct TrackerDomain: Hashable, Sendable {
        let host: String
        let path: String?
        let entityName: String
    }

    static let blockedCategoryKeys: Set<String> = [
        "Advertising", "Analytics", "Social", "Cryptomining",
        "FingerprintingInvasive", "FingerprintingGeneral", "Email", "Disconnect"
    ]

    static let functionalCategoryKeys: Set<String> = ["Content", "Anti-fraud"]

    static let mixedContentRules: [ContentRule] = [
        ContentRule(
            trigger: ContentRule.Trigger(urlFilter: "^http://"),
            action: ContentRule.Action(type: .makeHTTPS)
        )
    ]

    private static let thirdPartyCookieRule = ContentRule(
        trigger: ContentRule.Trigger(urlFilter: ".*", loadType: ["third-party"]),
        action: ContentRule.Action(type: .blockCookies)
    )

    private static let regexSpecialCharacters: Set<Character> = [
        ".", "+", "?", "*", "(", ")", "[", "]", "{", "}", "^", "$", "|", "\\"
    ]

    let trackers: [TrackerDomain]
    private let trackersByHost: [String: [TrackerDomain]]
    private let hostsByEntity: [String: Set<String>]

    init(entries: [DisconnectEntry]) {
        var hostsByEntity: [String: Set<String>] = [:]
        var functionalDomains: Set<String> = []
        var entityByBlockedDomain: [String: String] = [:]

        for entry in entries {
            let domains = entry.domains.map(Self.normalized)
            hostsByEntity[entry.entityName, default: []].formUnion(domains.map(Self.host(of:)))

            if Self.functionalCategoryKeys.contains(entry.categoryKey) {
                functionalDomains.formUnion(domains)
            }

            guard Self.blockedCategoryKeys.contains(entry.categoryKey) else { continue }

            for domain in domains {
                let owner = entityByBlockedDomain[domain].map { min($0, entry.entityName) } ?? entry.entityName
                entityByBlockedDomain[domain] = owner
            }
        }

        let trackers =
            entityByBlockedDomain
            .filter { !functionalDomains.contains($0.key) }
            .map { domain, entityName in
                TrackerDomain(host: Self.host(of: domain), path: Self.path(of: domain), entityName: entityName)
            }
            .sorted { ($0.host, $0.path ?? "") < ($1.host, $1.path ?? "") }

        self.trackers = trackers
        self.trackersByHost = Dictionary(grouping: trackers, by: \.host)
        self.hostsByEntity = hostsByEntity
    }

    func contentRules() -> [ContentRule] {
        let blockRules = trackers.map { tracker in
            ContentRule(
                trigger: ContentRule.Trigger(
                    urlFilter: Self.urlFilter(for: tracker),
                    loadType: ["third-party"],
                    unlessDomain: hostsByEntity[tracker.entityName, default: []].sorted().map { "*" + $0 }
                ),
                action: ContentRule.Action(type: .block)
            )
        }

        return blockRules + [Self.thirdPartyCookieRule]
    }

    func blockedTrackerHosts(in resourceURLs: [URL], pageURL: URL) -> Set<String> {
        guard let pageHost = pageURL.host?.lowercased() else { return [] }

        var blockedHosts: Set<String> = []

        for url in resourceURLs {
            guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
                let host = url.host?.lowercased(),
                let tracker = matchingTracker(host: host, path: url.path)
            else {
                continue
            }

            let ownerHosts = hostsByEntity[tracker.entityName, default: []]

            guard !ownerHosts.contains(where: { Self.host(pageHost, isWithin: $0) }) else { continue }

            blockedHosts.insert(host)
        }

        return blockedHosts
    }

    static func encode(_ rules: [ContentRule]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        guard let json = String(bytes: try encoder.encode(rules), encoding: .utf8) else {
            throw CocoaError(.coderInvalidValue)
        }

        return json
    }

    private func matchingTracker(host: String, path: String) -> TrackerDomain? {
        var labels = host.split(separator: ".")

        while !labels.isEmpty {
            let candidate = labels.joined(separator: ".")
            let match = trackersByHost[candidate]?.first { tracker in
                tracker.path.map { path.hasPrefix($0) } ?? true
            }

            if let match {
                return match
            }

            labels.removeFirst()
        }

        return nil
    }

    private static func urlFilter(for tracker: TrackerDomain) -> String {
        let hostPattern = escaped(tracker.host)
        let suffix = tracker.path.map(escaped) ?? "[:/]"

        return "^https?://([^/]*\\.)?" + hostPattern + suffix
    }

    private static func escaped(_ text: String) -> String {
        var result = ""

        for character in text {
            if regexSpecialCharacters.contains(character) {
                result.append("\\")
            }

            result.append(character)
        }

        return result
    }

    private static func normalized(_ domain: String) -> String {
        var value = domain.lowercased()

        for prefix in ["https://", "http://"] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
        }

        while value.hasSuffix("/") {
            value.removeLast()
        }

        return value
    }

    private static func host(of domain: String) -> String {
        String(domain.split(separator: "/", maxSplits: 1).first ?? Substring(domain))
    }

    private static func path(of domain: String) -> String? {
        guard let slash = domain.firstIndex(of: "/") else { return nil }

        return String(domain[slash...])
    }

    private static func host(_ host: String, isWithin domain: String) -> Bool {
        host == domain || host.hasSuffix("." + domain)
    }
}
