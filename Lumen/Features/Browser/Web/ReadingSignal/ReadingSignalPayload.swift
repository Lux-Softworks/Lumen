import Foundation

struct ReadingSignalPayload: Decodable {
    let url: String
    let title: String
    let readingTime: Int
    let scrollDepth: Double
    let triggered: Bool
}
