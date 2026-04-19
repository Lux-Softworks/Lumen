import Foundation

enum ZipArchiver {
    enum ArchiverError: Error { case failed, movedFileMissing }

    static func zip(sourceDir: URL, filename: String) throws -> URL {
        let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: destURL)

        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var moveError: Error?

        coordinator.coordinate(
            readingItemAt: sourceDir,
            options: [.forUploading],
            error: &coordError
        ) { zippedTmp in
            do {
                try FileManager.default.moveItem(at: zippedTmp, to: destURL)
            } catch {
                moveError = error
            }
        }

        if let err = coordError { throw err }
        if let err = moveError { throw err }
        guard FileManager.default.fileExists(atPath: destURL.path) else {
            throw ArchiverError.movedFileMissing
        }
        return destURL
    }
}
