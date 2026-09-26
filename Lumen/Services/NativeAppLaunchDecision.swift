import Foundation

enum NativeAppLaunchDecision: Equatable {
    case open
    case ask
    case stay

    private static let browserSchemes: Set<String> = ["http", "https", "about", "file", "data", "blob", "javascript"]

    static func decide(for url: URL, policy: NativeAppsPolicy, isUserInitiated: Bool) -> NativeAppLaunchDecision {
        guard isUserInitiated,
            let scheme = url.scheme?.lowercased(),
            !browserSchemes.contains(scheme)
        else {
            return .stay
        }

        switch policy {
        case .ask:
            return .ask

        case .always:
            return .open

        case .never:
            return .stay
        }
    }
}
