import Foundation

struct ReadingSignalConfig {
    var dwellThresholdSeconds: Int = 25
    var scrollDepthThreshold: Double = 0.4
    var pollIntervalMs: Int = 2000
    var excludedHostKeywords: [String] = ["bank", "banking", "account", "health"]
    var excludedHosts: [String] = ["mail.google.com", "outlook.com"]

    static let `default` = ReadingSignalConfig()
}
