//
//  AllArticlesRowView.swift
//  RSSReader
//
//  Created on 2026-02-04.
//

import CoreData
import SwiftUI

/// A row for "All Articles" showing a newspaper icon and
/// total unread count across all feeds, with a spinner when refreshing.
struct AllArticlesRowView: View {
    /// Whether feeds are currently being refreshed.
    var isRefreshing: Bool = false

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
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
            }
            Spacer()
            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .help("Refreshing feeds...")
            } else if !unreadArticles.isEmpty {
                Text("\(unreadArticles.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
        }
    }
}
