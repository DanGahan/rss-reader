//
//  ArticleDetailViewModel.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import AppKit
import Combine
import CoreData
import Foundation

/// ViewModel managing article detail display and actions.
///
/// Provides mark-as-read logic, HTML-stripped plain text
/// content, date formatting, and Safari integration.
@MainActor
final class ArticleDetailViewModel: ObservableObject {
    /// Whether to show the "Opened in Safari" toast.
    @Published var showOpenedToast = false

    private var toastTimer: AnyCancellable?

    // MARK: - Date Formatting

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()

    /// Formats a date for display in the article header.
    func formattedDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    // MARK: - Content

    /// Returns the article body as plain text, stripping
    /// HTML tags. Prefers `content` over `summary`.
    func plainTextContent(
        for article: CDArticle
    ) -> String {
        let raw = article.content
            ?? article.summary
            ?? ""
        return raw.stripHTML()
    }

    // MARK: - Actions

    /// Marks the article as read in Core Data if it is
    /// currently unread. Saves the context immediately so
    /// unread counts update reactively.
    func markAsRead(
        _ article: CDArticle,
        in context: NSManagedObjectContext
    ) {
        guard !article.isRead else { return }
        article.isRead = true
        try? context.save()
    }

    /// Opens the URL in the background (without activating
    /// Safari) and returns whether the open was attempted.
    @discardableResult
    func openInSafari(urlString: String) -> Bool {
        guard !urlString.isEmpty,
              let url = URL(string: urlString),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme)
        else { return false }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.open(
            url,
            configuration: config
        )
        return true
    }

    /// Opens the URL in background Safari and shows a
    /// brief toast notification.
    func openInSafariWithFeedback(urlString: String) {
        guard openInSafari(urlString: urlString) else {
            return
        }
        showOpenedToast = true
        toastTimer?.cancel()
        toastTimer = Just(false)
            .delay(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] value in
                self?.showOpenedToast = value
            }
    }
}
