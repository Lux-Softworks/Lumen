import Foundation

actor TrackerDatabase {
    private init() {}

    static let shared = TrackerDatabase()

    private var trackers: [String: ThreatDetector.TrackerInfo] = [:]
    private var disconnectEntries: [DisconnectEntry] = []
    private(set) var entityCount: Int = 0
    private(set) var domainCount: Int = 0
    private(set) var isLoaded: Bool = false

    func ensureLoaded() {
        if isLoaded { return }

        guard loadBundledDatabase() else { return }
        isLoaded = true
    }

    func lookup(domain: String) -> ThreatDetector.TrackerInfo? {
        if let direct = trackers[domain] {
            return direct
        }

        let parts = domain.split(separator: ".")
        if parts.count > 2 {
            let parent = parts.suffix(2).joined(separator: ".")
            return trackers[parent]
        }

        return nil
    }

    func allEntries() -> [String: ThreatDetector.TrackerInfo] {
        return trackers
    }

    func merge(_ additional: [String: ThreatDetector.TrackerInfo]) {
        for (key, value) in additional {
            trackers[key] = value
        }
        domainCount = trackers.count
    }

    func reload() {
        trackers.removeAll()
        disconnectEntries.removeAll()
        entityCount = 0
        domainCount = 0
        isLoaded = false

        guard loadBundledDatabase() else { return }
        isLoaded = true
    }

    private func loadBundledDatabase() -> Bool {
        guard let url = Bundle.main.url(forResource: "disconnect-services", withExtension: "json") else {
            return false
        }

        guard let data = try? Data(contentsOf: url) else {
            return false
        }

        parseDisconnectJSON(data)
        return true
    }

    func parseDisconnectJSON(_ data: Data) {
        let entries = DisconnectList.entries(from: data)

        guard !entries.isEmpty else { return }

        var newTrackers: [String: ThreatDetector.TrackerInfo] = [:]
        var seenEntities: Set<String> = []

        for entry in entries {
            let info = ThreatDetector.TrackerInfo(
                entityName: entry.entityName,
                category: DisconnectList.category(forKey: entry.categoryKey),
                domains: entry.domains
            )

            for domain in entry.domains {
                let cleaned =
                    domain
                    .replacingOccurrences(of: "http://", with: "")
                    .replacingOccurrences(of: "https://", with: "")
                    .components(separatedBy: "/").first ?? domain

                newTrackers[cleaned] = info
            }

            seenEntities.insert(entry.entityName)
        }

        for (key, value) in newTrackers {
            trackers[key] = value
        }

        disconnectEntries = entries
        entityCount = seenEntities.count
        domainCount = trackers.count
    }

    func contentRuleSource() throws -> ContentRuleSource {
        let blockList = TrackerBlockList(entries: disconnectEntries)

        return ContentRuleSource(
            blockList: blockList,
            trackingRules: try TrackerBlockList.encode(blockList.contentRules()),
            mixedContentRules: try TrackerBlockList.encode(TrackerBlockList.mixedContentRules)
        )
    }
}
