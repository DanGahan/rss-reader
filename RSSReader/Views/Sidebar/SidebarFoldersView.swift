//
//  SidebarFoldersView.swift
//  RSSReader
//
//  Created on 2026-02-06.
//

import SwiftUI

struct SidebarFoldersView: View {
    @ObservedObject var viewModel: SidebarViewModel
    let folders: FetchedResults<CDFolder>
    
    @Environment(\.managedObjectContext)
    private var context
    
    var body: some View {
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
                        // highPriorityGesture ensures tap fires
                        // immediately without waiting for drag
                        // gesture recognition to fail.
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                viewModel.selection = .feed(
                                    feed.id
                                )
                            }
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
            } label: {
                FolderRowView(folder: folder)
                    .contentShape(Rectangle())
                    // highPriorityGesture ensures tap fires
                    // immediately without waiting for drag
                    // gesture recognition to fail.
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            viewModel.selection = .folder(
                                folder.id
                            )
                        }
                    )
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
