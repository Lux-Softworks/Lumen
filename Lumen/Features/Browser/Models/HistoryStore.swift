import Combine
import Foundation

struct HistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let url: String
    let title: String
    let timestamp: Date

    init(url: String, title: String) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.timestamp = Date()
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []

    private let key = "com.lumen.history"
    private let maxEntries = 10

    static let shared = HistoryStore()

    private init() {
        load()
    }

    func record(url: String, title: String) {
        guard !url.isEmpty, url != "about:blank" else { return }

        entries.removeAll { $0.url == url }

        let entry = HistoryEntry(url: url, title: title)
        entries.insert(entry, at: 0)

        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        save()
    }

    var recentEntries: [HistoryEntry] {
        Array(entries.prefix(10))
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return }

        var seen = Set<String>()
        var deduped = [HistoryEntry]()
        for entry in decoded {
            if !seen.contains(entry.url) {
                seen.insert(entry.url)
                deduped.append(entry)
            }
        }

        entries = deduped
    }
}
