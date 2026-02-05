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

    /// Liquid Glass UI gray color RGB(136,136,136)
    private static let textGray = Color(
        red: 136 / 255,
        green: 136 / 255,
        blue: 136 / 255
    )

    /// Liquid Glass UI teal color RGB(17,170,170)
    private static let badgeTeal = Color(
        red: 17 / 255,
        green: 170 / 255,
        blue: 170 / 255
    )

    var body: some View {
        HStack {
            Label {
                Text(feed.title)
                    .lineLimit(1)
                    .foregroundStyle(Self.textGray)
            } icon: {
                feedIcon
            }
            Spacer()
            if feed.unreadCount > 0 {
                Text("\(feed.unreadCount)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Self.badgeTeal)
            }
        }
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
