//
//  RSSReaderError.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import Foundation

/// Errors specific to local RSS feed operations — parsing,
/// network fetches, data persistence, and feed management.
///
/// Separate from `AppError`, which covers Feedly auth/API
/// errors.
enum RSSReaderError: LocalizedError, Equatable {
    case invalidFeedURL
    case networkError(String)
    case parsingFailed(String)
    case feedNotFound
    case duplicateFeed
    case coreDataError(String)

    // MARK: - User-Facing Messages

    var errorDescription: String? {
        switch self {
        case .invalidFeedURL:
            return "The feed URL is not valid."
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .parsingFailed:
            return "Could not parse feed content."
        case .feedNotFound:
            return "No feed found at this URL."
        case .duplicateFeed:
            return "This feed is already subscribed."
        case .coreDataError(let detail):
            return "Database error: \(detail)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidFeedURL:
            return "Check the URL and try again."
        case .networkError:
            return "Check your connection and try again."
        case .parsingFailed:
            return "The feed may be temporarily broken."
        case .feedNotFound:
            return "Verify the URL points to an RSS or Atom feed."
        case .duplicateFeed:
            return "You are already subscribed to this feed."
        case .coreDataError:
            return "Try restarting the app."
        }
    }

    // MARK: - Retry Support

    /// Whether this error type is worth retrying.
    var isRetryable: Bool {
        switch self {
        case .networkError, .parsingFailed:
            return true
        case .invalidFeedURL, .feedNotFound,
             .duplicateFeed, .coreDataError:
            return false
        }
    }

    /// Whether this error should trigger a user-facing
    /// alert rather than a silent per-feed indicator.
    var isCritical: Bool {
        switch self {
        case .coreDataError:
            return true
        case .invalidFeedURL, .networkError,
             .parsingFailed, .feedNotFound,
             .duplicateFeed:
            return false
        }
    }
}
