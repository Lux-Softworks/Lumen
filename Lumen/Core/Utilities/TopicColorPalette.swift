import Foundation

enum TopicColorPalette {
    static let hexColors: [String] = [
        "#E57373", // coral
        "#F06292", // rose
        "#BA68C8", // orchid
        "#9575CD", // lavender
        "#7986CB", // iris
        "#64B5F6", // sky
        "#4FC3F7", // azure
        "#4DD0E1", // teal
        "#4DB6AC", // seafoam
        "#81C784", // fern
        "#AED581", // lime
        "#DCE775", // chartreuse
        "#FFD54F", // amber
        "#FFB74D", // marigold
        "#FF8A65", // persimmon
        "#A1887F", // walnut
        "#90A4AE"  // slate
    ]

    static func hex(for name: String) -> String {
        guard !hexColors.isEmpty else { return "#7F7F7F" }
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let index = Int(stableHash(key) % UInt64(hexColors.count))
        return hexColors[index]
    }

    private static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
