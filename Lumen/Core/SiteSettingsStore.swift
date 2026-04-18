import Foundation
import Combine

class SiteSettingsStore: ObservableObject {
    static let shared = SiteSettingsStore()
    
    @Published var hostSettings: [String: PrivacyPolicy] = [:]
    
    private let fileURL: URL = {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("Lumen", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("site_settings.json")
    }()
    
    private init() {
        load()
    }
    
    func policy(for url: URL?) -> PrivacyPolicy? {
        guard let host = url?.host?.lowercased() else { return nil }
        return hostSettings[host]
    }
    
    func savePolicy(_ policy: PrivacyPolicy, for url: URL?) {
        guard let host = url?.host?.lowercased() else { return }
        hostSettings[host] = policy
        save()
    }
    
    func removePolicy(for url: URL?) {
        guard let host = url?.host?.lowercased() else { return }
        hostSettings.removeValue(forKey: host)
        save()
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(hostSettings)
            try data.write(to: fileURL)
        } catch { }
    }
    
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            hostSettings = try JSONDecoder().decode([String: PrivacyPolicy].self, from: data)
        } catch { }
    }
}
