import Foundation
import os

enum AppLogger {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.luxsoftworks.Lumen"

    static func make(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}

enum KnowledgeLogger {
    static let storage = AppLogger.make("knowledge.storage")
    static let capture = AppLogger.make("knowledge.capture")
    static let query = AppLogger.make("knowledge.query")
    static let rag = AppLogger.make("knowledge.rag")
}
