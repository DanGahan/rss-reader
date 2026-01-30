//
//  CDFeedTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-29.
//

import CoreData
import Testing
@testable import RSSReader

@Suite("CDFeed Tests")
struct CDFeedTests {
    // MARK: - Entity Creation

    @Test("Feed can be created with required attributes")
    func createFeed() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Ars Technica",
            feedURL: "https://feeds.arstechnica.com/arstechnica"
        )

        #expect(feed.title == "Ars Technica")
        #expect(
            feed.feedURL ==
            "https://feeds.arstechnica.com/arstechnica"
        )
        #expect(feed.refreshInterval == 600)
        #expect(feed.lastFetched == nil)
        #expect(feed.lastError == nil)
        #expect(feed.siteURL == nil)
        #expect(feed.iconURL == nil)

        try context.save()

        let request = CDFeed.fetchRequest()
        let results = try context.fetch(request)
        #expect(results.count == 1)
    }

    @Test("Feed can store all optional attributes")
    func feedOptionalAttributes() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Example",
            feedURL: "https://example.com/feed",
            refreshInterval: 300
        )
        feed.siteURL = "https://example.com"
        feed.iconURL = "https://example.com/icon.png"
        feed.lastFetched = Date()
        feed.lastError = "Timeout"

        try context.save()

        let request = CDFeed.fetchRequest()
        let fetched = try context.fetch(request).first
        #expect(fetched?.siteURL == "https://example.com")
        #expect(
            fetched?.iconURL == "https://example.com/icon.png"
        )
        #expect(fetched?.lastFetched != nil)
        #expect(fetched?.lastError == "Timeout")
        #expect(fetched?.refreshInterval == 300)
    }

    // MARK: - Relationships

    @Test("Feed has one-to-many relationship with articles")
    func feedArticleRelationship() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Test Feed",
            feedURL: "https://example.com/feed"
        )

        CDArticle.create(
            in: context,
            id: "art-1",
            title: "Article 1",
            link: "https://example.com/1",
            published: Date(),
            feed: feed
        )
        CDArticle.create(
            in: context,
            id: "art-2",
            title: "Article 2",
            link: "https://example.com/2",
            published: Date(),
            feed: feed
        )
        try context.save()

        let articles = feed.articles as? Set<CDArticle>
        #expect(articles?.count == 2)
    }

    @Test("Feed belongs to optional folder")
    func feedFolderRelationship() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(in: context, name: "News")
        let feed = CDFeed.create(
            in: context,
            title: "BBC",
            feedURL: "https://bbc.co.uk/feed"
        )
        feed.folder = folder
        try context.save()

        #expect(feed.folder === folder)

        // Feed can also exist without a folder
        let orphan = CDFeed.create(
            in: context,
            title: "Orphan",
            feedURL: "https://orphan.com/feed"
        )
        #expect(orphan.folder == nil)
    }

    @Test("Deleting feed cascades to articles")
    func cascadeDeleteArticles() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Feed",
            feedURL: "https://example.com/feed"
        )
        CDArticle.create(
            in: context,
            id: "a1",
            title: "Art 1",
            link: "https://example.com/1",
            published: Date(),
            feed: feed
        )
        CDArticle.create(
            in: context,
            id: "a2",
            title: "Art 2",
            link: "https://example.com/2",
            published: Date(),
            feed: feed
        )
        try context.save()

        context.delete(feed)
        try context.save()

        let request = CDArticle.fetchRequest()
        let articles = try context.fetch(request)
        #expect(articles.isEmpty)
    }

    // MARK: - Computed Properties

    @Test("Unread count returns number of unread articles")
    func unreadCount() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Feed",
            feedURL: "https://example.com/feed"
        )

        CDArticle.create(
            in: context,
            id: "a1",
            title: "Unread 1",
            link: "https://example.com/1",
            published: Date(),
            feed: feed
        )
        CDArticle.create(
            in: context,
            id: "a2",
            title: "Unread 2",
            link: "https://example.com/2",
            published: Date(),
            feed: feed
        )
        let readArticle = CDArticle.create(
            in: context,
            id: "a3",
            title: "Read",
            link: "https://example.com/3",
            published: Date(),
            feed: feed
        )
        readArticle.isRead = true

        try context.save()
        #expect(feed.unreadCount == 2)
    }

    @Test("Unread count is zero with no articles")
    func unreadCountEmpty() {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Empty",
            feedURL: "https://example.com/feed"
        )
        #expect(feed.unreadCount == 0)
    }

    @Test("hasError is true when lastError is set")
    func hasErrorWhenErrorExists() {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Broken",
            feedURL: "https://example.com/feed"
        )
        feed.lastError = "Connection timeout"
        #expect(feed.hasError)
    }

    @Test("hasError is false when lastError is nil")
    func hasErrorWhenNoError() {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Healthy",
            feedURL: "https://example.com/feed"
        )
        #expect(!feed.hasError)
    }

    @Test("Unread count is zero when all articles are read")
    func unreadCountAllRead() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Feed",
            feedURL: "https://example.com/feed"
        )
        let art = CDArticle.create(
            in: context,
            id: "a1",
            title: "Read",
            link: "https://example.com/1",
            published: Date(),
            feed: feed
        )
        art.isRead = true
        try context.save()

        #expect(feed.unreadCount == 0)
    }
}
