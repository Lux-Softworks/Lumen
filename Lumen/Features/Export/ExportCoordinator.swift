import Foundation

actor ExportCoordinator {
    static let shared = ExportCoordinator()

    struct Request: Sendable {
        enum Scope: Sendable, Hashable {
            case wholeBase
            case topic(id: String)
            case site(id: String)
            case page(id: String)
            case dateRange(start: Date, end: Date)
        }

        struct Toggles: Sendable {
            var includeAnnotations: Bool = true
            var includeAISummaries: Bool = true
            var includeEmbeddings: Bool = true
            var includeTimestamps: Bool = true
        }

        let scope: Scope
        let toggles: Toggles
    }

    enum Progress: Sendable {
        case fetching
        case writing(current: Int, total: Int)
        case zipping
        case finished(URL)
        case cancelled
        case failed(String)
    }

    func run(_ request: Request) -> AsyncStream<Progress> {
        AsyncStream { continuation in
            let task = Task {
                let tmpRoot = Self.makeTmpRoot()
                defer { try? FileManager.default.removeItem(at: tmpRoot) }

                do {
                    continuation.yield(.fetching)

                    let payload = try await ExportPayloadBuilder.build(
                        scope: request.scope,
                        includeEmbeddings: request.toggles.includeEmbeddings
                    )

                    if payload.pages.isEmpty {
                        continuation.yield(.failed("No knowledge in this scope"))
                        continuation.finish()
                        return
                    }

                    let vaultDir = tmpRoot.appendingPathComponent("vault")
                    let jsonURL = tmpRoot.appendingPathComponent("knowledge.json")
                    try FileManager.default.createDirectory(at: vaultDir, withIntermediateDirectories: true)

                    try await Task.detached(priority: .utility) {
                        try MarkdownVaultWriter.write(
                            payload: payload,
                            toggles: request.toggles,
                            into: vaultDir,
                            onProgress: { done, total in
                                continuation.yield(.writing(current: done, total: total))
                            },
                            shouldCancel: { Task.isCancelled }
                        )
                    }.value

                    try await Task.detached(priority: .utility) {
                        try JSONBundleWriter.write(
                            payload: payload,
                            scope: request.scope,
                            toggles: request.toggles,
                            to: jsonURL
                        )
                    }.value

                    continuation.yield(.zipping)
                    let zipFilename = Self.makeZipFilename(for: request)
                    let zipURL = try await Task.detached(priority: .utility) {
                        try ZipArchiver.zip(sourceDir: tmpRoot, filename: zipFilename)
                    }.value

                    continuation.yield(.finished(zipURL))
                } catch is CancellationError {
                    continuation.yield(.cancelled)
                } catch {
                    continuation.yield(.failed(error.localizedDescription))
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func makeTmpRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("lumen-export-\(UUID().uuidString)", isDirectory: true)
    }

    private static func makeZipFilename(for request: Request) -> String {
        let date = DateFormatters.ymd.string(from: Date())
        let suffix: String
        switch request.scope {
        case .wholeBase: suffix = "Full"
        case .topic: suffix = "Topic"
        case .site: suffix = "Site"
        case .page: suffix = "Page"
        case .dateRange: suffix = "Range"
        }
        return "Lumen-Knowledge-\(suffix)-\(date).zip"
    }
}
