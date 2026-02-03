//
//  SidebarViewModelTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-29.
//

import CoreData
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

    // MARK: - Folder CRUD

    @Test("createFolder creates folder in context")
    @MainActor
    func createFolder() throws {
        let context = CoreDataTestHelper.makeContext()
        let vm = SidebarViewModel()
        vm.createFolder(name: "Tech", in: context)

        let request = CDFolder.fetchRequest()
        let folders = try context.fetch(request)
        #expect(folders.count == 1)
        #expect(folders.first?.name == "Tech")
    }

    @Test("createFolder trims whitespace")
    @MainActor
    func createFolderTrimWhitespace() throws {
        let context = CoreDataTestHelper.makeContext()
        let vm = SidebarViewModel()
        vm.createFolder(
            name: "  News  ", in: context
        )

        let request = CDFolder.fetchRequest()
        let folders = try context.fetch(request)
        #expect(folders.first?.name == "News")
    }

    @Test("createFolder ignores empty name")
    @MainActor
    func createFolderEmptyName() throws {
        let context = CoreDataTestHelper.makeContext()
        let vm = SidebarViewModel()
        vm.createFolder(name: "   ", in: context)

        let request = CDFolder.fetchRequest()
        let folders = try context.fetch(request)
        #expect(folders.isEmpty)
    }

    @Test("createFolder increments sortOrder")
    @MainActor
    func createFolderSortOrder() throws {
        let context = CoreDataTestHelper.makeContext()
        let vm = SidebarViewModel()
        vm.createFolder(name: "First", in: context)
        vm.createFolder(name: "Second", in: context)

        let request = CDFolder.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(
                key: "sortOrder", ascending: true
            )
        ]
        let folders = try context.fetch(request)
        #expect(folders.count == 2)
        #expect(folders[0].sortOrder == 0)
        #expect(folders[1].sortOrder == 1)
    }

    @Test("renameFolder updates folder name")
    @MainActor
    func renameFolder() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(
            in: context, name: "Old", sortOrder: 0
        )
        try context.save()

        let vm = SidebarViewModel()
        vm.renameFolder(
            id: folder.id,
            newName: "New",
            in: context
        )
        #expect(folder.name == "New")
    }

    @Test("renameFolder ignores empty name")
    @MainActor
    func renameFolderEmptyName() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(
            in: context, name: "Keep", sortOrder: 0
        )
        try context.save()

        let vm = SidebarViewModel()
        vm.renameFolder(
            id: folder.id,
            newName: "  ",
            in: context
        )
        #expect(folder.name == "Keep")
    }

    @Test("deleteFolder keeps feeds as unfiled")
    @MainActor
    func deleteFolderKeepsFeeds() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(
            in: context, name: "Tech", sortOrder: 0
        )
        let feed = CDFeed.create(
            in: context,
            title: "Ars Technica",
            feedURL: "https://ars.com/feed"
        )
        feed.folder = folder
        try context.save()

        let vm = SidebarViewModel()
        vm.deleteFolder(
            id: folder.id, in: context
        )

        let folderReq = CDFolder.fetchRequest()
        let folders = try context.fetch(folderReq)
        #expect(folders.isEmpty)

        let feedReq = CDFeed.fetchRequest()
        let feeds = try context.fetch(feedReq)
        #expect(feeds.count == 1)
        #expect(feeds.first?.folder == nil)
    }

    @Test("moveFeed changes feed folder")
    @MainActor
    func moveFeedToFolder() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(
            in: context, name: "Tech", sortOrder: 0
        )
        let feed = CDFeed.create(
            in: context,
            title: "Test Feed",
            feedURL: "https://test.com/feed"
        )
        try context.save()
        #expect(feed.folder == nil)

        let vm = SidebarViewModel()
        vm.moveFeed(
            feedId: feed.id,
            toFolderId: folder.id,
            in: context
        )
        #expect(feed.folder?.id == folder.id)
    }

    @Test("moveFeed to nil sets feed unfiled")
    @MainActor
    func moveFeedToUnfiled() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(
            in: context, name: "Tech", sortOrder: 0
        )
        let feed = CDFeed.create(
            in: context,
            title: "Test Feed",
            feedURL: "https://test.com/feed"
        )
        feed.folder = folder
        try context.save()

        let vm = SidebarViewModel()
        vm.moveFeed(
            feedId: feed.id,
            toFolderId: nil,
            in: context
        )
        #expect(feed.folder == nil)
    }
}
