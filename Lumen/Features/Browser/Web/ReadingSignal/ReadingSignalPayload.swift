import Foundation

nonisolated struct ReadingSignalPayload: Decodable, Sendable {
    let url: String
    let title: String
    let readingTime: Int
    let scrollDepth: Double
    let triggered: Bool
    let isUpdate: Bool

    enum CodingKeys: String, CodingKey {
        case url, title, readingTime, scrollDepth, triggered, isUpdate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(String.self, forKey: .url)
        title = try container.decode(String.self, forKey: .title)
        readingTime = try container.decode(Int.self, forKey: .readingTime)
        scrollDepth = try container.decode(Double.self, forKey: .scrollDepth)
        triggered = try container.decode(Bool.self, forKey: .triggered)
        isUpdate = (try? container.decode(Bool.self, forKey: .isUpdate)) ?? false
    }

    init(url: String, title: String, readingTime: Int, scrollDepth: Double, triggered: Bool, isUpdate: Bool) {
        self.url = url
        self.title = title
        self.readingTime = readingTime
        self.scrollDepth = scrollDepth
        self.triggered = triggered
        self.isUpdate = isUpdate
    }
}
