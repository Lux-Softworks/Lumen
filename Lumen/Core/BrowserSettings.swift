import Foundation
import SwiftUI
import Combine
import UIKit

enum NativeAppsPolicy: String, CaseIterable, Identifiable {
    case ask = "Ask"
    case always = "Always Open"
    case never = "Stay in Browser"
    var id: String { rawValue }
}

enum HapticsMode: String, CaseIterable, Identifiable {
    case off, subtle, full
    var id: String { rawValue }
    var rank: Int {
        switch self {
        case .off: return 0
        case .subtle: return 1
        case .full: return 2
        }
    }
    var label: String {
        switch self {
        case .off: return "Off"
        case .subtle: return "Subtle"
        case .full: return "Full"
        }
    }
    var caption: String {
        switch self {
        case .off: return "No vibrations."
        case .subtle: return "Vibrate only on key changes — toggles, sheet snaps, confirmations."
        case .full: return "Vibrate on every interaction."
        }
    }
}

@MainActor
class BrowserSettings: ObservableObject {
    static let shared = BrowserSettings()

    private let defaults = UserDefaults.standard

    @Published var enableJavaScript: Bool {
        didSet { defaults.set(enableJavaScript, forKey: "enableJavaScript") }
    }
    @Published var blockPopups: Bool {
        didSet { defaults.set(blockPopups, forKey: "blockPopups") }
    }
    @Published var blockTrackers: Bool {
        didSet { defaults.set(blockTrackers, forKey: "blockTrackers") }
    }
    @Published var defaultSearchEngine: String {
        didSet { defaults.set(defaultSearchEngine, forKey: "defaultSearchEngine") }
    }
    @Published var clearHistoryOnClose: Bool {
        didSet { defaults.set(clearHistoryOnClose, forKey: "clearHistoryOnClose") }
    }
    @Published var nativeAppsPolicy: NativeAppsPolicy {
        didSet { defaults.set(nativeAppsPolicy.rawValue, forKey: "nativeAppsPolicy") }
    }
    @Published var collectKnowledge: Bool {
        didSet { defaults.set(collectKnowledge, forKey: "collectKnowledge") }
    }
    @Published var hapticsMode: HapticsMode {
        didSet { defaults.set(hapticsMode.rawValue, forKey: "hapticsMode") }
    }

    var searchEngine: SearchEngine {
        get { SearchEngine(rawValue: defaultSearchEngine) ?? .google }
        set { defaultSearchEngine = newValue.rawValue }
    }

    private init() {
        self.enableJavaScript = defaults.object(forKey: "enableJavaScript") as? Bool ?? true
        self.blockPopups = defaults.object(forKey: "blockPopups") as? Bool ?? true
        self.blockTrackers = defaults.object(forKey: "blockTrackers") as? Bool ?? true
        self.defaultSearchEngine = defaults.string(forKey: "defaultSearchEngine") ?? "Google"
        self.clearHistoryOnClose = defaults.object(forKey: "clearHistoryOnClose") as? Bool ?? false
        let savedPolicy = defaults.string(forKey: "nativeAppsPolicy") ?? ""
        self.nativeAppsPolicy = NativeAppsPolicy(rawValue: savedPolicy) ?? .ask
        self.collectKnowledge = defaults.object(forKey: "collectKnowledge") as? Bool ?? true
        if let savedHaptics = defaults.string(forKey: "hapticsMode"),
           let mode = HapticsMode(rawValue: savedHaptics) {
            self.hapticsMode = mode
        } else {
            self.hapticsMode = UIAccessibility.isReduceMotionEnabled ? .subtle : .full
        }
    }

    func policy(for url: URL?) -> PrivacyPolicy {
        if let sitePolicy = SiteSettingsStore.shared.policy(for: url) {
            return sitePolicy
        }
        return globalPrivacyPolicy
    }

    var globalPrivacyPolicy: PrivacyPolicy {
        PrivacyPolicy(
            blocksThirdPartyCookies: blockTrackers,
            allowsJavaScript: enableJavaScript,
            allowsInlineMediaPlayback: false,
            allowsPictureInPictureMediaPlayback: false,
            allowsAirPlayForMediaPlayback: false,
            allowsMediaAutoPlay: false,
            javaScriptCanOpenWindowsAutomatically: !blockPopups,
            suppressesIncrementalRendering: true,
            limitsNavigationToHTTPS: true,
            customUserAgent: nil
        )
    }
}
