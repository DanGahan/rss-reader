//
//  MainView.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import SwiftUI

/// Main 3-pane layout view for authenticated users.
struct MainView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var sidebarViewModel =
        SidebarViewModel()

    var body: some View {
        NavigationSplitView {
            // Left sidebar - Folders & Feeds
            SidebarView(viewModel: sidebarViewModel)
        } content: {
            // Middle pane - Article List
            ArticleListView(
                sidebarSelection:
                    sidebarViewModel.selection
            )
        } detail: {
            // Right pane - Article Content
            ArticleDetailPlaceholderView()
                .frame(minWidth: 500)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    NotificationCenter.default.post(
                        name: .refresh,
                        object: nil
                    )
                } label: {
                    Label(
                        "Refresh",
                        systemImage: "arrow.clockwise"
                    )
                }
                .keyboardShortcut(
                    "r",
                    modifiers: [.command]
                )
            }
        }
    }
}

// MARK: - Placeholder Views

/// Placeholder for the article detail view.
struct ArticleDetailPlaceholderView: View {
    var body: some View {
        VStack {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Select an article to read")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
