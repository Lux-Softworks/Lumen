import Combine
import Foundation
import CryptoKit

struct HistoryEntry: Codable, Identifiable, Equatable {
    let id: String
    let url: String
    let title: String
    let timestamp: Date

    init(url: String, title: String) {
        let normalizedURL = HistoryStore.normalizeURL(url)
        self.id = HistoryStore.stableID(for: normalizedURL)
        self.url = url
        self.title = title
        self.timestamp = Date()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let stringId = try? container.decode(String.self, forKey: .id) {
            self.id = stringId
        } else if let uuidId = try? container.decode(UUID.self, forKey: .id) {
            self.id = uuidId.uuidString
        } else {
            let url = try container.decode(String.self, forKey: .url)
            let normalizedURL = HistoryStore.normalizeURL(url)
            self.id = HistoryStore.stableID(for: normalizedURL)
        }
        
        self.url = try container.decode(String.self, forKey: .url)
        self.title = try container.decode(String.self, forKey: .title)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []

    private let key = "com.lumen.history"
    private let maxEntries = 10
    private var saveCancellable: AnyCancellable?
    private let saveSubject = PassthroughSubject<Void, Never>()

    static let shared = HistoryStore()

    private init() {
        load()
        setupPersistenceThrottle()
    }
    
    private func setupPersistenceThrottle() {
        saveCancellable = saveSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.performSave()
            }
    }

    func record(url: String, title: String) {
        guard !url.isEmpty, url != "about:blank" else { return }

        let normalizedURL = Self.normalizeURL(url)
        let stableID = Self.stableID(for: normalizedURL)
        
        entries.removeAll { $0.id == stableID }

        let entry = HistoryEntry(url: url, title: title)
        entries.insert(entry, at: 0)

        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        saveSubject.send()
    }

    nonisolated static func normalizeURL(_ url: String) -> String {
        var normalized = url.lowercased().trimmingCharacters(in: .whitespaces)
        
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        
        if normalized.hasPrefix("http://") {
            normalized = String(normalized.dropFirst(7))
        } else if normalized.hasPrefix("https://") {
            normalized = String(normalized.dropFirst(8))
        }
        
        if normalized.hasPrefix("www.") {
            normalized = String(normalized.dropFirst(4))
        }
        
        return normalized
    }
    
    nonisolated static func stableID(for normalizedURL: String) -> String {
        let hash = SHA256.hash(data: Data(normalizedURL.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).lowercased()
    }

    var recentEntries: [HistoryEntry] {
        Array(entries.prefix(10))
    }

    func clearAll() {
        entries = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func performSave() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        
        guard let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }

        var seen = Set<String>()
        var deduped = [HistoryEntry]()
        for entry in decoded {
            let normalizedURL = Self.normalizeURL(entry.url)
            let stableID = Self.stableID(for: normalizedURL)
            
            if !seen.contains(stableID) {
                seen.insert(stableID)
                deduped.append(entry)
            }
        }

        entries = deduped
    }
}
