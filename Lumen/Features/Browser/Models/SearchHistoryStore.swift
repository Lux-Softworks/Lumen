import Combine
import Foundation

struct SearchQueryEntry: Codable, Identifiable, Equatable {
    let id: String
    let query: String
    let timestamp: Date

    init(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = SearchHistoryStore.normalize(trimmed)
        self.query = trimmed
        self.timestamp = Date()
    }
}

@MainActor
final class SearchHistoryStore: ObservableObject {
    @Published private(set) var entries: [SearchQueryEntry] = []

    private var indexById: [String: Int] = [:]

    private static let legacyKey = "com.lumen.search.queries"
    private static let fileName = "search_history.json"
    private static let maxEntries = 200
    private static let maxQueryLength = 256
    private static let maxFileBytes = 1 * 1024 * 1024

    private var saveCancellable: AnyCancellable?
    private let saveSubject = PassthroughSubject<Void, Never>()
    private let storeURL: URL

    static let shared = SearchHistoryStore()

    private init() {
        self.storeURL = Self.resolveStoreURL()
        load()
        migrateLegacyIfNeeded()
        setupPersistenceThrottle()
    }

    func record(query: String, isIncognito: Bool) {
        guard !isIncognito else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.count <= Self.maxQueryLength else { return }
        guard !looksSensitive(trimmed) else { return }

        let normalized = Self.normalize(trimmed)
        guard !normalized.isEmpty else { return }

        if let existing = indexById[normalized] {
            entries.remove(at: existing)
        }
        entries.insert(SearchQueryEntry(query: trimmed), at: 0)
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        rebuildIndex()
        saveSubject.send()
    }

    func suggestions(matching prefix: String, limit: Int = 5) -> [SearchQueryEntry] {
        let normalizedPrefix = Self.normalize(prefix)
        if normalizedPrefix.isEmpty {
            return Array(entries.prefix(limit))
        }
        var prefixMatches: [SearchQueryEntry] = []
        var substringMatches: [SearchQueryEntry] = []
        prefixMatches.reserveCapacity(limit)
        substringMatches.reserveCapacity(limit)
        for entry in entries {
            let id = entry.id
            if id == normalizedPrefix { continue }
            if id.hasPrefix(normalizedPrefix) {
                prefixMatches.append(entry)
                if prefixMatches.count >= limit { break }
            } else if substringMatches.count < limit, id.contains(normalizedPrefix) {
                substringMatches.append(entry)
            }
        }
        return Array((prefixMatches + substringMatches).prefix(limit))
    }

    func clearAll() {
        entries = []
        indexById.removeAll(keepingCapacity: true)
        try? FileManager.default.removeItem(at: storeURL)
    }

    func flush() {
        performSave()
    }

    nonisolated static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func rebuildIndex() {
        indexById.removeAll(keepingCapacity: true)
        for (i, e) in entries.enumerated() { indexById[e.id] = i }
    }

    private func looksSensitive(_ s: String) -> Bool {
        if let url = URL(string: s), url.scheme != nil, url.host != nil { return true }
        if s.range(of: #"\b(?:\d[ -]*?){13,19}\b"#, options: .regularExpression) != nil {
            return true
        }
        if s.count >= 32,
           s.range(of: #"^[a-fA-F0-9]+$"#, options: .regularExpression) != nil {
            return true
        }
        if s.count >= 40, !s.contains("."), !s.contains(" "),
           s.range(of: #"^[A-Za-z0-9+/=_\-]+$"#, options: .regularExpression) != nil,
           s.range(of: #"[A-Z]"#, options: .regularExpression) != nil,
           s.range(of: #"[a-z]"#, options: .regularExpression) != nil,
           s.range(of: #"\d"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private func setupPersistenceThrottle() {
        saveCancellable = saveSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.performSave() }
    }

    private func performSave() {
        do {
            var data = try JSONEncoder().encode(entries)
            if data.count > Self.maxFileBytes {
                let half = max(10, entries.count / 2)
                entries = Array(entries.prefix(half))
                rebuildIndex()
                data = try JSONEncoder().encode(entries)
            }
            try data.write(to: storeURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        } catch {}
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }
        do {
            let data = try Data(contentsOf: storeURL)
            let decoded = try JSONDecoder().decode([SearchQueryEntry].self, from: data)
            var seen = Set<String>()
            var deduped: [SearchQueryEntry] = []
            deduped.reserveCapacity(decoded.count)
            for entry in decoded where seen.insert(entry.id).inserted {
                deduped.append(entry)
            }
            entries = Array(deduped.prefix(Self.maxEntries))
            rebuildIndex()
        } catch {
            let quarantine = storeURL.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: storeURL, to: quarantine)
        }
    }

    private func migrateLegacyIfNeeded() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Self.legacyKey) else { return }
        defer { defaults.removeObject(forKey: Self.legacyKey) }
        guard entries.isEmpty,
              let decoded = try? JSONDecoder().decode([SearchQueryEntry].self, from: data)
        else { return }
        var seen = Set<String>()
        var deduped: [SearchQueryEntry] = []
        deduped.reserveCapacity(decoded.count)
        for entry in decoded where seen.insert(entry.id).inserted {
            deduped.append(entry)
        }
        entries = Array(deduped.prefix(Self.maxEntries))
        rebuildIndex()
        saveSubject.send()
    }

    private static func resolveStoreURL() -> URL {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Lumen", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }
}
