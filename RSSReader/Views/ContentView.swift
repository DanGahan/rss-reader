//
//  ContentView.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import SwiftUI

/// Root content view presenting the 3-pane RSS reader layout.
struct ContentView: View {
    @StateObject private var sidebarViewModel =
        SidebarViewModel()
    @StateObject private var listViewModel =
        ArticleListViewModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: sidebarViewModel)
        } content: {
            ArticleListView(
                sidebarSelection:
                    sidebarViewModel.selection,
                viewModel: listViewModel
            )
        } detail: {
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

            ToolbarItem(placement: .primaryAction) {
                Button {
                    NotificationCenter.default.post(
                        name: .addFeed,
                        object: nil
                    )
                } label: {
                    Label(
                        "Add Feed",
                        systemImage: "plus"
                    )
                }
            }
        }
    }
}
