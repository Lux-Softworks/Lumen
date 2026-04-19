import Foundation
import os

enum FileProtectionVerifier {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Lumen",
        category: "fileprotection"
    )

    static func assert(
        path: String,
        expected: FileProtectionType,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        guard FileManager.default.fileExists(atPath: path) else { return }

        guard
            let attrs = try? FileManager.default.attributesOfItem(atPath: path),
            let actual = attrs[.protectionKey] as? FileProtectionType
        else {
            log.error(
                "protection unknown at \(file, privacy: .public):\(line, privacy: .public)"
            )
            return
        }

        if actual != expected {
            log.error(
                "protection mismatch expected=\(expected.rawValue, privacy: .public) actual=\(actual.rawValue, privacy: .public) at \(file, privacy: .public):\(line, privacy: .public)"
            )
        }
    }

    static func assertDirectory(
        _ path: String,
        expected: FileProtectionType
    ) {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(atPath: path) else { return }
        for child in children {
            assert(path: (path as NSString).appendingPathComponent(child), expected: expected)
        }
    }
}
