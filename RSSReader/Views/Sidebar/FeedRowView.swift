//
//  FeedRowView.swift
//  RSSReader
//
//  Created on 2026-01-29.
//

import CoreData
import SwiftUI

/// A single feed row showing an RSS icon, title, unread
/// badge, and optional error overlay.
struct FeedRowView: View {
    @ObservedObject var feed: CDFeed

    /// Fetch unread articles for this feed for real-time count.
    @FetchRequest private var unreadArticles: FetchedResults<CDArticle>

    init(feed: CDFeed) {
        self.feed = feed
        _unreadArticles = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(
                format: "feed.id == %@ AND isRead == NO",
                feed.id as CVarArg
            ),
            animation: .default
        )
    }

    var body: some View {
        HStack {
            Label {
                Text(feed.title)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            } icon: {
                feedIcon
            }
            Spacer()
            if !unreadArticles.isEmpty {
                Text("\(unreadArticles.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
        }
        .help(feed.lastError ?? feed.feedURL)
    }

    // MARK: - Subviews

    private var feedIcon: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "dot.radiowaves.up.forward")
                .font(.system(size: 16))
                .foregroundStyle(.primary)

            if feed.hasError {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .offset(x: 4, y: 4)
            }
        }
    }
}
