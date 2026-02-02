//
//  AppState.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Combine
import Foundation

/// Global application state managing shared UI state.
@MainActor
final class AppState: ObservableObject {
    /// Global error state for critical errors that need
    /// user attention.
    @Published var error: AppError?

    /// Clears any active error state.
    func clearError() {
        error = nil
    }
}
