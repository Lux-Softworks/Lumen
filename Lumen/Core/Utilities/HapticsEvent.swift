import UIKit

enum HapticsEvent: Hashable {
    case tap
    case selection
    case snap
    case soft
    case rigid
    case success
    case error

    var minMode: HapticsMode {
        switch self {
        case .tap, .soft: return .full
        case .selection, .snap, .rigid, .success, .error: return .subtle
        }
    }

    var bypassesThrottle: Bool {
        switch self {
        case .success, .error: return true
        default: return false
        }
    }

    enum Generator {
        case impact(UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat)
        case selection
        case notification(UINotificationFeedbackGenerator.FeedbackType)
    }

    var generator: Generator {
        switch self {
        case .tap: return .impact(.soft, intensity: 0.7)
        case .selection: return .selection
        case .snap: return .impact(.soft, intensity: 0.5)
        case .soft: return .impact(.soft, intensity: 0.45)
        case .rigid: return .impact(.rigid, intensity: 0.55)
        case .success: return .notification(.success)
        case .error: return .notification(.warning)
        }
    }
}
