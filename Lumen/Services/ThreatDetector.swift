import Foundation
import WebKit

enum ThreatType: String, Codable, CaseIterable {
    case tracker
    case fingerprinter
    case dataExfiltration
    case cookieAbuse
    case cryptominer
}

enum ThreatSeverity: Int, Codable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    static func < (lhs: ThreatSeverity, rhs: ThreatSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum EntityCategory: String, Codable {
    case advertising
    case analytics
    case social
    case cryptomining
    case fingerprinting
    case unknown
}

enum DataCategory: String, Codable {
    case browsingHistory
    case deviceFingerprint
    case personalIdentifiers
    case locationData
    case cookieData
    case credentials
}

struct ThreatEntity: Codable, Equatable, Hashable {
    let name: String
    let domains: [String]
    let category: EntityCategory
    let privacyPolicyURL: URL?
    let abuseContactEmail: String?

    static func == (lhs: ThreatEntity, rhs: ThreatEntity) -> Bool {
        lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

struct ThreatEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let type: ThreatType
    let severity: ThreatSeverity
    let sourceURL: URL
    let sourceDomain: String
    let pageURL: URL
    let entity: ThreatEntity?
    let details: String
    let dataAtRisk: [DataCategory]
}

struct InterceptedRequest {
    let url: URL
    let pageURL: URL
    let headers: [String: String]
    let isThirdParty: Bool
    let resourceType: ResourceType
    let timestamp: Date

    enum ResourceType {
        case document
        case script
        case image
        case xhr
        case stylesheet
        case font
        case media
        case other
    }
}

protocol ThreatDetectorDelegate: AnyObject {
    func threatDetector(_ detector: ThreatDetector, didDetect event: ThreatEvent)
}

final class ThreatDetector {

    weak var delegate: ThreatDetectorDelegate?

    private var knownTrackers: [String: TrackerInfo] = [:]
    private var fingerprintingPatterns: Set<String> = []
    private var cryptominerDomains: Set<String> = []

    struct TrackerInfo {
        let entityName: String
        let category: EntityCategory
        let domains: [String]
    }

    private static let suspiciousQueryKeys: Set<String> = [
        "uid", "userid", "user_id", "device_id", "deviceid", "idfa", "gaid",
        "aaid", "email", "mail", "phone", "lat", "lon", "latitude", "longitude",
        "fingerprint", "fp", "uuid", "advertising_id", "android_id", "idfv",
    ]

    private static let fingerprintAPIs: Set<String> = [
        "canvas.toDataURL", "canvas.toBlob", "getImageData",
        "webgl.getParameter", "webgl.getSupportedExtensions",
        "AudioContext", "OfflineAudioContext", "createOscillator",
        "navigator.plugins", "navigator.mimeTypes", "navigator.hardwareConcurrency",
        "screen.colorDepth", "screen.pixelDepth",
        "getBattery", "getGamepads", "mediaDevices.enumerateDevices",
    ]

    private static let knownCryptominerDomains: Set<String> = [
        "coinhive.com", "coin-hive.com", "gus.host", "cnhv.co",
        "crypto-loot.com", "cryptoloot.pro", "minero.cc",
        "authedmine.com", "jsecoin.com", "mineralt.io",
    ]

    private static let knownFingerprintingScriptPatterns: Set<String> = [
        "fingerprintjs", "fingerprint2", "clientjs",
        "evercookie", "supercookie", "panopticlick",
    ]

    init() {
        cryptominerDomains = Self.knownCryptominerDomains
        fingerprintingPatterns = Self.knownFingerprintingScriptPatterns
    }

    func loadTrackerDatabase(_ trackers: [String: TrackerInfo]) {
        knownTrackers = trackers
    }

    func analyze(_ request: InterceptedRequest) -> [ThreatEvent] {
        let domain = extractRegistrableDomain(from: request.url.host?.lowercased() ?? "")
        var events: [ThreatEvent] = []

        if let trackerEvent = detectTracker(request, domain: domain) {
            events.append(trackerEvent)
        }

        if let fingerprintEvent = detectFingerprinting(request, domain: domain) {
            events.append(fingerprintEvent)
        }

        if let exfilEvent = detectDataExfiltration(request, domain: domain) {
            events.append(exfilEvent)
        }

        if let cookieEvent = detectCookieAbuse(request, domain: domain) {
            events.append(cookieEvent)
        }

        if let minerEvent = detectCryptominer(request, domain: domain) {
            events.append(minerEvent)
        }

        for event in events {
            delegate?.threatDetector(self, didDetect: event)
        }

        return events
    }

    func classifyRequest(requestURL: URL, pageURL: URL) -> Bool {
        guard let requestHost = requestURL.host?.lowercased(),
            let pageHost = pageURL.host?.lowercased()
        else {
            return false
        }

        let requestDomain = extractRegistrableDomain(from: requestHost)
        let pageDomain = extractRegistrableDomain(from: pageHost)

        return requestDomain != pageDomain
    }

    private static let commonCompoundTLDs: Set<String> = [
        "co.uk", "org.uk", "me.uk", "net.uk", "gov.uk", "ac.uk",
        "co.jp", "ne.jp", "or.jp", "ac.jp", "go.jp",
        "com.au", "net.au", "org.au", "edu.au", "gov.au",
        "co.nz", "net.nz", "org.nz", "geek.nz", "kiwi.nz",
        "co.za", "gov.za", "org.za", "ac.za", "net.za",
        "com.br", "net.br", "org.br", "gov.br", "edu.br",
        "com.mx", "org.mx", "gob.mx", "edu.mx", "net.mx",
        "co.in", "net.in", "org.in", "gov.in", "ac.in",
        "com.sg", "net.sg", "org.sg", "gov.sg", "edu.sg",
    ]

    func extractRegistrableDomain(from host: String) -> String {
        let parts = host.split(separator: ".")

        if parts.count <= 2 {
            return host
        }

        let lastTwo = parts.suffix(2).joined(separator: ".")
        if Self.commonCompoundTLDs.contains(lastTwo) {
            if parts.count >= 3 {
                return parts.suffix(3).joined(separator: ".")
            }
        }

        return parts.suffix(2).joined(separator: ".")
    }

    private func detectTracker(_ request: InterceptedRequest, domain: String) -> ThreatEvent? {
        guard request.isThirdParty else { return nil }
        guard let tracker = lookupTracker(domain: domain) else { return nil }

        let severity: ThreatSeverity

        switch tracker.category {
        case .advertising:
            severity = .high

        case .analytics:
            severity = .medium

        case .social:
            severity = .medium

        case .fingerprinting:
            severity = .critical

        case .cryptomining:
            severity = .critical

        case .unknown:
            severity = .low
        }

        let entity = ThreatEntity(
            name: tracker.entityName,
            domains: tracker.domains,
            category: tracker.category,
            privacyPolicyURL: nil,
            abuseContactEmail: nil
        )

        return ThreatEvent(
            id: UUID(),
            timestamp: request.timestamp,
            type: .tracker,
            severity: severity,
            sourceURL: request.url,
            sourceDomain: domain,
            pageURL: request.pageURL,
            entity: entity,
            details: "\(tracker.entityName) tracker loaded from \(domain)",
            dataAtRisk: [.browsingHistory, .cookieData]
        )
    }

    private func detectFingerprinting(_ request: InterceptedRequest, domain: String) -> ThreatEvent? {
        guard request.resourceType == .script else { return nil }

        let urlString = request.url.absoluteString.lowercased()

        let isKnownFingerprintScript = fingerprintingPatterns.contains { pattern in
            urlString.contains(pattern)
        }

        guard isKnownFingerprintScript else { return nil }

        return ThreatEvent(
            id: UUID(),
            timestamp: request.timestamp,
            type: .fingerprinter,
            severity: .critical,
            sourceURL: request.url,
            sourceDomain: domain,
            pageURL: request.pageURL,
            entity: nil,
            details: "Fingerprinting script detected from \(domain)",
            dataAtRisk: [.deviceFingerprint, .browsingHistory]
        )
    }

    func analyzeHookedFingerprint(request: InterceptedRequest, api: String) {
        let domain = extractRegistrableDomain(from: request.url.host?.lowercased() ?? "")

        guard Self.fingerprintAPIs.contains(api) else { return }

        guard request.isThirdParty else { return }

        let trackerInfo = lookupTracker(domain: domain)
        let isKnownTracker = trackerInfo != nil

        let severity: ThreatSeverity = isKnownTracker ? .critical : .medium

        var entity: ThreatEntity? = nil
        if let tracker = trackerInfo {
            entity = ThreatEntity(
                name: tracker.entityName,
                domains: tracker.domains,
                category: tracker.category,
                privacyPolicyURL: nil,
                abuseContactEmail: nil
            )
        }

        let event = ThreatEvent(
            id: UUID(),
            timestamp: request.timestamp,
            type: .fingerprinter,
            severity: severity,
            sourceURL: request.url,
            sourceDomain: domain,
            pageURL: request.pageURL,
            entity: entity,
            details: "Active cross-site fingerprinting detected: accessed \(api)",
            dataAtRisk: [.deviceFingerprint]
        )

        delegate?.threatDetector(self, didDetect: event)
    }

    private func detectDataExfiltration(_ request: InterceptedRequest, domain: String) -> ThreatEvent? {
        guard request.isThirdParty else { return nil }

        guard let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems
        else {
            return nil
        }

        var suspiciousParams: [String] = []

        for item in queryItems {
            let key = item.name.lowercased()
            if Self.suspiciousQueryKeys.contains(key) {
                suspiciousParams.append(item.name)
            }
        }

        guard !suspiciousParams.isEmpty else { return nil }

        let dataRisk: [DataCategory] = suspiciousParams.compactMap { param in
            let lower = param.lowercased()
            if lower.contains("email") || lower.contains("mail") { return .personalIdentifiers }
            if lower.contains("lat") || lower.contains("lon") || lower.contains("location") {
                return .locationData
            }
            if lower.contains("fingerprint") || lower.contains("fp") { return .deviceFingerprint }
            if lower.contains("device") || lower.contains("id") { return .personalIdentifiers }
            return .browsingHistory
        }

        let severity: ThreatSeverity = suspiciousParams.count >= 3 ? .critical : .high

        return ThreatEvent(
            id: UUID(),
            timestamp: request.timestamp,
            type: .dataExfiltration,
            severity: severity,
            sourceURL: request.url,
            sourceDomain: domain,
            pageURL: request.pageURL,
            entity: nil,
            details:
                "Suspicious data exfiltration via parameters: \(suspiciousParams.joined(separator: ", "))",
            dataAtRisk: Array(Set(dataRisk))
        )
    }

    private func detectCookieAbuse(_ request: InterceptedRequest, domain: String) -> ThreatEvent? {
        guard request.isThirdParty else { return nil }

        let hasCookieSyncIndicators: Bool = {
            guard let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false),
                let queryItems = components.queryItems
            else {
                return false
            }

            let keys = Set(queryItems.map { $0.name.lowercased() })
            let syncKeys: Set<String> = [
                "partner", "partner_id", "sync", "sync_id", "cookie_id", "match", "cm", "csync",
            ]

            return !keys.isDisjoint(with: syncKeys)
        }()

        guard hasCookieSyncIndicators else { return nil }

        return ThreatEvent(
            id: UUID(),
            timestamp: request.timestamp,
            type: .cookieAbuse,
            severity: .high,
            sourceURL: request.url,
            sourceDomain: domain,
            pageURL: request.pageURL,
            entity: nil,
            details: "Cookie syncing detected with \(domain)",
            dataAtRisk: [.cookieData, .browsingHistory]
        )
    }

    private func detectCryptominer(_ request: InterceptedRequest, domain: String) -> ThreatEvent? {
        guard request.resourceType == .script else { return nil }
        guard cryptominerDomains.contains(domain) else { return nil }

        return ThreatEvent(
            id: UUID(),
            timestamp: request.timestamp,
            type: .cryptominer,
            severity: .critical,
            sourceURL: request.url,
            sourceDomain: domain,
            pageURL: request.pageURL,
            entity: ThreatEntity(
                name: domain,
                domains: [domain],
                category: .cryptomining,
                privacyPolicyURL: nil,
                abuseContactEmail: nil
            ),
            details: "Cryptomining script detected from \(domain)",
            dataAtRisk: []
        )
    }

    private func lookupTracker(domain: String) -> TrackerInfo? {
        if let direct = knownTrackers[domain] {
            return direct
        }

        let parts = domain.split(separator: ".")

        if parts.count > 2 {
            let parent = parts.suffix(2).joined(separator: ".")
            return knownTrackers[parent]
        }

        return nil
    }
}
