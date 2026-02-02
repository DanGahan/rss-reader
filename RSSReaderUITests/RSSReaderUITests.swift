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

    func testAppTitleDisplays() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify the app title is displayed
        let title = app.staticTexts["RSS Reader"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
    }
}
