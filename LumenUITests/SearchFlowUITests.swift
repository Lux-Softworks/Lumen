import XCTest

final class SearchFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_tappingSearch_revealsURLField() throws {
        let app = XCUIApplication()
        app.launch()

        let searchOpen = app.buttons["bottombar.searchOpen"]
        XCTAssertTrue(searchOpen.waitForExistence(timeout: 5))
        searchOpen.tap()

        let urlField = app.textFields["browser.urlField"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 3), "URL field did not appear")
    }

    func test_urlField_acceptsInput() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["bottombar.searchOpen"].tap()

        let urlField = app.textFields["browser.urlField"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 3))
        urlField.tap()
        urlField.typeText("example.com")

        XCTAssertEqual(urlField.value as? String, "example.com")
    }
}
