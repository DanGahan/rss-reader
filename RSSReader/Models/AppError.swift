//
//  AppError.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Foundation

/// Application-specific errors with user-friendly messages.
enum AppError: LocalizedError, Identifiable, Equatable {
    case authenticationFailed(String)
    case networkError(String)
    case apiError(statusCode: Int, message: String)
    case invalidResponse
    case rateLimitExceeded
    case tokenExpired
    case noInternet

    var id: String {
        errorDescription ?? UUID().uuidString
    }

    var errorDescription: String? {
        switch self {
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case let .apiError(code, message):
            return "Feedly API error (\(code)): \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .tokenExpired:
            return "Session expired. Please log in again."
        case .noInternet:
            return "No internet connection. Unable to connect to Feedly."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noInternet:
            return "Check your internet connection and try again."
        case .tokenExpired:
            return "Please log in again to continue."
        case .rateLimitExceeded:
            return "Wait a few minutes before trying again."
        case .authenticationFailed:
            return "Please try signing in again."
        default:
            return "Please try again later."
        }
    }
}
