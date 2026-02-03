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
    private var context

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
        .alert(
            "New Folder",
            isPresented: $viewModel.showNewFolderAlert
        ) {
            TextField(
                "Folder name",
                text: $viewModel.folderNameInput
            )
            Button("Create") {
                viewModel.createFolder(
                    name: viewModel.folderNameInput,
                    in: context
                )
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(
            "Rename Folder",
            isPresented: $viewModel.showRenameFolderAlert
        ) {
            TextField(
                "New name",
                text: $viewModel.folderNameInput
            )
            Button("Rename") {
                if let id = viewModel.folderToRename {
                    viewModel.renameFolder(
                        id: id,
                        newName: viewModel.folderNameInput,
                        in: context
                    )
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete Folder?",
            isPresented:
                $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = viewModel.folderToDelete {
                    viewModel.deleteFolder(
                        id: id, in: context
                    )
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Feeds in this folder will be moved "
                    + "to Unfiled."
            )
        }
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
                            SidebarSelection.feed(
                                feed.id
                            )
                        )
                        .onTapGesture {
                            viewModel.selection = .feed(
                                feed.id
                            )
                        }
                        .contextMenu {
                            feedContextMenu(feed: feed)
                        }
                }
            } label: {
                FolderRowView(folder: folder)
                    .onTapGesture {
                        viewModel.selection = .folder(
                            folder.id
                        )
                    }
            }
            .tag(SidebarSelection.folder(folder.id))
            .contextMenu {
                folderContextMenu(folder: folder)
            }
        }
    }

    @ViewBuilder
    private var unfiledFeedsSection: some View {
        if !unfiledFeeds.isEmpty {
            Section("Unfiled") {
                ForEach(
                    unfiledFeeds, id: \.id
                ) { feed in
                    FeedRowView(feed: feed)
                        .tag(
                            SidebarSelection.feed(
                                feed.id
                            )
                        )
                        .onTapGesture {
                            viewModel.selection = .feed(
                                feed.id
                            )
                        }
                        .contextMenu {
                            feedContextMenu(feed: feed)
                        }
                }
            }
        }
    }

    // MARK: - Context Menus

    @ViewBuilder
    private func folderContextMenu(
        folder: CDFolder
    ) -> some View {
        Button("Rename...") {
            viewModel.folderToRename = folder.id
            viewModel.folderNameInput = folder.name
            viewModel.showRenameFolderAlert = true
        }
        Divider()
        Button("Delete", role: .destructive) {
            viewModel.folderToDelete = folder.id
            viewModel.showDeleteConfirmation = true
        }
    }

    @ViewBuilder
    private func feedContextMenu(
        feed: CDFeed
    ) -> some View {
        Menu("Move to Folder") {
            ForEach(folders, id: \.id) { folder in
                Button(folder.name) {
                    viewModel.moveFeed(
                        feedId: feed.id,
                        toFolderId: folder.id,
                        in: context
                    )
                }
                .disabled(feed.folder?.id == folder.id)
            }
            Divider()
            Button("Unfiled") {
                viewModel.moveFeed(
                    feedId: feed.id,
                    toFolderId: nil,
                    in: context
                )
            }
            .disabled(feed.folder == nil)
        }
        Divider()
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
        context.delete(feed)
        try? context.save()
    }
}
