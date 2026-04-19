import XCTest

final class LumenUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_launch_presentsHomeAndBottomBar() throws {
        let app = XCUIApplication()
        app.launch()

        let tabsButton = app.buttons["bottombar.tabs"]
        let searchOpen = app.buttons["bottombar.searchOpen"]
        let settings = app.buttons["bottombar.settings"]

        XCTAssertTrue(tabsButton.waitForExistence(timeout: 5), "tabs button missing")
        XCTAssertTrue(searchOpen.waitForExistence(timeout: 2), "search button missing")
        XCTAssertTrue(settings.waitForExistence(timeout: 2), "settings button missing")
    }

    func test_tabsButton_disabledWhenNoTabs() throws {
        let app = XCUIApplication()
        app.launch()

        let tabsButton = app.buttons["bottombar.tabs"]
        XCTAssertTrue(tabsButton.waitForExistence(timeout: 5))
        XCTAssertFalse(tabsButton.isEnabled, "tabs button should be disabled on fresh launch")
    }
}
