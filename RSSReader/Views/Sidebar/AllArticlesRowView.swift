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

    var body: some View {
        Label {
            Text("All Articles")
                .lineLimit(1)
        } icon: {
            Image(systemName: "newspaper")
                .foregroundStyle(.blue)
        }
        .badge(totalUnreadCount)
    }
}
