nonisolated enum TopicVote {
    static func majority(
        counts: [(topicID: String, count: Int)],
        current: String?
    ) -> String? {
        guard let topCount = counts.map({ $0.count }).max() else { return current }
        let leaders = counts.filter { $0.count == topCount }
        if let current, leaders.contains(where: { $0.topicID == current }) {
            return current
        }
        return leaders.map { $0.topicID }.sorted().first
    }
}
