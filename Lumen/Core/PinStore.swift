import Foundation
import Combine

@MainActor
final class PinStore: ObservableObject {
    static let shared = PinStore()

    private let key = "pinnedDomains"
    @Published private var pinned: Set<String>
    @Published private(set) var all: [String] = []

    private init() {
        let arr = UserDefaults.standard.stringArray(forKey: key) ?? []
        pinned = Set(arr)
        all = pinned.sorted()
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
        all = pinned.sorted()
        save()
    }

    private func save() {
        UserDefaults.standard.set(pinned.sorted(), forKey: key)
    }
}
