//
//  RSSReaderUITests.swift
//  RSSReaderUITests
//
//  Created on 2026-01-28.
//

import XCTest

final class RSSReaderUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesWithSidebar() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify the All Articles row is displayed in the sidebar
        let allArticles = app.staticTexts["All Articles"]
        XCTAssertTrue(allArticles.waitForExistence(timeout: 5))
    }
}
