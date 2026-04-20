import UIKit
import WebKit
import os.log

@available(iOS 14.5, *)
final class DownloadHandler: NSObject, WKDownloadDelegate {

    private let logger = AppLogger.make("Download")
    private var destinationsByDownload: [ObjectIdentifier: URL] = [:]

    static let shared = DownloadHandler()

    static var onDownloadComplete: ((URL) -> Void)?

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let filename = sanitize(filename: suggestedFilename)
        let dir = downloadsDirectory()

        var target = dir.appendingPathComponent(filename)
        target = uniqued(target)

        destinationsByDownload[ObjectIdentifier(download)] = target
        completionHandler(target)
    }

    func downloadDidFinish(_ download: WKDownload) {
        let key = ObjectIdentifier(download)
        guard let url = destinationsByDownload.removeValue(forKey: key) else { return }
        logger.info("download finished: \(url.lastPathComponent, privacy: .public)")

        Task { @MainActor in
            Self.onDownloadComplete?(url)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: any Error, resumeData: Data?) {
        logger.error("download failed: \(String(describing: error), privacy: .public)")
        destinationsByDownload.removeValue(forKey: ObjectIdentifier(download))
    }

    private func downloadsDirectory() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let downloads = base.appendingPathComponent("Downloads", isDirectory: true)
        if !fm.fileExists(atPath: downloads.path) {
            try? fm.createDirectory(at: downloads, withIntermediateDirectories: true)
        }
        return downloads
    }

    private func sanitize(filename: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = filename.components(separatedBy: invalid).joined(separator: "_")
        return cleaned.isEmpty ? "download" : cleaned
    }

    private func uniqued(_ url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let dir = url.deletingLastPathComponent()
        for i in 1..<1000 {
            let name = ext.isEmpty ? "\(base) (\(i))" : "\(base) (\(i)).\(ext)"
            let candidate = dir.appendingPathComponent(name)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return url
    }

    static func shouldDownload(response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse else { return false }
        let disposition = (http.value(forHTTPHeaderField: "Content-Disposition") ?? "").lowercased()
        if disposition.contains("attachment") { return true }

        let contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        let inlineTypes = [
            "text/html", "text/css", "text/javascript", "application/javascript",
            "application/x-javascript", "application/json", "application/xml",
            "image/", "audio/", "video/", "font/", "application/font",
            "application/xhtml+xml", "text/plain", "text/xml"
        ]
        if inlineTypes.contains(where: { contentType.hasPrefix($0) || contentType.contains($0) }) {
            return false
        }

        let downloadableTypes = [
            "application/pdf", "application/zip", "application/x-",
            "application/octet-stream", "application/vnd.",
            "application/msword", "application/x-tar", "application/gzip"
        ]
        return downloadableTypes.contains(where: { contentType.hasPrefix($0) })
    }
}
