//
//  FolderRowView.swift
//  RSSReader
//
//  Created on 2026-01-29.
//

import SwiftUI

/// A folder label showing a folder icon, name, and
/// aggregate unread badge.
struct FolderRowView: View {
    @ObservedObject var folder: CDFolder

    var body: some View {
        Label {
            Text(folder.name)
                .lineLimit(1)
        } icon: {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
        }
        .badge(folder.unreadCount)
    }
}
