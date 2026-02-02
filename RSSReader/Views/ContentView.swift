//
//  ContentView.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Combine
import SwiftUI

/// Root content view presenting the 3-pane RSS reader layout.
struct ContentView: View {
    @StateObject private var sidebarViewModel =
        SidebarViewModel()
    @StateObject private var listViewModel =
        ArticleListViewModel()
    @StateObject private var refreshService =
        RefreshService()

    @State private var showingAddFeed = false

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
                .disabled(refreshService.isRefreshing)
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: .addFeed
            )
        ) { _ in
            showingAddFeed = true
        }
        .sheet(isPresented: $showingAddFeed) {
            AddFeedSheet()
        }
        .onAppear {
            refreshService.startAutoRefresh()
        }
        .onDisappear {
            refreshService.stopAutoRefresh()
        }
    }
}
