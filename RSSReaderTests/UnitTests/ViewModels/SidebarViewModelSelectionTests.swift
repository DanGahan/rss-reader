//
//  SidebarViewModelSelectionTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-03.
//

import Foundation
import Testing
@testable import RSSReader

@Suite("SidebarViewModel Selection Tests")
struct SidebarViewModelSelectionTests {
    @Test("Selection is nil on init")
    @MainActor
    func initialSelectionIsNil() {
        let vm = SidebarViewModel()
        #expect(vm.selection == nil)
    }

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

    // MARK: - All Articles Selection

    @Test("selectAll sets selection to all case")
    @MainActor
    func selectAll() {
        let vm = SidebarViewModel()
        vm.selectAll()
        #expect(vm.selection == .all)
    }

    @Test("isAllSelected returns true when all selected")
    @MainActor
    func isAllSelectedWhenAllSelected() {
        let vm = SidebarViewModel()
        vm.selectAll()
        #expect(vm.isAllSelected == true)
    }

    @Test("isAllSelected returns false when folder selected")
    @MainActor
    func isAllSelectedWhenFolderSelected() {
        let vm = SidebarViewModel()
        vm.selectFolder(UUID())
        #expect(vm.isAllSelected == false)
    }

    @Test("isAllSelected returns false when feed selected")
    @MainActor
    func isAllSelectedWhenFeedSelected() {
        let vm = SidebarViewModel()
        vm.selectFeed(UUID())
        #expect(vm.isAllSelected == false)
    }

    @Test("isAllSelected returns false when nothing selected")
    @MainActor
    func isAllSelectedWhenNothingSelected() {
        let vm = SidebarViewModel()
        #expect(vm.isAllSelected == false)
    }

    @Test("Selecting folder replaces all selection")
    @MainActor
    func folderReplacesAllSelection() {
        let vm = SidebarViewModel()
        let folderId = UUID()
        vm.selectAll()
        vm.selectFolder(folderId)
        #expect(vm.isAllSelected == false)
        #expect(vm.selectedFolderId == folderId)
    }

    @Test("selectedFolderId is nil when all selected")
    @MainActor
    func selectedFolderIdWhenAllSelected() {
        let vm = SidebarViewModel()
        vm.selectAll()
        #expect(vm.selectedFolderId == nil)
    }

    @Test("selectedFeedId is nil when all selected")
    @MainActor
    func selectedFeedIdWhenAllSelected() {
        let vm = SidebarViewModel()
        vm.selectAll()
        #expect(vm.selectedFeedId == nil)
    }

    // MARK: - SidebarSelection Equality

    @Test("SidebarSelection all equality")
    func allEquality() {
        let lhs = SidebarSelection.all
        let rhs = SidebarSelection.all
        #expect(lhs == rhs)
    }

    @Test("SidebarSelection folder equality")
    func folderEquality() {
        let id = UUID()
        let lhs = SidebarSelection.folder(id)
        let rhs = SidebarSelection.folder(id)
        #expect(lhs == rhs)
    }

    @Test("SidebarSelection feed equality")
    func feedEquality() {
        let id = UUID()
        let lhs = SidebarSelection.feed(id)
        let rhs = SidebarSelection.feed(id)
        #expect(lhs == rhs)
    }

    @Test("SidebarSelection folder != feed with same UUID")
    func folderNotEqualToFeed() {
        let id = UUID()
        #expect(
            SidebarSelection.folder(id)
                != SidebarSelection.feed(id)
        )
    }

    @Test("SidebarSelection all != folder")
    func allNotEqualToFolder() {
        let id = UUID()
        #expect(SidebarSelection.all != SidebarSelection.folder(id))
    }

    @Test("SidebarSelection all != feed")
    func allNotEqualToFeed() {
        let id = UUID()
        #expect(SidebarSelection.all != SidebarSelection.feed(id))
    }
}
