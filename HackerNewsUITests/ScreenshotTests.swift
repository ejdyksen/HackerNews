import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppStoreScreenshots() throws {
        let listApp = launchApp()
        let listRow = waitForLoadedList(in: listApp)
        XCTAssertTrue(listRow.exists)
        snapshot("01_List", timeWaitingForIdle: 5)
        listApp.terminate()

        let commentsApp = launchApp()
        waitForLoadedList(in: commentsApp).tap()
        XCTAssertTrue(commentsApp.descendants(matching: .any)["ScreenshotCommentsView"].waitForExistence(timeout: 10))
        snapshot("02_Comments", timeWaitingForIdle: 8)
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
        return app
    }

    @discardableResult
    private func waitForLoadedList(in app: XCUIApplication) -> XCUIElement {
        XCTAssertTrue(app.descendants(matching: .any)["ScreenshotListView"].waitForExistence(timeout: 20))

        let row = app.descendants(matching: .any).matching(identifier: "ScreenshotStoryRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        return row
    }
}
