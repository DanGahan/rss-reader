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
    @ObservedObject var refreshService: RefreshService

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
            SidebarFoldersView(viewModel: viewModel, folders: folders)
                        SidebarUnfiledFeedsView(
                viewModel: viewModel,
                unfiledFeeds: unfiledFeeds,
                folders: folders
            )
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
        AllArticlesRowView(isRefreshing: refreshService.isRefreshing)
            .tag(SidebarSelection.all)
            .onDrop(of: [UTType.feedDrag], isTargeted: nil) { providers in
                handleDrop(providers: providers, toFolderId: nil)
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
}
