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

    var body: some View {
        NavigationSplitView {
            // Left sidebar - Categories & Feeds
            SidebarPlaceholderView()
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
        } content: {
            // Middle pane - Article List
            ArticleListPlaceholderView()
                .frame(minWidth: 300, idealWidth: 400)
        } detail: {
            // Right pane - Article Content
            ArticleDetailPlaceholderView()
                .frame(minWidth: 500)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    NotificationCenter.default.post(name: .refresh, object: nil)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}

// MARK: - Placeholder Views

/// Placeholder for the sidebar view until fully implemented.
struct SidebarPlaceholderView: View {
    var body: some View {
        VStack {
            Image(systemName: "folder")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Categories & Feeds")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Placeholder for the article list view until fully implemented.
struct ArticleListPlaceholderView: View {
    var body: some View {
        VStack {
            Image(systemName: "list.bullet")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Article List")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Placeholder for the article detail view until fully implemented.
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
