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
    private var didLoad = false

    static let shared = HistoryStore()

    private init() {
        setupPersistenceThrottle()
    }

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        let key = self.key
        
        Task.detached(priority: .userInitiated) {
            guard let data = UserDefaults.standard.data(forKey: key) else { return }
            guard let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
                UserDefaults.standard.removeObject(forKey: key)
                return
            }
            let deduped = HistoryStore.dedupe(decoded)
            await MainActor.run {
                HistoryStore.shared.applyLoaded(deduped)
            }
        }
    }

    private func applyLoaded(_ loaded: [HistoryEntry]) {
        let inMemory = entries
        let merged = Self.dedupe(inMemory + loaded)
        entries = merged.count > maxEntries ? Array(merged.prefix(maxEntries)) : merged

        for entry in entries {
            if let parsed = URL(string: entry.url) {
                FaviconService.prefetchFavicon(for: parsed)
            }
        }
    }

    nonisolated private static func dedupe(_ list: [HistoryEntry]) -> [HistoryEntry] {
        var seenIDs = Set<String>()
        var seenDisplay = Set<String>()
        var deduped = [HistoryEntry]()
        deduped.reserveCapacity(list.count)
        for entry in list {
            let normalizedURL = normalizeURL(entry.url)
            let id = stableID(for: normalizedURL)
            let displayKey = displayDedupKey(url: entry.url, title: entry.title)
            guard !seenIDs.contains(id), !seenDisplay.contains(displayKey) else { continue }
            seenIDs.insert(id)
            seenDisplay.insert(displayKey)
            deduped.append(entry)
        }
        return deduped
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
        let displayKey = Self.displayDedupKey(url: url, title: title)

        entries.removeAll {
            $0.id == stableID || Self.displayDedupKey(url: $0.url, title: $0.title) == displayKey
        }

        let entry = HistoryEntry(url: url, title: title)
        entries.insert(entry, at: 0)

        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        saveSubject.send()

        if let parsed = URL(string: url) {
            FaviconService.prefetchFavicon(for: parsed)
        }
    }

    nonisolated static func normalizeURL(_ url: String) -> String {
        URLNormalizer.displayKey(url)
    }

    nonisolated static func displayDedupKey(url: String, title: String) -> String {
        let host = URLNormalizer.extractDomain(url).lowercased()
        let normalizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return host + "|" + normalizedTitle
    }

    nonisolated static func stableID(for normalizedURL: String) -> String {
        let hash = SHA256.hash(data: Data(normalizedURL.utf8))
        let hexChars: [UInt8] = Array("0123456789abcdef".utf8)
        var bytes = [UInt8]()
        bytes.reserveCapacity(16)
        for byte in hash.prefix(8) {
            bytes.append(hexChars[Int(byte >> 4)])
            bytes.append(hexChars[Int(byte & 0x0F)])
        }
        return String(decoding: bytes, as: UTF8.self)
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

}
