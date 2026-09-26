import Foundation

nonisolated struct DisconnectEntry: Equatable, Sendable {
    let categoryKey: String
    let entityName: String
    let domains: [String]
}

nonisolated enum DisconnectList {
    private static let categoriesByKey: [String: EntityCategory] = [
        "Advertising": .advertising,
        "Analytics": .analytics,
        "Social": .social,
        "Cryptomining": .cryptomining,
        "FingerprintingInvasive": .fingerprinting,
        "FingerprintingGeneral": .fingerprinting,
        "Email": .email,
        "EmailAggressive": .email,
        "Content": .content,
        "Anti-fraud": .antiFraud,
        "Disconnect": .advertising
    ]

    static func category(forKey key: String) -> EntityCategory {
        categoriesByKey[key] ?? .unknown
    }

    static func entries(from data: Data) -> [DisconnectEntry] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let categories = root["categories"] as? [String: Any]
        else {
            return []
        }

        var entries: [DisconnectEntry] = []

        for (categoryKey, categoryValue) in categories {
            guard let entities = categoryValue as? [[String: Any]] else { continue }

            for entity in entities {
                for (entityName, entityValue) in entity {
                    guard let properties = entityValue as? [String: Any] else { continue }

                    let domains = properties.values.compactMap { $0 as? [String] }.flatMap { $0 }

                    guard !domains.isEmpty else { continue }

                    entries.append(
                        DisconnectEntry(categoryKey: categoryKey, entityName: entityName, domains: domains)
                    )
                }
            }
        }

        return entries
    }
}
