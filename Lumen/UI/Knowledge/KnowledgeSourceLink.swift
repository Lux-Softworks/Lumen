import SwiftUI

extension EnvironmentValues {
    @Entry var openKnowledgeSource: ((URL) -> Void)?
}

nonisolated enum KnowledgeSourceLink {
    static func url(for page: PageContent) -> URL? {
        guard let url = URL(string: page.url),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else { return nil }

        return url
    }
}
