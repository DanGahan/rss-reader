//
//  ContentView.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// Root content view presenting the 3-pane RSS reader layout.
struct ContentView: View {
    @StateObject private var sidebarViewModel =
        SidebarViewModel()
    @StateObject private var listViewModel =
        ArticleListViewModel()
    @StateObject private var refreshService =
        RefreshService()

    @State private var showingAddFeed = false

    @Environment(\.managedObjectContext)
    private var context

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

            ToolbarItem(placement: .automatic) {
                if let lastRefresh =
                    refreshService.lastRefreshDate {
                    Text(
                        lastRefresh,
                        format: .relative(
                            presentation: .named
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Never refreshed")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: .newFolder
            )
        ) { _ in
            sidebarViewModel.folderNameInput = ""
            sidebarViewModel.showNewFolderAlert = true
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
        .onReceive(
            NotificationCenter.default.publisher(
                for: .exportOPML
            )
        ) { _ in
            exportOPML()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication
                    .didResignActiveNotification
            )
        ) { _ in
            refreshService.pauseAutoRefresh()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication
                    .didBecomeActiveNotification
            )
        ) { _ in
            refreshService.resumeAutoRefresh()
        }
    }

    // MARK: - OPML Export

    private func exportOPML() {
        let panel = NSSavePanel()
        panel.title = "Export Subscriptions"
        panel.nameFieldStringValue = "subscriptions.opml"
        panel.allowedContentTypes = [
            UTType(
                filenameExtension: "opml"
            ) ?? .xml
        ]

        guard panel.runModal() == .OK,
              let url = panel.url
        else { return }

        do {
            let service = OPMLService()
            let data = try service.exportOPML(
                from: context
            )
            try data.write(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
