import Foundation

nonisolated enum ReadingDuration {
    static func label(seconds: Int) -> String {
        guard seconds >= 60 else { return "<1m" }

        let minutes = seconds / 60
        guard minutes >= 60 else { return "\(minutes)m" }

        let hours = minutes / 60
        let leftoverMinutes = minutes % 60

        return leftoverMinutes == 0 ? "\(hours)h" : "\(hours)h \(leftoverMinutes)m"
    }
}
