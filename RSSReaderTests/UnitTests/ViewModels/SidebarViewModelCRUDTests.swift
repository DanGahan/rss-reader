//
//  SidebarViewModelCRUDTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-03.
//

import CoreData
import Foundation
import Testing
@testable import RSSReader

@Suite("SidebarViewModel CRUD Tests")
struct SidebarViewModelCRUDTests {
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
