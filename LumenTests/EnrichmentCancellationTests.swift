import Testing
import Foundation
import Synchronization
@testable import Lumen

struct EnrichmentCancellationTests {
    private final class EnrichmentNoticeCounter: Sendable {
        let count = Mutex(0)
    }

    @Test func cancelledEnrichmentPostsNoCompletionNotice() async {
        let counter = EnrichmentNoticeCounter()
        let observer = NotificationCenter.default.addObserver(
            forName: .knowledgeCaptured,
            object: nil,
            queue: nil
        ) { notification in
            guard notification.userInfo?["stage"] as? String == "enrichment" else { return }
            counter.count.withLock { $0 += 1 }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let extracted = ExtractedContent(
            url: "https://example.com/actors",
            title: "Actors",
            content: "actors isolate state",
            timestamp: Date(),
            author: nil,
            description: nil,
            siteName: nil
        )
        let enrichment = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await KnowledgeCaptureService.runEnrichment(
                pageID: "cancelled-page",
                extracted: extracted,
                newlyCreatedWebsiteID: nil,
                topicCandidates: [],
                provisionalTopicName: nil
            )
        }
        await enrichment.value

        #expect(counter.count.withLock { $0 } == 0)
    }
}
