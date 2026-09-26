import SwiftUI

enum ClearHistoryOnClose {
    static func handle(_ phase: ScenePhase, isEnabled: Bool) {
        guard isEnabled, phase == .background else { return }

        HistoryStore.shared.clearAll()
        SearchHistoryStore.shared.clearAll()
    }
}
