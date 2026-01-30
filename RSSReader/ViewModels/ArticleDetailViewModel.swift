//
//  ArticleDetailViewModel.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import AppKit
import CoreData
import Foundation

/// ViewModel managing article detail display and actions.
///
/// Provides mark-as-read logic, HTML-stripped plain text
/// content, date formatting, and Safari integration.
@MainActor
final class ArticleDetailViewModel: ObservableObject {

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

    /// Opens the article link in the default browser.
    func openInSafari(urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
