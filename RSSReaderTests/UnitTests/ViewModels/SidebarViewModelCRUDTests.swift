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

    // MARK: - Feed Deletion

    @Test("deleteFeed removes feed from context")
    @MainActor
    func deleteFeedRemovesFeed() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Test Feed",
            feedURL: "https://test.com/feed"
        )
        try context.save()

        let vm = SidebarViewModel()
        vm.deleteFeed(id: feed.id, in: context)

        let request = CDFeed.fetchRequest()
        let feeds = try context.fetch(request)
        #expect(feeds.isEmpty)
    }

    @Test("deleteFeed clears selection when deleting selected feed")
    @MainActor
    func deleteFeedClearsSelection() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Test Feed",
            feedURL: "https://test.com/feed"
        )
        try context.save()

        let vm = SidebarViewModel()
        vm.selection = .feed(feed.id)
        #expect(vm.selection == .feed(feed.id))

        vm.deleteFeed(id: feed.id, in: context)

        #expect(vm.selection == nil)
    }

    @Test("deleteFeed preserves selection when deleting different feed")
    @MainActor
    func deleteFeedPreservesOtherSelection() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed1 = CDFeed.create(
            in: context,
            title: "Feed 1",
            feedURL: "https://test1.com/feed"
        )
        let feed2 = CDFeed.create(
            in: context,
            title: "Feed 2",
            feedURL: "https://test2.com/feed"
        )
        try context.save()

        let vm = SidebarViewModel()
        vm.selection = .feed(feed1.id)

        vm.deleteFeed(id: feed2.id, in: context)

        // Selection should still be feed1
        #expect(vm.selection == .feed(feed1.id))

        // feed2 should be deleted
        let request = CDFeed.fetchRequest()
        let feeds = try context.fetch(request)
        #expect(feeds.count == 1)
        #expect(feeds.first?.id == feed1.id)
    }

    @Test("deleteFeed cascades to delete articles")
    @MainActor
    func deleteFeedCascadesToArticles() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Test Feed",
            feedURL: "https://test.com/feed"
        )
        CDArticle.create(
            in: context,
            id: "article-1",
            title: "Article 1",
            link: "https://test.com/1",
            published: Date(),
            feed: feed
        )
        CDArticle.create(
            in: context,
            id: "article-2",
            title: "Article 2",
            link: "https://test.com/2",
            published: Date(),
            feed: feed
        )
        try context.save()

        let vm = SidebarViewModel()
        vm.deleteFeed(id: feed.id, in: context)

        let articleRequest = CDArticle.fetchRequest()
        let articles = try context.fetch(articleRequest)
        #expect(articles.isEmpty)
    }
}
