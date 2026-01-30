//
//  SidebarViewModel.swift
//  RSSReader
//
//  Created on 2026-01-29.
//

import Combine
import SwiftUI

/// Represents a selectable item in the sidebar.
enum SidebarSelection: Hashable {
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
    @Published private(set) var collapsedFolders: Set<UUID> = []

    // MARK: - Computed Selection Helpers

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
}
