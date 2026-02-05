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
    @FetchRequest(
        sortDescriptors: [],
        animation: .default
    ) private var feeds: FetchedResults<CDFeed>

    /// Total unread count across all feeds.
    private var totalUnreadCount: Int {
        feeds.reduce(0) { $0 + $1.unreadCount }
    }

    /// Liquid Glass UI gray color RGB(136,136,136)
    private static let iconGray = Color(
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
                Text("All Articles")
                    .lineLimit(1)
            } icon: {
                Image(systemName: "newspaper")
                    .foregroundStyle(Self.iconGray)
            }
            Spacer()
            if totalUnreadCount > 0 {
                Text("\(totalUnreadCount)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Self.badgeTeal)
            }
        }
    }
}
