import UIKit

enum FaviconService {
    private static let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 256
        cache.totalCostLimit = 16 * 1024 * 1024
        return cache
    }()

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.timeoutIntervalForRequest = 5
        return URLSession(configuration: configuration)
    }()

    static func faviconURL(for pageURL: URL) -> URL? {
        guard let host = pageURL.host, !host.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.port = pageURL.port
        components.path = "/favicon.ico"

        return components.url
    }

    static func fetchFavicon(for pageURL: URL) async -> UIImage? {
        guard let url = faviconURL(for: pageURL) else { return nil }
        let key = url as NSURL
        if let cached = cache.object(forKey: key) { return cached }
        guard let (data, response) = try? await session.data(from: url) else { return nil }
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
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
