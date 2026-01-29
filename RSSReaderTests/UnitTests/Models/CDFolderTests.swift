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

        let feed1 = CDFeed.create(
            in: context,
            title: "Feed 1",
            feedURL: "https://example.com/1"
        )
        feed1.folder = folder

        let feed2 = CDFeed.create(
            in: context,
            title: "Feed 2",
            feedURL: "https://example.com/2"
        )
        feed2.folder = folder

        // Feed 1: 2 unread, 1 read
        CDArticle.create(
            in: context,
            id: "a1",
            title: "Article 1",
            link: "https://example.com/a1",
            published: Date(),
            feed: feed1
        )
        CDArticle.create(
            in: context,
            id: "a2",
            title: "Article 2",
            link: "https://example.com/a2",
            published: Date(),
            feed: feed1
        )
        let readArticle = CDArticle.create(
            in: context,
            id: "a3",
            title: "Article 3",
            link: "https://example.com/a3",
            published: Date(),
            feed: feed1
        )
        readArticle.isRead = true

        // Feed 2: 1 unread
        CDArticle.create(
            in: context,
            id: "a4",
            title: "Article 4",
            link: "https://example.com/a4",
            published: Date(),
            feed: feed2
        )

        try context.save()
        #expect(folder.unreadCount == 3)
    }

    @Test("Unread count is zero when no feeds")
    func unreadCountNoFeeds() {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(in: context, name: "Empty")
        #expect(folder.unreadCount == 0)
    }
}
