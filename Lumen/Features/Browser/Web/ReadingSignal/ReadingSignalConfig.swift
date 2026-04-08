import Foundation

struct ReadingSignalConfig {
    var dwellThresholdSeconds: Int = 30
    var scrollDepthThreshold: Double = 0.4
    var pollIntervalMs: Int = 5000
    var excludedHostKeywords: [String] = ["bank", "banking", "account", "health"]
    var excludedHosts: [String] = ["mail.google.com", "outlook.com"]

    static let `default` = ReadingSignalConfig()
}
