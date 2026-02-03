//
//  ArticleListViewModel.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import Combine
import CoreData
import Foundation

/// ViewModel managing article list selection, filtering,
/// and navigation state.
///
/// Article data comes from Core Data `@FetchRequest` in the
/// view; navigation methods accept an article array so the
/// ViewModel stays testable without a managed-object context.
@MainActor
final class ArticleListViewModel: ObservableObject {
    /// The currently selected article's ID.
    @Published var selectedArticleId: String?

    /// When true the view should filter to unread articles.
    @Published var showUnreadOnly = false

    /// Indicates a feed refresh is in progress.
    @Published var isLoading = false

    // MARK: - Selection

    func selectArticle(_ id: String) {
        selectedArticleId = id
    }

    func clearSelection() {
        selectedArticleId = nil
    }

    // MARK: - Navigation

    /// Selects the next article in the list relative to the
    /// current selection. Selects the first article if
    /// nothing is selected.
    func selectNext(from articleIds: [String]) {
        guard !articleIds.isEmpty else { return }

        guard
            let currentId = selectedArticleId,
            let index = articleIds.firstIndex(of: currentId),
            index + 1 < articleIds.count
        else {
            selectedArticleId = articleIds.first
            return
        }
        selectedArticleId = articleIds[index + 1]
    }

    /// Selects the previous article in the list. Does
    /// nothing if already at the top or nothing is selected.
    func selectPrevious(from articleIds: [String]) {
        guard
            let currentId = selectedArticleId,
            let index = articleIds.firstIndex(of: currentId),
            index > 0
        else { return }
        selectedArticleId = articleIds[index - 1]
    }

    /// Advances to the next unread article, searching
    /// forward from the current position and wrapping around
    /// to the beginning if needed.
    ///
    /// - Parameter unreadIds: Ordered IDs of articles whose
    ///   `isRead` is false.
    func selectNextUnread(
        from articleIds: [String],
        unreadIds: Set<String>
    ) {
        guard !articleIds.isEmpty else { return }

        let startIndex: Int
        if let currentId = selectedArticleId,
           let idx = articleIds.firstIndex(of: currentId) {
            startIndex = idx + 1
        } else {
            startIndex = 0
        }

        // Search forward from current position
        for i in startIndex..<articleIds.count
        where unreadIds.contains(articleIds[i]) {
            selectedArticleId = articleIds[i]
            return
        }

        // Wrap around from beginning
        let limit = min(startIndex, articleIds.count)
        for i in 0..<limit
        where unreadIds.contains(articleIds[i]) {
            selectedArticleId = articleIds[i]
            return
        }
    }

    // MARK: - Batch Actions

    /// Marks all unread articles in the array as read and
    /// saves the context once.
    func markAllAsRead(
        _ articles: [CDArticle],
        in context: NSManagedObjectContext
    ) {
        let unread = articles.filter { !$0.isRead }
        guard !unread.isEmpty else { return }
        for article in unread {
            article.isRead = true
        }
        try? context.save()
    }
}
