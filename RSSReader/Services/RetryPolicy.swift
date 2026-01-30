//
//  RetryPolicy.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import Foundation

/// Exponential-backoff retry policy for feed fetches.
///
/// Calculates delay as `baseDelay * 2^attempt`, clamped to
/// `maxDelay`. Jitter is not applied so tests are
/// deterministic — callers may add jitter if desired.
struct RetryPolicy: Sendable {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval

    /// Default policy: up to 5 retries, 5 s base, 5 min cap.
    static let `default` = RetryPolicy(
        maxRetries: 5,
        baseDelay: 5,
        maxDelay: 300
    )

    /// Aggressive policy for user-initiated retries.
    static let immediate = RetryPolicy(
        maxRetries: 3,
        baseDelay: 1,
        maxDelay: 10
    )

    /// Whether another retry is allowed for this attempt
    /// number (0-based).
    func shouldRetry(attempt: Int) -> Bool {
        attempt < maxRetries
    }

    /// Backoff delay in seconds for a given attempt
    /// (0-based). Returns 0 for attempt 0.
    func delay(for attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let raw = baseDelay * pow(2, Double(attempt - 1))
        return min(raw, maxDelay)
    }
}
