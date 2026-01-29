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

    func testAuthenticationViewDisplaysSignInButton() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify the sign in button exists
        let signInButton = app.buttons["Sign in with Feedly"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
    }

    func testAppTitleDisplays() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify the app title is displayed
        let title = app.staticTexts["RSS Reader"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
    }
}
