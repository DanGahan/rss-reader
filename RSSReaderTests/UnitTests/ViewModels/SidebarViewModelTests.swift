//
//  SidebarViewModelTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-29.
//

import Foundation
import Testing
@testable import RSSReader

@Suite("SidebarViewModel Tests")
struct SidebarViewModelTests {

    // MARK: - Initial State

    @Test("Selection is nil on init")
    @MainActor
    func initialSelectionIsNil() {
        let vm = SidebarViewModel()
        #expect(vm.selection == nil)
    }

    @Test("No folders are collapsed on init")
    @MainActor
    func initialExpansionState() {
        let vm = SidebarViewModel()
        #expect(vm.collapsedFolders.isEmpty)
    }

    // MARK: - Selection

    @Test("Select folder sets selection to folder case")
    @MainActor
    func selectFolder() {
        let vm = SidebarViewModel()
        let id = UUID()
        vm.selectFolder(id)
        #expect(vm.selection == .folder(id))
    }

    @Test("Select feed sets selection to feed case")
    @MainActor
    func selectFeed() {
        let vm = SidebarViewModel()
        let id = UUID()
        vm.selectFeed(id)
        #expect(vm.selection == .feed(id))
    }

    @Test("selectedFolderId returns UUID when folder selected")
    @MainActor
    func selectedFolderIdWhenFolderSelected() {
        let vm = SidebarViewModel()
        let id = UUID()
        vm.selectFolder(id)
        #expect(vm.selectedFolderId == id)
    }

    @Test("selectedFolderId is nil when feed selected")
    @MainActor
    func selectedFolderIdWhenFeedSelected() {
        let vm = SidebarViewModel()
        vm.selectFeed(UUID())
        #expect(vm.selectedFolderId == nil)
    }

    @Test("selectedFeedId returns UUID when feed selected")
    @MainActor
    func selectedFeedIdWhenFeedSelected() {
        let vm = SidebarViewModel()
        let id = UUID()
        vm.selectFeed(id)
        #expect(vm.selectedFeedId == id)
    }

    @Test("selectedFeedId is nil when folder selected")
    @MainActor
    func selectedFeedIdWhenFolderSelected() {
        let vm = SidebarViewModel()
        vm.selectFolder(UUID())
        #expect(vm.selectedFeedId == nil)
    }

    @Test("clearSelection resets selection to nil")
    @MainActor
    func clearSelection() {
        let vm = SidebarViewModel()
        vm.selectFolder(UUID())
        vm.clearSelection()
        #expect(vm.selection == nil)
    }

    @Test("Selecting feed replaces previous folder selection")
    @MainActor
    func selectionReplacesPrevious() {
        let vm = SidebarViewModel()
        let folderId = UUID()
        let feedId = UUID()
        vm.selectFolder(folderId)
        vm.selectFeed(feedId)
        #expect(vm.selectedFolderId == nil)
        #expect(vm.selectedFeedId == feedId)
    }

    // MARK: - Folder Expansion

    @Test("Folders default to expanded")
    @MainActor
    func foldersDefaultToExpanded() {
        let vm = SidebarViewModel()
        let id = UUID()
        #expect(vm.isFolderExpanded(id))
    }

    @Test("setFolderExpanded false collapses folder")
    @MainActor
    func setFolderCollapsed() {
        let vm = SidebarViewModel()
        let id = UUID()
        vm.setFolderExpanded(id, isExpanded: false)
        #expect(!vm.isFolderExpanded(id))
    }

    @Test("setFolderExpanded true re-expands folder")
    @MainActor
    func setFolderReExpanded() {
        let vm = SidebarViewModel()
        let id = UUID()
        vm.setFolderExpanded(id, isExpanded: false)
        vm.setFolderExpanded(id, isExpanded: true)
        #expect(vm.isFolderExpanded(id))
    }

    @Test("toggleFolderExpansion collapses expanded folder")
    @MainActor
    func toggleCollapse() {
        let vm = SidebarViewModel()
        let id = UUID()
        vm.toggleFolderExpansion(id)
        #expect(!vm.isFolderExpanded(id))
    }

    @Test("toggleFolderExpansion expands collapsed folder")
    @MainActor
    func toggleExpand() {
        let vm = SidebarViewModel()
        let id = UUID()
        vm.toggleFolderExpansion(id)
        vm.toggleFolderExpansion(id)
        #expect(vm.isFolderExpanded(id))
    }

    @Test("Collapsing one folder does not affect others")
    @MainActor
    func independentFolderExpansion() {
        let vm = SidebarViewModel()
        let id1 = UUID()
        let id2 = UUID()
        vm.setFolderExpanded(id1, isExpanded: false)
        #expect(!vm.isFolderExpanded(id1))
        #expect(vm.isFolderExpanded(id2))
    }

    // MARK: - Expanded Binding

    @Test("expandedBinding getter returns correct state")
    @MainActor
    func expandedBindingGetter() {
        let vm = SidebarViewModel()
        let id = UUID()
        let binding = vm.expandedBinding(for: id)
        #expect(binding.wrappedValue == true)

        vm.setFolderExpanded(id, isExpanded: false)
        #expect(binding.wrappedValue == false)
    }

    @Test("expandedBinding setter updates state")
    @MainActor
    func expandedBindingSetter() {
        let vm = SidebarViewModel()
        let id = UUID()
        let binding = vm.expandedBinding(for: id)
        binding.wrappedValue = false
        #expect(!vm.isFolderExpanded(id))

        binding.wrappedValue = true
        #expect(vm.isFolderExpanded(id))
    }

    // MARK: - SidebarSelection Equality

    @Test("SidebarSelection folder equality")
    func folderEquality() {
        let id = UUID()
        #expect(
            SidebarSelection.folder(id)
                == SidebarSelection.folder(id)
        )
    }

    @Test("SidebarSelection feed equality")
    func feedEquality() {
        let id = UUID()
        #expect(
            SidebarSelection.feed(id)
                == SidebarSelection.feed(id)
        )
    }

    @Test("SidebarSelection folder != feed with same UUID")
    func folderNotEqualToFeed() {
        let id = UUID()
        #expect(
            SidebarSelection.folder(id)
                != SidebarSelection.feed(id)
        )
    }
}
