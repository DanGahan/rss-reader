//
//  FeedErrorHandlerTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-30.
//

import CoreData
import Foundation
import Testing
@testable import RSSReader

@Suite("FeedErrorHandler Tests")
struct FeedErrorHandlerTests {
    // MARK: - Helpers

    private func makeFeed(
        _ context: NSManagedObjectContext
    ) -> CDFeed {
        CDFeed.create(
            in: context,
            title: "Test Feed",
            feedURL: "https://example.com/feed"
        )
    }

    // MARK: - Record Error

    @Test("recordError sets lastError on feed")
    @MainActor
    func recordErrorSetsFeedError() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = makeFeed(context)
        let handler = FeedErrorHandler()

        handler.recordError(
            .networkError("timeout"),
            for: feed,
            in: context
        )

        #expect(feed.lastError != nil)
        #expect(
            feed.lastError?.contains("timeout") == true
        )
    }

    @Test("recordError sets criticalError for critical errors")
    @MainActor
    func recordCriticalError() {
        let context = CoreDataTestHelper.makeContext()
        let feed = makeFeed(context)
        let handler = FeedErrorHandler()

        handler.recordError(
            .coreDataError("save failed"),
            for: feed,
            in: context
        )

        #expect(
            handler.criticalError
                == .coreDataError("save failed")
        )
    }

    @Test("recordError does not set criticalError for non-critical")
    @MainActor
    func recordNonCriticalError() {
        let context = CoreDataTestHelper.makeContext()
        let feed = makeFeed(context)
        let handler = FeedErrorHandler()

        handler.recordError(
            .networkError("timeout"),
            for: feed,
            in: context
        )

        #expect(handler.criticalError == nil)
    }

    // MARK: - Clear Error

    @Test("clearError resets lastError and retry count")
    @MainActor
    func clearErrorResets() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = makeFeed(context)
        let handler = FeedErrorHandler()

        handler.recordError(
            .networkError("fail"),
            for: feed,
            in: context
        )
        _ = handler.nextRetryDelay(for: feed)

        handler.clearError(for: feed, in: context)

        #expect(feed.lastError == nil)
        #expect(handler.currentAttempt(for: feed) == 0)
    }

    // MARK: - Should Retry

    @Test("shouldRetry returns true for retryable errors")
    @MainActor
    func shouldRetryRetryable() {
        let context = CoreDataTestHelper.makeContext()
        let feed = makeFeed(context)
        let handler = FeedErrorHandler()

        #expect(
            handler.shouldRetry(
                for: feed,
                error: .networkError("timeout")
            )
        )
    }

    @Test("shouldRetry returns false for non-retryable errors")
    @MainActor
    func shouldRetryNonRetryable() {
        let context = CoreDataTestHelper.makeContext()
        let feed = makeFeed(context)
        let handler = FeedErrorHandler()

        #expect(
            !handler.shouldRetry(
                for: feed,
                error: .invalidFeedURL
            )
        )
    }

    @Test("shouldRetry returns false after max retries")
    @MainActor
    func shouldRetryExhausted() {
        let context = CoreDataTestHelper.makeContext()
        let feed = makeFeed(context)
        let policy = RetryPolicy(
            maxRetries: 2, baseDelay: 1, maxDelay: 10
        )
        let handler = FeedErrorHandler(
            retryPolicy: policy
        )

        // Exhaust retries
        _ = handler.nextRetryDelay(for: feed)
        _ = handler.nextRetryDelay(for: feed)

        #expect(
            !handler.shouldRetry(
                for: feed,
                error: .networkError("timeout")
            )
        )
    }

    // MARK: - Retry Delay

    @Test("nextRetryDelay increments attempt counter")
    @MainActor
    func retryDelayIncrements() {
        let context = CoreDataTestHelper.makeContext()
        let feed = makeFeed(context)
        let handler = FeedErrorHandler()

        #expect(handler.currentAttempt(for: feed) == 0)
        _ = handler.nextRetryDelay(for: feed)
        #expect(handler.currentAttempt(for: feed) == 1)
        _ = handler.nextRetryDelay(for: feed)
        #expect(handler.currentAttempt(for: feed) == 2)
    }

    @Test("nextRetryDelay returns increasing delays")
    @MainActor
    func retryDelayIncreases() {
        let context = CoreDataTestHelper.makeContext()
        let feed = makeFeed(context)
        let policy = RetryPolicy(
            maxRetries: 5, baseDelay: 2, maxDelay: 100
        )
        let handler = FeedErrorHandler(
            retryPolicy: policy
        )

        let d1 = handler.nextRetryDelay(for: feed)
        let d2 = handler.nextRetryDelay(for: feed)
        let d3 = handler.nextRetryDelay(for: feed)

        #expect(d1 == 0)  // attempt 0
        #expect(d2 == 2)  // attempt 1: 2 * 2^0
        #expect(d3 == 4)  // attempt 2: 2 * 2^1
    }

    // MARK: - Reset

    @Test("resetRetryCount clears attempt counter")
    @MainActor
    func resetRetryCount() {
        let context = CoreDataTestHelper.makeContext()
        let feed = makeFeed(context)
        let handler = FeedErrorHandler()

        _ = handler.nextRetryDelay(for: feed)
        _ = handler.nextRetryDelay(for: feed)
        handler.resetRetryCount(for: feed)

        #expect(handler.currentAttempt(for: feed) == 0)
    }

    // MARK: - Independent Feeds

    @Test("Retry state is independent per feed")
    @MainActor
    func independentFeeds() {
        let context = CoreDataTestHelper.makeContext()
        let feed1 = makeFeed(context)
        let feed2 = CDFeed.create(
            in: context,
            title: "Other",
            feedURL: "https://other.com/feed"
        )
        let handler = FeedErrorHandler()

        _ = handler.nextRetryDelay(for: feed1)
        _ = handler.nextRetryDelay(for: feed1)

        #expect(handler.currentAttempt(for: feed1) == 2)
        #expect(handler.currentAttempt(for: feed2) == 0)
    }
}
