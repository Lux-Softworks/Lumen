import Foundation
import SwiftUI
import Combine
import os

enum BootstrapPhase: Equatable, Sendable {
    case pending
    case initializing
    case ready
    case failed(String)

    var isReady: Bool { self == .ready }

    var failureMessage: String? {
        if case .failed(let m) = self { return m }
        return nil
    }
}

@MainActor
final class AppBootstrap: ObservableObject {
    static let shared = AppBootstrap()

    @Published private(set) var knowledgeStorage: BootstrapPhase = .pending

    private init() {}

    func start() {
        guard knowledgeStorage == .pending || knowledgeStorage.failureMessage != nil else { return }
        knowledgeStorage = .initializing

        Task { [weak self] in
            do {
                try await KnowledgeStorage.shared.initialize()
                await MainActor.run { self?.knowledgeStorage = .ready }
            } catch {
                let description = String(describing: error)
                KnowledgeLogger.storage.error("KnowledgeStorage init failed: \(description, privacy: .public)")
                await MainActor.run { self?.knowledgeStorage = .failed(description) }
            }
        }
    }

    func retry() {
        knowledgeStorage = .pending
        start()
    }
}
