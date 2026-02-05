//
//  AllArticlesRowView.swift
//  RSSReader
//
//  Created on 2026-02-04.
//

import CoreData
import SwiftUI

/// A row for "All Articles" showing a newspaper icon and
/// total unread count across all feeds.
struct AllArticlesRowView: View {
    /// Fetch unread articles directly for accurate real-time count.
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "isRead == NO"),
        animation: .default
    ) private var unreadArticles: FetchedResults<CDArticle>

    var body: some View {
        HStack {
            Label {
                Text("All Articles")
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "newspaper")
                    .foregroundStyle(.primary)
            }
            Spacer()
            if !unreadArticles.isEmpty {
                Text("\(unreadArticles.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
        }
    }
}
