//
//  RetryPolicyTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-30.
//

import Testing
@testable import RSSReader

@Suite("RetryPolicy Tests")
struct RetryPolicyTests {

    // MARK: - Should Retry

    @Test("Allows retry within max retries")
    func allowsRetry() {
        let policy = RetryPolicy(
            maxRetries: 3, baseDelay: 1, maxDelay: 60
        )
        #expect(policy.shouldRetry(attempt: 0))
        #expect(policy.shouldRetry(attempt: 2))
    }

    @Test("Denies retry at max retries")
    func deniesRetryAtMax() {
        let policy = RetryPolicy(
            maxRetries: 3, baseDelay: 1, maxDelay: 60
        )
        #expect(!policy.shouldRetry(attempt: 3))
    }

    @Test("Denies retry beyond max retries")
    func deniesRetryBeyondMax() {
        let policy = RetryPolicy(
            maxRetries: 2, baseDelay: 1, maxDelay: 60
        )
        #expect(!policy.shouldRetry(attempt: 5))
    }

    // MARK: - Delay Calculation

    @Test("First attempt has zero delay")
    func firstAttemptZeroDelay() {
        let policy = RetryPolicy.default
        #expect(policy.delay(for: 0) == 0)
    }

    @Test("Delay doubles with each attempt")
    func exponentialBackoff() {
        let policy = RetryPolicy(
            maxRetries: 5, baseDelay: 2, maxDelay: 1000
        )
        #expect(policy.delay(for: 1) == 2)   // 2 * 2^0
        #expect(policy.delay(for: 2) == 4)   // 2 * 2^1
        #expect(policy.delay(for: 3) == 8)   // 2 * 2^2
        #expect(policy.delay(for: 4) == 16)  // 2 * 2^3
    }

    @Test("Delay is clamped to maxDelay")
    func delayClamped() {
        let policy = RetryPolicy(
            maxRetries: 10, baseDelay: 5, maxDelay: 30
        )
        // Attempt 4: 5 * 2^3 = 40 → clamped to 30
        #expect(policy.delay(for: 4) == 30)
        #expect(policy.delay(for: 8) == 30)
    }

    // MARK: - Presets

    @Test("Default policy has expected values")
    func defaultPreset() {
        let policy = RetryPolicy.default
        #expect(policy.maxRetries == 5)
        #expect(policy.baseDelay == 5)
        #expect(policy.maxDelay == 300)
    }

    @Test("Immediate policy has expected values")
    func immediatePreset() {
        let policy = RetryPolicy.immediate
        #expect(policy.maxRetries == 3)
        #expect(policy.baseDelay == 1)
        #expect(policy.maxDelay == 10)
    }
}
