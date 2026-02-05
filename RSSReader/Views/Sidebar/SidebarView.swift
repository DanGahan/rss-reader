//
//  SidebarView.swift
//  RSSReader
//
//  Created on 2026-01-29.
//

import CoreData
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Type identifier for dragging feeds within the app.
    /// Uses utf8PlainText since NSString-based NSItemProvider
    /// registers with this type by default.
    static let feedDrag = UTType.utf8PlainText
}

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
            allArticlesRow
            foldersSection
            unfiledFeedsSection
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .sheet(isPresented: $viewModel.showNewFolderAlert) {
            FolderNameSheet(
                mode: .create,
                folderName: $viewModel.folderNameInput,
                onSave: {
                    viewModel.createFolder(
                        name: viewModel.folderNameInput,
                        in: context
                    )
                    viewModel.showNewFolderAlert = false
                },
                onCancel: {
                    viewModel.showNewFolderAlert = false
                }
            )
        }
        .sheet(isPresented: $viewModel.showRenameFolderAlert) {
            FolderNameSheet(
                mode: .rename,
                folderName: $viewModel.folderNameInput,
                onSave: {
                    if let id = viewModel.folderToRename {
                        viewModel.renameFolder(
                            id: id,
                            newName: viewModel.folderNameInput,
                            in: context
                        )
                    }
                    viewModel.showRenameFolderAlert = false
                },
                onCancel: {
                    viewModel.showRenameFolderAlert = false
                }
            )
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
    private var allArticlesRow: some View {
        AllArticlesRowView()
            .tag(SidebarSelection.all)
            .onDrop(of: [UTType.feedDrag], isTargeted: nil) { providers in
                handleDrop(providers: providers, toFolderId: nil)
            }
    }

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
                        .contentShape(Rectangle())
                        // DisclosureGroup content doesn't properly
                        // propagate selection to List(selection:).
                        .onTapGesture {
                            viewModel.selection = .feed(
                                feed.id
                            )
                        }
                        .onDrag {
                            NSItemProvider(
                                object: feed.id.uuidString as NSString
                            )
                        }
                        .contextMenu {
                            feedContextMenu(feed: feed)
                        }
                }
            } label: {
                FolderRowView(folder: folder)
                    .contentShape(Rectangle())
                    // DisclosureGroup labels need manual tap handling
                    // to select without toggling expansion.
                    .onTapGesture {
                        viewModel.selection = .folder(
                            folder.id
                        )
                    }
                    .onDrag {
                        NSItemProvider(
                            object: "folder:\(folder.id.uuidString)" as NSString
                        )
                    }
                    .contextMenu {
                        folderContextMenu(folder: folder)
                    }
                    .onDrop(
                        of: [.utf8PlainText],
                        isTargeted: nil
                    ) { providers in
                        handleFolderDrop(
                            providers: providers,
                            targetFolderId: folder.id
                        )
                    }
            }
            .tag(SidebarSelection.folder(folder.id))
        }
    }

    // MARK: - Drop Handling

    private func handleFolderDrop(
        providers: [NSItemProvider],
        targetFolderId: UUID
    ) -> Bool {
        guard let provider = providers.first else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { string, _ in
            guard let payload = string as? String else {
                return
            }

            DispatchQueue.main.async {
                if payload.hasPrefix("folder:") {
                    // Folder reorder
                    let uuidString = String(
                        payload.dropFirst("folder:".count)
                    )
                    guard let folderId = UUID(
                        uuidString: uuidString
                    ) else { return }

                    // Don't drop on self
                    guard folderId != targetFolderId else {
                        return
                    }

                    viewModel.reorderFolder(
                        id: folderId,
                        beforeFolderId: targetFolderId,
                        in: context
                    )
                } else {
                    // Feed drop (existing behavior)
                    guard let feedId = UUID(
                        uuidString: payload
                    ) else { return }

                    viewModel.moveFeed(
                        feedId: feedId,
                        toFolderId: targetFolderId,
                        in: context
                    )
                }
            }
        }
        return true
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
                        .onDrag {
                            NSItemProvider(
                                object: feed.id.uuidString as NSString
                            )
                        }
                        .contextMenu {
                            feedContextMenu(feed: feed)
                        }
                }
            }
            .onDrop(of: [UTType.feedDrag], isTargeted: nil) { providers in
                handleDrop(providers: providers, toFolderId: nil)
            }
        }
    }

    // MARK: - Drop Handling

    private func handleDrop(providers: [NSItemProvider], toFolderId folderId: UUID?) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { string, error in
            if let error = error {
                print("Error loading dragged object: \(error.localizedDescription)")
                return
            }
            guard let uuidString = string as? String,
                  let feedId = UUID(uuidString: uuidString) else { return }
            DispatchQueue.main.async {
                viewModel.moveFeed(feedId: feedId, toFolderId: folderId, in: context)
            }
        }
        return true
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
