import UIKit

enum FaviconService {
    static func faviconURL(for pageURL: URL) -> URL? {
        guard let host = pageURL.host, !host.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/s2/favicons"
        components.queryItems = [
            URLQueryItem(name: "domain", value: host),
            URLQueryItem(name: "sz", value: "256"),
        ]

        return components.url
    }

    static func fetchFavicon(for pageURL: URL) async -> UIImage? {
        guard let url = faviconURL(for: pageURL) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }

        return UIImage(data: data)
    }
}
