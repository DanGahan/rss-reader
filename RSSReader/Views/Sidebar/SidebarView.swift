//
//  SidebarView.swift
//  RSSReader
//
//  Created on 2026-01-29.
//

import CoreData
import SwiftUI

/// Sidebar displaying folders (with expandable feeds) and
/// an unfiled feeds section. Drives selection state via
/// `SidebarViewModel`.
struct SidebarView: View {
    @ObservedObject var viewModel: SidebarViewModel

    @Environment(\.managedObjectContext)
    private var viewContext

    @FetchRequest(
        sortDescriptors: [
            SortDescriptor(\CDFolder.sortOrder),
            SortDescriptor(\CDFolder.name)
        ],
        animation: .default
    ) private var folders: FetchedResults<CDFolder>

    @FetchRequest(
        sortDescriptors: [
            SortDescriptor(\CDFeed.title)
        ],
        predicate: NSPredicate(
            format: "folder == nil"
        ),
        animation: .default
    ) private var unfiledFeeds: FetchedResults<CDFeed>

    var body: some View {
        List(selection: $viewModel.selection) {
            foldersSection
            unfiledFeedsSection
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }

    // MARK: - Sections

    @ViewBuilder
    private var foldersSection: some View {
        ForEach(folders, id: \.id) { folder in
            DisclosureGroup(
                isExpanded: viewModel.expandedBinding(
                    for: folder.id
                )
            ) {
                ForEach(
                    folder.sortedFeeds,
                    id: \.id
                ) { feed in
                    FeedRowView(feed: feed)
                        .tag(
                            SidebarSelection.feed(feed.id)
                        )
                        .contextMenu {
                            feedContextMenu(feed: feed)
                        }
                }
            } label: {
                FolderRowView(folder: folder)
            }
            .tag(SidebarSelection.folder(folder.id))
        }
    }

    @ViewBuilder
    private var unfiledFeedsSection: some View {
        if !unfiledFeeds.isEmpty {
            Section("Unfiled") {
                ForEach(unfiledFeeds, id: \.id) { feed in
                    FeedRowView(feed: feed)
                        .tag(
                            SidebarSelection.feed(feed.id)
                        )
                        .contextMenu {
                            feedContextMenu(feed: feed)
                        }
                }
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func feedContextMenu(
        feed: CDFeed
    ) -> some View {
        Button(role: .destructive) {
            deleteFeed(feed)
        } label: {
            Label(
                "Remove Feed",
                systemImage: "trash"
            )
        }
    }

    // MARK: - Actions

    private func deleteFeed(_ feed: CDFeed) {
        viewContext.delete(feed)
        try? viewContext.save()
    }
}
