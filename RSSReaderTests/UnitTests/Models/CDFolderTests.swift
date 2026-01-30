//
//  CDFolderTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-29.
//

import CoreData
import Testing
@testable import RSSReader

@Suite("CDFolder Tests")
struct CDFolderTests {
    // MARK: - Entity Creation

    @Test("Folder can be created with required attributes")
    func createFolder() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(in: context, name: "Tech")

        #expect(folder.name == "Tech")
        #expect(folder.sortOrder == 0)
        #expect(folder.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(folder.dateCreated <= Date())

        try context.save()

        let request = CDFolder.fetchRequest()
        let results = try context.fetch(request)
        #expect(results.count == 1)
        #expect(results.first?.name == "Tech")
    }

    @Test("Folder can be created with custom sort order")
    func createFolderWithSortOrder() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(
            in: context,
            name: "News",
            sortOrder: 5
        )

        #expect(folder.sortOrder == 5)
    }

    // MARK: - Relationships

    @Test("Folder has one-to-many relationship with feeds")
    func folderFeedRelationship() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(in: context, name: "Tech")
        let feed1 = CDFeed.create(
            in: context,
            title: "Ars Technica",
            feedURL: "https://arstechnica.com/feed"
        )
        let feed2 = CDFeed.create(
            in: context,
            title: "The Verge",
            feedURL: "https://theverge.com/feed"
        )

        feed1.folder = folder
        feed2.folder = folder
        try context.save()

        let feeds = folder.feeds as? Set<CDFeed>
        #expect(feeds?.count == 2)
        #expect(feed1.folder === folder)
        #expect(feed2.folder === folder)
    }

    @Test("Deleting folder cascades to feeds")
    func cascadeDeleteFeeds() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(in: context, name: "Tech")
        CDFeed.create(
            in: context,
            title: "Feed 1",
            feedURL: "https://example.com/feed1"
        ).folder = folder
        CDFeed.create(
            in: context,
            title: "Feed 2",
            feedURL: "https://example.com/feed2"
        ).folder = folder
        try context.save()

        context.delete(folder)
        try context.save()

        let feedRequest = CDFeed.fetchRequest()
        let feeds = try context.fetch(feedRequest)
        #expect(feeds.isEmpty)
    }

    // MARK: - Computed Properties

    @Test("Unread count sums unread articles across feeds")
    func unreadCount() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(in: context, name: "Tech")
        let feed1 = makeFeed(context: context, title: "Feed 1", folder: folder)
        let feed2 = makeFeed(context: context, title: "Feed 2", folder: folder)

        // Feed 1: 2 unread, 1 read
        makeArticle(context: context, id: "a1", feed: feed1)
        makeArticle(context: context, id: "a2", feed: feed1)
        makeArticle(context: context, id: "a3", feed: feed1).isRead = true

        // Feed 2: 1 unread
        makeArticle(context: context, id: "a4", feed: feed2)

        try context.save()
        #expect(folder.unreadCount == 3)
    }

    @Test("sortedFeeds returns feeds alphabetically by title")
    func sortedFeedsOrder() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(in: context, name: "Tech")
        makeFeed(context: context, title: "Zebra", folder: folder)
        makeFeed(context: context, title: "Apple", folder: folder)
        makeFeed(context: context, title: "Mango", folder: folder)
        try context.save()

        let sorted = folder.sortedFeeds
        #expect(sorted.count == 3)
        #expect(sorted[0].title == "Apple")
        #expect(sorted[1].title == "Mango")
        #expect(sorted[2].title == "Zebra")
    }

    @Test("sortedFeeds returns empty array when no feeds")
    func sortedFeedsEmpty() {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(in: context, name: "Empty")
        #expect(folder.sortedFeeds.isEmpty)
    }

    @Test("Unread count is zero when no feeds")
    func unreadCountNoFeeds() {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(in: context, name: "Empty")
        #expect(folder.unreadCount == 0)
    }

    // MARK: - Helpers

    @discardableResult
    private func makeFeed(
        context: NSManagedObjectContext,
        title: String,
        folder: CDFolder
    ) -> CDFeed {
        let feed = CDFeed.create(
            in: context,
            title: title,
            feedURL: "https://example.com/\(title)"
        )
        feed.folder = folder
        return feed
    }

    @discardableResult
    private func makeArticle(
        context: NSManagedObjectContext,
        id: String,
        feed: CDFeed
    ) -> CDArticle {
        CDArticle.create(
            in: context,
            id: id,
            title: "Article \(id)",
            link: "https://example.com/\(id)",
            published: Date(),
            feed: feed
        )
    }
}
