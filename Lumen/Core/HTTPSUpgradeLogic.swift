import Foundation

enum HTTPSUpgradeLogic {
    enum PolicyAction: Equatable {
        case allow
        case upgrade(URL)
        case cancel
    }

    static func decidePolicy(for url: URL, httpsOnly: Bool) -> PolicyAction {
        guard let scheme = url.scheme?.lowercased() else {
            return .cancel
        }

        switch scheme {
        case "https", "about", "file":
            return .allow
        case "http":
            if httpsOnly {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.scheme = "https"

                if let httpsURL = components?.url {
                    return .upgrade(httpsURL)
                }

                return .cancel
            }

            return .allow
        default:
            return .cancel
        }
    }
}
