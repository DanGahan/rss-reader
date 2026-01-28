//
//  AppErrorTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-28.
//

import Testing
@testable import RSSReader

@Suite("AppError Tests")
struct AppErrorTests {

    // MARK: - Error Description Tests

    @Test("Authentication failed error description")
    func authenticationFailedDescription() {
        let error = AppError.authenticationFailed("Invalid credentials")
        #expect(
            error.errorDescription ==
            "Authentication failed: Invalid credentials"
        )
    }

    @Test("Network error description")
    func networkErrorDescription() {
        let error = AppError.networkError("Connection timeout")
        #expect(
            error.errorDescription ==
            "Network error: Connection timeout"
        )
    }

    @Test("API error description includes status code and message")
    func apiErrorDescription() {
        let error = AppError.apiError(
            statusCode: 500,
            message: "Internal server error"
        )
        #expect(
            error.errorDescription ==
            "Feedly API error (500): Internal server error"
        )
    }

    @Test("Invalid response error description")
    func invalidResponseDescription() {
        let error = AppError.invalidResponse
        #expect(error.errorDescription == "Invalid response from server")
    }

    @Test("Rate limit exceeded error description")
    func rateLimitExceededDescription() {
        let error = AppError.rateLimitExceeded
        #expect(
            error.errorDescription ==
            "Rate limit exceeded. Please try again later."
        )
    }

    @Test("Token expired error description")
    func tokenExpiredDescription() {
        let error = AppError.tokenExpired
        #expect(
            error.errorDescription ==
            "Session expired. Please log in again."
        )
    }

    @Test("No internet error description")
    func noInternetDescription() {
        let error = AppError.noInternet
        #expect(
            error.errorDescription ==
            "No internet connection. Unable to connect to Feedly."
        )
    }

    // MARK: - Recovery Suggestion Tests

    @Test("No internet recovery suggestion")
    func noInternetRecoverySuggestion() {
        let error = AppError.noInternet
        #expect(
            error.recoverySuggestion ==
            "Check your internet connection and try again."
        )
    }

    @Test("Token expired recovery suggestion")
    func tokenExpiredRecoverySuggestion() {
        let error = AppError.tokenExpired
        #expect(
            error.recoverySuggestion ==
            "Please log in again to continue."
        )
    }

    @Test("Rate limit recovery suggestion")
    func rateLimitExceededRecoverySuggestion() {
        let error = AppError.rateLimitExceeded
        #expect(
            error.recoverySuggestion ==
            "Wait a few minutes before trying again."
        )
    }

    @Test("Auth failed recovery suggestion")
    func authenticationFailedRecoverySuggestion() {
        let error = AppError.authenticationFailed("Test")
        #expect(
            error.recoverySuggestion ==
            "Please try signing in again."
        )
    }

    @Test("Default recovery suggestion")
    func defaultRecoverySuggestion() {
        let error = AppError.invalidResponse
        #expect(error.recoverySuggestion == "Please try again later.")
    }

    // MARK: - Identifiable Tests

    @Test("Errors have identifiers")
    func errorHasId() {
        let error1 = AppError.noInternet
        let error2 = AppError.tokenExpired
        #expect(error1.id != error2.id)
    }

    // MARK: - Equatable Tests

    @Test("Same errors are equal")
    func errorEquality() {
        let error1 = AppError.noInternet
        let error2 = AppError.noInternet
        #expect(error1 == error2)
    }

    @Test("Different errors are not equal")
    func errorInequality() {
        let error1 = AppError.noInternet
        let error2 = AppError.tokenExpired
        #expect(error1 != error2)
    }
}
