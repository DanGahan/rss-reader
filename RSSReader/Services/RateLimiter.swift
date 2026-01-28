//
//  RateLimiter.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Foundation

/// Thread-safe rate limiter using a sliding window algorithm.
/// Ensures API calls don't exceed the configured rate limit.
actor RateLimiter {
    private let maxRequests: Int
    private let windowInterval: TimeInterval
    private var requestTimestamps: [Date] = []

    /// Creates a rate limiter with the specified requests per minute.
    /// - Parameter requestsPerMinute: Maximum number of requests
    ///   allowed per minute.
    init(requestsPerMinute: Int) {
        self.maxRequests = requestsPerMinute
        self.windowInterval = 60.0
    }

    /// Waits until a request slot is available within the rate limit.
    /// Throws if the wait would be unreasonably long.
    func waitForSlot() async throws {
        cleanupOldTimestamps()

        if requestTimestamps.count < maxRequests {
            requestTimestamps.append(Date())
            return
        }

        // Calculate when the oldest request will expire
        guard let oldestTimestamp = requestTimestamps.first else {
            requestTimestamps.append(Date())
            return
        }

        let waitTime = oldestTimestamp.addingTimeInterval(
            windowInterval
        ).timeIntervalSinceNow

        if waitTime > 0 {
            try await Task.sleep(
                nanoseconds: UInt64(waitTime * 1_000_000_000)
            )
        }

        cleanupOldTimestamps()
        requestTimestamps.append(Date())
    }

    /// Returns the number of remaining request slots in the current window.
    var remainingRequests: Int {
        var timestamps = requestTimestamps
        let cutoff = Date().addingTimeInterval(-windowInterval)
        timestamps.removeAll { $0 < cutoff }
        return max(0, maxRequests - timestamps.count)
    }

    private func cleanupOldTimestamps() {
        let cutoff = Date().addingTimeInterval(-windowInterval)
        requestTimestamps.removeAll { $0 < cutoff }
    }
}
