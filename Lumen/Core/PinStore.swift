import Foundation
import Combine

@MainActor
final class PinStore: ObservableObject {
    static let shared = PinStore()

    private let key = "pinnedDomains"
    @Published private var pinned: Set<String>

    private init() {
        let arr = UserDefaults.standard.stringArray(forKey: key) ?? []
        pinned = Set(arr)
    }

    func isPinned(_ domain: String) -> Bool {
        pinned.contains(domain)
    }

    func toggle(_ domain: String) {
        if pinned.contains(domain) {
            pinned.remove(domain)
        } else {
            pinned.insert(domain)
        }
        save()
    }

    private func save() {
        UserDefaults.standard.set(Array(pinned), forKey: key)
    }
}
