//
//  FolderRowView.swift
//  RSSReader
//
//  Created on 2026-01-29.
//

import CoreData
import SwiftUI
import UniformTypeIdentifiers

/// A folder label showing a folder icon, name, and
/// aggregate unread badge.
struct FolderRowView: View {
    @ObservedObject var folder: CDFolder

    /// Fetch unread articles for this folder for real-time count.
    @FetchRequest private var unreadArticles: FetchedResults<CDArticle>

    init(folder: CDFolder) {
        self.folder = folder
        _unreadArticles = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(
                format: "feed.folder.id == %@ AND isRead == NO",
                folder.id as CVarArg
            ),
            animation: .default
        )
    }

    var body: some View {
        HStack {
            Label {
                Text(folder.name)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "folder")
                    .font(.system(size: 16))
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
