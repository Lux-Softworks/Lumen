import Foundation

struct ReadingSignalConfig {
    var dwellThresholdSeconds: Int = 12
    var scrollDepthThreshold: Double = 0.3
    var pollIntervalMs: Int = 1500
    var excludedHostKeywords: [String] = ["bank", "banking", "health"]
    var excludedHosts: [String] = ["mail.google.com", "outlook.com"]

    static let `default` = ReadingSignalConfig()
}
