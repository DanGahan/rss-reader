//
//  SidebarViewModel.swift
//  RSSReader
//
//  Created on 2026-01-29.
//

import Combine
import CoreData
import SwiftUI

/// Represents a selectable item in the sidebar.
enum SidebarSelection: Hashable {
    case all
    case folder(UUID)
    case feed(UUID)
}

/// ViewModel managing sidebar selection and folder
/// expansion state.
///
/// Folder expansion defaults to expanded; only collapsed
/// folder IDs are tracked, so new folders appear open
/// automatically.
@MainActor
final class SidebarViewModel: ObservableObject {
    @Published var selection: SidebarSelection?

    /// IDs of explicitly collapsed folders. Folders not in
    /// this set are treated as expanded.
    @Published private(set) var collapsedFolders: Set<UUID>
        = []

    // MARK: - Folder Management State

    @Published var showNewFolderAlert = false
    @Published var showRenameFolderAlert = false
    @Published var showDeleteConfirmation = false
    @Published var folderNameInput = ""
    @Published var folderToRename: UUID?
    @Published var folderToDelete: UUID?

    // MARK: - Computed Selection Helpers

    /// Returns true if "All Articles" is currently selected.
    var isAllSelected: Bool {
        if case .all = selection { return true }
        return false
    }

    /// Returns the selected folder's UUID, or nil if a feed
    /// (or nothing) is selected.
    var selectedFolderId: UUID? {
        if case .folder(let id) = selection { return id }
        return nil
    }

    /// Returns the selected feed's UUID, or nil if a folder
    /// (or nothing) is selected.
    var selectedFeedId: UUID? {
        if case .feed(let id) = selection { return id }
        return nil
    }

    // MARK: - Selection Actions

    func selectAll() {
        selection = .all
    }

    func selectFolder(_ id: UUID) {
        selection = .folder(id)
    }

    func selectFeed(_ id: UUID) {
        selection = .feed(id)
    }

    func clearSelection() {
        selection = nil
    }

    // MARK: - Expansion State

    func isFolderExpanded(_ id: UUID) -> Bool {
        !collapsedFolders.contains(id)
    }

    func setFolderExpanded(
        _ id: UUID,
        isExpanded: Bool
    ) {
        if isExpanded {
            collapsedFolders.remove(id)
        } else {
            collapsedFolders.insert(id)
        }
    }

    func toggleFolderExpansion(_ id: UUID) {
        if collapsedFolders.contains(id) {
            collapsedFolders.remove(id)
        } else {
            collapsedFolders.insert(id)
        }
    }

    /// Creates a two-way binding for a folder's expansion
    /// state, suitable for `DisclosureGroup(isExpanded:)`.
    func expandedBinding(
        for folderId: UUID
    ) -> Binding<Bool> {
        Binding(
            get: { [weak self] in
                self?.isFolderExpanded(folderId) ?? true
            },
            set: { [weak self] isExpanded in
                self?.setFolderExpanded(
                    folderId,
                    isExpanded: isExpanded
                )
            }
        )
    }

    // MARK: - Folder CRUD

    /// Creates a new folder with the given name. Trims
    /// whitespace and ignores empty names.
    func createFolder(
        name: String,
        in context: NSManagedObjectContext
    ) {
        let trimmed = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return }

        let nextOrder = nextSortOrder(in: context)
        CDFolder.create(
            in: context,
            name: trimmed,
            sortOrder: nextOrder
        )
        try? context.save()
    }

    /// Renames an existing folder. Trims whitespace and
    /// ignores empty names.
    func renameFolder(
        id: UUID,
        newName: String,
        in context: NSManagedObjectContext
    ) {
        let trimmed = newName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return }

        guard let folder = fetchFolder(
            id: id, in: context
        ) else { return }
        folder.name = trimmed
        try? context.save()
    }

    /// Deletes a folder but keeps its feeds (moves them
    /// to unfiled).
    func deleteFolder(
        id: UUID,
        in context: NSManagedObjectContext
    ) {
        guard let folder = fetchFolder(
            id: id, in: context
        ) else { return }

        // Nullify feed→folder to avoid cascade delete
        for feed in folder.sortedFeeds {
            feed.folder = nil
        }

        context.delete(folder)
        try? context.save()
    }

    /// Moves a feed to the specified folder, or to unfiled
    /// if `folderId` is nil.
    func moveFeed(
        feedId: UUID,
        toFolderId folderId: UUID?,
        in context: NSManagedObjectContext
    ) {
        guard let feed = fetchFeed(
            id: feedId, in: context
        ) else { return }

        if let folderId {
            feed.folder = fetchFolder(
                id: folderId, in: context
            )
        } else {
            feed.folder = nil
        }
        try? context.save()
    }

    /// Deletes a feed and clears selection if the feed
    /// was currently selected. This prevents crashes from
    /// SwiftUI trying to access deleted objects.
    func deleteFeed(
        id feedId: UUID,
        in context: NSManagedObjectContext
    ) {
        // Clear selection first if this feed is selected
        if case .feed(let selectedId) = selection,
           selectedId == feedId {
            selection = nil
        }

        guard let feed = fetchFeed(
            id: feedId, in: context
        ) else { return }

        context.delete(feed)
        try? context.save()
    }

    /// Reorders a folder by moving it before or after
    /// another folder.
    func reorderFolder(
        id: UUID,
        beforeFolderId targetId: UUID?,
        in context: NSManagedObjectContext
    ) {
        // Fetch all folders sorted by current order
        let request = CDFolder.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(
                key: "sortOrder", ascending: true
            ),
            NSSortDescriptor(
                key: "name", ascending: true
            )
        ]
        guard var folders = try? context.fetch(request),
              let sourceIndex = folders.firstIndex(
                  where: { $0.id == id }
              )
        else { return }

        // Remove from current position
        let folder = folders.remove(at: sourceIndex)

        // Find target position
        if let targetId,
           let targetIndex = folders.firstIndex(
               where: { $0.id == targetId }
           ) {
            folders.insert(folder, at: targetIndex)
        } else {
            // Move to end if no target
            folders.append(folder)
        }

        // Update sort orders
        for (index, folder) in folders.enumerated() {
            folder.sortOrder = Int32(index)
        }

        try? context.save()
    }

    // MARK: - Private Helpers

    private func nextSortOrder(
        in context: NSManagedObjectContext
    ) -> Int32 {
        let request = CDFolder.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(
                key: "sortOrder", ascending: false
            )
        ]
        request.fetchLimit = 1
        let folders = (try? context.fetch(request)) ?? []
        let maxOrder = folders.first?.sortOrder ?? -1
        return maxOrder + 1
    }

    private func fetchFolder(
        id: UUID,
        in context: NSManagedObjectContext
    ) -> CDFolder? {
        let request = CDFolder.fetchRequest()
        request.predicate = NSPredicate(
            format: "id == %@", id as CVarArg
        )
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func fetchFeed(
        id: UUID,
        in context: NSManagedObjectContext
    ) -> CDFeed? {
        let request = CDFeed.fetchRequest()
        request.predicate = NSPredicate(
            format: "id == %@", id as CVarArg
        )
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
