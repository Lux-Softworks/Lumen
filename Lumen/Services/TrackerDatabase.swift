import Foundation

actor TrackerDatabase {

    static let shared = TrackerDatabase()

    private var trackers: [String: ThreatDetector.TrackerInfo] = [:]
    private(set) var entityCount: Int = 0
    private(set) var domainCount: Int = 0

    private init() {
        Task {
            await loadBundledDatabase()
        }
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
        entityCount = 0
        domainCount = 0

        Task {
            await loadBundledDatabase()
        }
    }

    private func loadBundledDatabase() {
        guard let url = Bundle.main.url(forResource: "disconnect-services", withExtension: "json") else {
            return
        }

        guard let data = try? Data(contentsOf: url) else {
            return
        }

        parseDisconnectJSON(data)
    }

    func parseDisconnectJSON(_ data: Data) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let categories = root["categories"] as? [String: Any] else {
            return
        }

        let categoryMapping: [String: EntityCategory] = [
            "Advertising": .advertising,
            "Analytics": .analytics,
            "Social": .social,
            "Cryptomining": .cryptomining,
            "Fingerprinting": .fingerprinting,
            "Content": .unknown,
            "Disconnect": .advertising,
            "Anti-fraud": .unknown
        ]

        var newTrackers: [String: ThreatDetector.TrackerInfo] = [:]
        var seenEntities: Set<String> = []

        for (categoryName, categoryEntries) in categories {
            guard let entries = categoryEntries as? [[String: Any]] else {
                continue
            }

            let category = categoryMapping[categoryName] ?? .unknown

            for entry in entries {
                for (entityName, entityData) in entry {
                    guard let entityDict = entityData as? [String: Any] else {
                        continue
                    }

                    var allDomains: [String] = []

                    for (key, value) in entityDict {
                        if key == "performance" || key == "dnt" {
                            continue
                        }

                        if let domainList = value as? [String] {
                            allDomains.append(contentsOf: domainList)
                        }
                    }

                    guard !allDomains.isEmpty else { continue }

                    let info = ThreatDetector.TrackerInfo(
                        entityName: entityName,
                        category: category,
                        domains: allDomains
                    )

                    for domain in allDomains {
                        let cleaned = domain
                            .replacingOccurrences(of: "http://", with: "")
                            .replacingOccurrences(of: "https://", with: "")
                            .components(separatedBy: "/").first ?? domain

                        newTrackers[cleaned] = info
                    }

                    seenEntities.insert(entityName)
                }
            }
        }

        for (key, value) in newTrackers {
            trackers[key] = value
        }

        entityCount = seenEntities.count
        domainCount = trackers.count
    }
}
