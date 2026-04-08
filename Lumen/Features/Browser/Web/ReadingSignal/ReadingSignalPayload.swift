import Foundation

struct ReadingSignalPayload: Decodable, Sendable {
    let url: String
    let title: String
    let readingTime: Int
    let scrollDepth: Double
    let triggered: Bool
}
