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
    @StateObject private var listViewModel =
        ArticleListViewModel()

    var body: some View {
        NavigationSplitView {
            // Left sidebar - Folders & Feeds
            SidebarView(viewModel: sidebarViewModel)
        } content: {
            // Middle pane - Article List
            ArticleListView(
                sidebarSelection:
                    sidebarViewModel.selection,
                viewModel: listViewModel
            )
        } detail: {
            // Right pane - Article Content
            ArticleDetailView(
                articleId:
                    listViewModel.selectedArticleId
            )
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
