import XCTest

@testable import Lumen

final class LocalKnowledgeProviderTests: XCTestCase {

    var knowledgeProvider: LocalKnowledgeProvider!

    override func setUp() async throws {
        knowledgeProvider = LocalKnowledgeProvider()
    }

    func testHeuristicRoutingAction() async {
        let expectation = XCTestExpectation(description: "Model response")
        let input = "Click the login button"

        Task {
            let intent = await knowledgeProvider.route(input)
            XCTAssertEqual(intent, .action, "Should detect 'click' as an action intent")
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 120.0)
    }

    func testHeuristicRoutingContext() async {
        let expectation = XCTestExpectation(description: "Model response")
        let input = "Summarize this page"

        Task {
            let intent = await knowledgeProvider.route(input)
            XCTAssertEqual(intent, .context, "Should detect 'summarize' as a context intent")
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 120.0)
    }

    func testDefaultToKnowledge() async {
        let expectation = XCTestExpectation(description: "Model response")
        let input = "What is the capital of France?"

        Task {
            let intent = await knowledgeProvider.route(input)
            XCTAssertEqual(
                intent, .knowledge, "Should default to knowledge intent for unknown patterns")
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 120.0)
    }
}
