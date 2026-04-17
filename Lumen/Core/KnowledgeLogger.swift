import Foundation
import os

enum KnowledgeLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Lumen"

    static let storage = Logger(subsystem: subsystem, category: "knowledge.storage")
    static let capture = Logger(subsystem: subsystem, category: "knowledge.capture")
    static let query = Logger(subsystem: subsystem, category: "knowledge.query")
    static let rag = Logger(subsystem: subsystem, category: "knowledge.rag")
}
