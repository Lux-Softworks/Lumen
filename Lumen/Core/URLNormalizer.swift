import Foundation

nonisolated enum URLNormalizer {
    nonisolated static func displayKey(_ url: String) -> String {
        var normalized = url.lowercased().trimmingCharacters(in: .whitespaces)

        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }

        if normalized.hasPrefix("http://") {
            normalized = String(normalized.dropFirst(7))
        } else if normalized.hasPrefix("https://") {
            normalized = String(normalized.dropFirst(8))
        }

        if normalized.hasPrefix("www.") {
            normalized = String(normalized.dropFirst(4))
        }

        return normalized
    }

    nonisolated static func canonical(_ url: String) -> String {
        guard var comps = URLComponents(string: url) else {
            return url.lowercased()
        }

        comps.fragment = nil
        if let items = comps.queryItems {
            let filtered = items.filter { !trackingParams.contains($0.name.lowercased()) }
            comps.queryItems = filtered.isEmpty ? nil : filtered
        }

        var host = (comps.host ?? "").lowercased()
        if host.hasPrefix("www.") { host = String(host.dropFirst(4)) }
        var path = comps.path

        if path.count > 1, path.hasSuffix("/") { path.removeLast() }
        var result = host + path

        if let query = comps.query, !query.isEmpty {
            result += "?" + query
        }

        return result.lowercased()
    }

    nonisolated static func extractDomain(_ url: String) -> String {
        guard let host = URL(string: url)?.host else { return "" }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private static let trackingParams: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "utm_id", "utm_name", "utm_brand", "utm_social", "utm_social-type",
        "fbclid", "gclid", "gbraid", "wbraid", "dclid", "msclkid", "yclid",
        "mc_cid", "mc_eid", "igshid", "s_cid", "ref", "ref_", "ref_src",
        "referrer", "source", "src", "campaign", "_hsenc", "_hsmi",
        "_ga", "_gac", "aff", "affiliate", "trk", "pk_campaign", "pk_kwd",
        "spm", "share", "shared", "shareid", "share_source"
    ]
}
