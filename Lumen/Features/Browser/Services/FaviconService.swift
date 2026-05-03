import UIKit

enum FaviconService {
    private static let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 256
        cache.totalCostLimit = 16 * 1024 * 1024
        return cache
    }()

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
        let key = url as NSURL
        if let cached = cache.object(forKey: key) { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        guard let image = UIImage(data: data) else { return nil }
        let cost = data.count
        cache.setObject(image, forKey: key, cost: cost)
        return image
    }

    static func cachedFavicon(for pageURL: URL) -> UIImage? {
        guard let url = faviconURL(for: pageURL) else { return nil }
        return cache.object(forKey: url as NSURL)
    }

    static func prefetchFavicon(for pageURL: URL) {
        guard let url = faviconURL(for: pageURL) else { return }
        if cache.object(forKey: url as NSURL) != nil { return }
        Task.detached(priority: .background) {
            _ = await fetchFavicon(for: pageURL)
        }
    }
}
