//
//  AppState.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Combine
import Foundation

/// Global application state managing authentication and user session.
@MainActor
final class AppState: ObservableObject {
    /// Whether the user is currently authenticated with Feedly.
    @Published var isAuthenticated = false

    /// The currently logged-in user, if any.
    @Published var currentUser: FeedlyUser?

    /// Global error state for critical errors that need user attention.
    @Published var error: AppError?

    /// Clears the current session and resets to unauthenticated state.
    func logout() {
        isAuthenticated = false
        currentUser = nil
        error = nil
    }
}
