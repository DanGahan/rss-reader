//
//  FeedErrorHandler.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import CoreData
import Foundation

/// Manages per-feed error state in Core Data and decides
/// whether a failed feed should be retried.
///
/// Feed-level errors are stored on `CDFeed.lastError` so
/// the sidebar can show an error icon. Critical errors are
/// surfaced via the published `criticalError` property for
/// alert presentation.
@MainActor
final class FeedErrorHandler: ObservableObject {
    /// The most recent critical error that should be shown
    /// as an alert. Set to `nil` after the user dismisses.
    @Published var criticalError: RSSReaderError?

    /// Tracks the current retry attempt per feed UUID.
    private var retryAttempts: [UUID: Int] = [:]

    /// The retry policy in effect.
    let retryPolicy: RetryPolicy

    init(retryPolicy: RetryPolicy = .default) {
        self.retryPolicy = retryPolicy
    }

    // MARK: - Error Recording

    /// Records an error against a feed, updating its
    /// `lastError` in Core Data. If the error is critical
    /// it is also published for alert presentation.
    func recordError(
        _ error: RSSReaderError,
        for feed: CDFeed,
        in context: NSManagedObjectContext
    ) {
        feed.lastError = error.errorDescription
        try? context.save()

        ErrorLogger.log(
            error,
            context: "Feed: \(feed.title)"
        )

        if error.isCritical {
            criticalError = error
        }
    }

    /// Clears the error state for a feed and resets its
    /// retry counter.
    func clearError(
        for feed: CDFeed,
        in context: NSManagedObjectContext
    ) {
        feed.lastError = nil
        retryAttempts[feed.id] = nil
        try? context.save()
    }

    // MARK: - Retry Logic

    /// Whether the feed should be retried given its current
    /// attempt count and the nature of the last error.
    func shouldRetry(
        for feed: CDFeed,
        error: RSSReaderError
    ) -> Bool {
        guard error.isRetryable else { return false }
        let attempt = retryAttempts[feed.id] ?? 0
        return retryPolicy.shouldRetry(attempt: attempt)
    }

    /// Returns the backoff delay for the feed's next retry
    /// and increments the attempt counter.
    func nextRetryDelay(for feed: CDFeed) -> TimeInterval {
        let attempt = retryAttempts[feed.id] ?? 0
        retryAttempts[feed.id] = attempt + 1
        return retryPolicy.delay(for: attempt)
    }

    /// Resets the retry counter for a feed (e.g. after a
    /// successful fetch).
    func resetRetryCount(for feed: CDFeed) {
        retryAttempts[feed.id] = nil
    }

    /// Returns the current attempt count for a feed.
    func currentAttempt(for feed: CDFeed) -> Int {
        retryAttempts[feed.id] ?? 0
    }

    // MARK: - UUID-based Methods

    /// Returns the backoff delay for a feed UUID's next retry
    /// and increments the attempt counter.
    func nextRetryDelay(for feedId: UUID) -> TimeInterval {
        let attempt = retryAttempts[feedId] ?? 0
        retryAttempts[feedId] = attempt + 1
        return retryPolicy.delay(for: attempt)
    }

    /// Resets the retry counter for a feed UUID.
    func resetRetryCount(for feedId: UUID) {
        retryAttempts[feedId] = nil
    }
}
