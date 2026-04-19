import XCTest

final class SettingsFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_tappingSettings_opensSettingsPage() throws {
        let app = XCUIApplication()
        app.launch()

        let settings = app.buttons["bottombar.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        let header = app.textFields["browser.urlField"]
        XCTAssertTrue(header.waitForExistence(timeout: 3), "Settings header field did not appear")
        
        let predicate = NSPredicate(format: "placeholderValue == %@", "Browser Settings")
        let expectation = expectation(for: predicate, evaluatedWith: header, handler: nil)
        let result = XCTWaiter().wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(result, .completed, "Placeholder did not update to 'Browser Settings'")
    }

    func test_tappingKnowledgeTab_opensKnowledgePanel() throws {
        let app = XCUIApplication()
        app.launch()

        let knowledge = app.buttons["bottombar.knowledge"]
        XCTAssertTrue(knowledge.waitForExistence(timeout: 5))
        knowledge.tap()

        let urlField = app.textFields["browser.urlField"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 3))
    }
}
