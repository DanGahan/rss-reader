//
//  FeedRowView.swift
//  RSSReader
//
//  Created on 2026-01-29.
//

import SwiftUI

/// A single feed row showing an RSS icon, title, unread
/// badge, and optional error overlay.
struct FeedRowView: View {
    @ObservedObject var feed: CDFeed

    var body: some View {
        Label {
            Text(feed.title)
                .lineLimit(1)
        } icon: {
            feedIcon
        }
        .badge(feed.unreadCount)
        .help(feed.lastError ?? feed.feedURL)
    }

    // MARK: - Subviews

    private var feedIcon: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "dot.radiowaves.up.forward")
                .foregroundStyle(.secondary)

            if feed.hasError {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .offset(x: 4, y: 4)
            }
        }
    }
}
