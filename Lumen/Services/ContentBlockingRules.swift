import CryptoKit
import Foundation
import WebKit
import os

nonisolated struct ContentRuleSource: Sendable {
    let blockList: TrackerBlockList
    let trackingRules: String
    let mixedContentRules: String
}

@MainActor
final class ContentBlockingRules {
    struct Compiled {
        let tracking: WKContentRuleList
        let mixedContent: WKContentRuleList
        let blockList: TrackerBlockList
    }

    enum CompileFailure: Error {
        case emptyResult(String)
    }

    static let shared = ContentBlockingRules()

    private static let trackingPrefix = "lumen.tracking"
    private static let mixedContentPrefix = "lumen.mixed-content"
    private static let logger = AppLogger.make("ContentBlocking")

    private var loading: Task<Compiled?, Never>?

    private init() {}

    func compiled() async -> Compiled? {
        if let loading {
            return await loading.value
        }

        let task = Task { await Self.load() }
        loading = task
        let result = await task.value

        if result == nil {
            loading = nil
        }

        return result
    }

    static func apply(
        _ compiled: Compiled,
        to controller: WKUserContentController,
        blocksTrackers: Bool,
        upgradesMixedContent: Bool
    ) {
        controller.removeAllContentRuleLists()

        if blocksTrackers {
            controller.add(compiled.tracking)
        }

        if upgradesMixedContent {
            controller.add(compiled.mixedContent)
        }
    }

    nonisolated static func identifier(prefix: String, encodedRules: String) -> String {
        let digest = SHA256.hash(data: Data(encodedRules.utf8))
        let hex = digest.prefix(8).map { String(format: "%02x", $0) }.joined()

        return prefix + "." + hex
    }

    private static func load() async -> Compiled? {
        do {
            await TrackerDatabase.shared.ensureLoaded()
            let source = try await TrackerDatabase.shared.contentRuleSource()
            let store: WKContentRuleListStore = WKContentRuleListStore.default()
            let tracking = try await ruleList(prefix: trackingPrefix, encodedRules: source.trackingRules, store: store)
            let mixedContent = try await ruleList(
                prefix: mixedContentPrefix,
                encodedRules: source.mixedContentRules,
                store: store
            )

            return Compiled(tracking: tracking, mixedContent: mixedContent, blockList: source.blockList)
        } catch {
            let reason = String(describing: error)
            logger.error(
                "Content rule compile failed: \(reason, privacy: .public)"
            )

            return nil
        }
    }

    private static func ruleList(
        prefix: String,
        encodedRules: String,
        store: WKContentRuleListStore
    ) async throws -> WKContentRuleList {
        let identifier = identifier(prefix: prefix, encodedRules: encodedRules)

        if let cached = try? await store.contentRuleList(forIdentifier: identifier) {
            return cached
        }

        await removeStaleLists(prefix: prefix, keeping: identifier, store: store)

        guard
            let compiled = try await store.compileContentRuleList(
                forIdentifier: identifier,
                encodedContentRuleList: encodedRules
            )
        else {
            throw CompileFailure.emptyResult(identifier)
        }

        return compiled
    }

    private static func removeStaleLists(prefix: String, keeping identifier: String, store: WKContentRuleListStore) async {
        let identifiers = await store.availableIdentifiers() ?? []

        for stale in identifiers where stale.hasPrefix(prefix + ".") && stale != identifier {
            try? await store.removeContentRuleList(forIdentifier: stale)
        }
    }
}
