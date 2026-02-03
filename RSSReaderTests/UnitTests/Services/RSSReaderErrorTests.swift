//
//  RSSReaderErrorTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-30.
//

import Testing
@testable import RSSReader

@Suite("RSSReaderError Tests")
struct RSSReaderErrorTests {
    // MARK: - Error Descriptions

    @Test("invalidFeedURL has description")
    func invalidFeedURLDescription() {
        let err = RSSReaderError.invalidFeedURL
        #expect(
            err.errorDescription?.contains("not valid")
                == true
        )
    }

    @Test("networkError includes detail")
    func networkErrorDescription() {
        let err = RSSReaderError.networkError("timeout")
        #expect(
            err.errorDescription?.contains("timeout")
                == true
        )
    }

    @Test("parsingFailed has description")
    func parsingFailedDescription() {
        let err = RSSReaderError.parsingFailed("bad xml")
        #expect(
            err.errorDescription?.contains("parse")
                == true
        )
    }

    @Test("feedNotFound has description")
    func feedNotFoundDescription() {
        let err = RSSReaderError.feedNotFound
        #expect(
            err.errorDescription?.contains("No feed")
                == true
        )
    }

    @Test("duplicateFeed has description")
    func duplicateFeedDescription() {
        let err = RSSReaderError.duplicateFeed
        #expect(
            err.errorDescription?.contains("already")
                == true
        )
    }

    @Test("coreDataError includes detail")
    func coreDataErrorDescription() {
        let err = RSSReaderError.coreDataError("save")
        #expect(
            err.errorDescription?.contains("save")
                == true
        )
    }

    // MARK: - Recovery Suggestions

    @Test("All errors have recovery suggestions")
    func allHaveRecoverySuggestions() {
        let errors: [RSSReaderError] = [
            .invalidFeedURL,
            .networkError("test"),
            .parsingFailed("test"),
            .feedNotFound,
            .duplicateFeed,
            .coreDataError("test")
        ]
        for error in errors {
            #expect(error.recoverySuggestion != nil)
        }
    }

    // MARK: - Retryable

    @Test("networkError is retryable")
    func networkRetryable() {
        #expect(
            RSSReaderError.networkError("test").isRetryable
        )
    }

    @Test("parsingFailed is retryable")
    func parsingRetryable() {
        #expect(
            RSSReaderError.parsingFailed("test").isRetryable
        )
    }

    @Test("invalidFeedURL is not retryable")
    func invalidURLNotRetryable() {
        #expect(!RSSReaderError.invalidFeedURL.isRetryable)
    }

    @Test("feedNotFound is not retryable")
    func notFoundNotRetryable() {
        #expect(!RSSReaderError.feedNotFound.isRetryable)
    }

    @Test("duplicateFeed is not retryable")
    func duplicateNotRetryable() {
        #expect(!RSSReaderError.duplicateFeed.isRetryable)
    }

    @Test("coreDataError is not retryable")
    func coreDataNotRetryable() {
        #expect(
            !RSSReaderError.coreDataError("x").isRetryable
        )
    }

    // MARK: - Critical

    @Test("coreDataError is critical")
    func coreDataCritical() {
        #expect(
            RSSReaderError.coreDataError("x").isCritical
        )
    }

    @Test("networkError is not critical")
    func networkNotCritical() {
        #expect(
            !RSSReaderError.networkError("x").isCritical
        )
    }

    // MARK: - Equatable

    @Test("Same cases are equal")
    func equality() {
        let feedNotFound1 = RSSReaderError.feedNotFound
        let feedNotFound2 = RSSReaderError.feedNotFound
        #expect(feedNotFound1 == feedNotFound2)

        let network1 = RSSReaderError.networkError("a")
        let network2 = RSSReaderError.networkError("a")
        #expect(network1 == network2)
    }

    @Test("Different cases are not equal")
    func inequality() {
        #expect(
            RSSReaderError.feedNotFound
                != RSSReaderError.duplicateFeed
        )
    }
}
