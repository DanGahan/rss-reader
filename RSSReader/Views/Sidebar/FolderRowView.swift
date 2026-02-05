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

    /// Liquid Glass UI teal color RGB(17,170,170)
    private static let badgeTeal = Color(
        red: 17 / 255,
        green: 170 / 255,
        blue: 170 / 255
    )

    var body: some View {
        HStack {
            Label {
                Text(folder.name)
                    .lineLimit(1)
            } icon: {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if folder.unreadCount > 0 {
                Text("\(folder.unreadCount)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Self.badgeTeal)
            }
        }
    }
}
