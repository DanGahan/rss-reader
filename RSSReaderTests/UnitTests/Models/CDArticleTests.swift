//
//  CDArticleTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-29.
//

import CoreData
import Testing
@testable import RSSReader

@Suite("CDArticle Tests")
struct CDArticleTests {
    // MARK: - Entity Creation

    @Test("Article can be created with required attributes")
    func createArticle() throws {
        let context = CoreDataTestHelper.makeContext()
        let published = Date()
        let article = CDArticle.create(
            in: context,
            id: "feed/123/article/456",
            title: "Swift 6 Released",
            link: "https://swift.org/blog/swift-6",
            published: published
        )

        #expect(article.id == "feed/123/article/456")
        #expect(article.title == "Swift 6 Released")
        #expect(article.link == "https://swift.org/blog/swift-6")
        #expect(article.published == published)
        #expect(article.isRead == false)
        #expect(article.dateAdded <= Date())
        #expect(article.author == nil)
        #expect(article.summary == nil)
        #expect(article.content == nil)
        #expect(article.thumbnailURL == nil)

        try context.save()

        let request = CDArticle.fetchRequest()
        let results = try context.fetch(request)
        #expect(results.count == 1)
    }

    @Test("Article can store all optional attributes")
    func articleOptionalAttributes() throws {
        let context = CoreDataTestHelper.makeContext()
        let article = CDArticle.create(
            in: context,
            id: "art-1",
            title: "Test",
            link: "https://example.com",
            published: Date()
        )
        article.author = "Jane Doe"
        article.summary = "A short summary"
        article.content = "<p>Full HTML content</p>"
        article.thumbnailURL = "https://example.com/thumb.jpg"

        try context.save()

        let request = CDArticle.fetchRequest()
        let fetched = try context.fetch(request).first
        #expect(fetched?.author == "Jane Doe")
        #expect(fetched?.summary == "A short summary")
        #expect(fetched?.content == "<p>Full HTML content</p>")
        #expect(
            fetched?.thumbnailURL ==
            "https://example.com/thumb.jpg"
        )
    }

    @Test("Article uses String id, not UUID")
    func articleStringId() throws {
        let context = CoreDataTestHelper.makeContext()
        let article = CDArticle.create(
            in: context,
            id: "feed/custom-string-id",
            title: "Test",
            link: "https://example.com",
            published: Date()
        )
        try context.save()

        #expect(article.id == "feed/custom-string-id")
    }

    // MARK: - Read State

    @Test("Article defaults to unread")
    func defaultUnread() {
        let context = CoreDataTestHelper.makeContext()
        let article = CDArticle.create(
            in: context,
            id: "a1",
            title: "Test",
            link: "https://example.com",
            published: Date()
        )
        #expect(article.isRead == false)
    }

    @Test("Article can be marked as read")
    func markAsRead() throws {
        let context = CoreDataTestHelper.makeContext()
        let article = CDArticle.create(
            in: context,
            id: "a1",
            title: "Test",
            link: "https://example.com",
            published: Date()
        )
        article.isRead = true
        try context.save()

        let request = CDArticle.fetchRequest()
        let fetched = try context.fetch(request).first
        #expect(fetched?.isRead == true)
    }

    // MARK: - Relationships

    @Test("Article belongs to a feed")
    func articleFeedRelationship() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Tech News",
            feedURL: "https://example.com/feed"
        )
        let article = CDArticle.create(
            in: context,
            id: "a1",
            title: "Test",
            link: "https://example.com/1",
            published: Date(),
            feed: feed
        )
        try context.save()

        #expect(article.feed === feed)
        let feedArticles = feed.articles as? Set<CDArticle>
        #expect(feedArticles?.contains(article) == true)
    }

    @Test("Removing feed nullifies article relationship")
    func nullifyOnFolderDelete() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(in: context, name: "Tech")
        let feed = CDFeed.create(
            in: context,
            title: "Feed",
            feedURL: "https://example.com/feed"
        )
        feed.folder = folder
        try context.save()

        feed.folder = nil
        try context.save()

        #expect(feed.folder == nil)
    }

    // MARK: - De-duplication (CloudKit Compatibility)

    @Test("findExisting returns nil when no article exists")
    func findExistingNoMatch() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Feed",
            feedURL: "https://example.com/feed"
        )
        try context.save()

        let result = CDArticle.findExisting(
            articleId: "non-existent-id",
            feed: feed,
            in: context
        )

        #expect(result == nil)
    }

    @Test("findExisting returns existing article")
    func findExistingMatch() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Feed",
            feedURL: "https://example.com/feed"
        )
        let article = CDArticle.create(
            in: context,
            id: "article-123",
            title: "Test Article",
            link: "https://example.com/article",
            published: Date(),
            feed: feed
        )
        try context.save()

        let result = CDArticle.findExisting(
            articleId: "article-123",
            feed: feed,
            in: context
        )

        #expect(result === article)
    }

    @Test("findExisting does not match article in different feed")
    func findExistingDifferentFeed() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed1 = CDFeed.create(
            in: context,
            title: "Feed 1",
            feedURL: "https://example.com/feed1"
        )
        let feed2 = CDFeed.create(
            in: context,
            title: "Feed 2",
            feedURL: "https://example.com/feed2"
        )
        _ = CDArticle.create(
            in: context,
            id: "shared-id",
            title: "Article in Feed 1",
            link: "https://example.com/article",
            published: Date(),
            feed: feed1
        )
        try context.save()

        // Same ID but different feed should not match
        let result = CDArticle.findExisting(
            articleId: "shared-id",
            feed: feed2,
            in: context
        )

        #expect(result == nil)
    }

    @Test("createIfNotExists creates new article when none exists")
    func createIfNotExistsNew() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Feed",
            feedURL: "https://example.com/feed"
        )
        try context.save()

        let (article, isNew) = CDArticle.createIfNotExists(
            in: context,
            id: "new-article",
            title: "New Article",
            link: "https://example.com/new",
            published: Date(),
            feed: feed
        )
        try context.save()

        #expect(isNew == true)
        #expect(article.id == "new-article")
        #expect(article.title == "New Article")

        let request = CDArticle.fetchRequest()
        let count = try context.count(for: request)
        #expect(count == 1)
    }

    @Test("createIfNotExists returns existing article without creating duplicate")
    func createIfNotExistsDuplicate() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Feed",
            feedURL: "https://example.com/feed"
        )
        let existing = CDArticle.create(
            in: context,
            id: "existing-article",
            title: "Original Title",
            link: "https://example.com/original",
            published: Date(),
            feed: feed
        )
        try context.save()

        // Try to create article with same ID
        let (article, isNew) = CDArticle.createIfNotExists(
            in: context,
            id: "existing-article",
            title: "Different Title",
            link: "https://example.com/different",
            published: Date(),
            feed: feed
        )

        #expect(isNew == false)
        #expect(article === existing)
        #expect(article.title == "Original Title") // Not overwritten

        let request = CDArticle.fetchRequest()
        let count = try context.count(for: request)
        #expect(count == 1) // Still only one article
    }

    @Test("createIfNotExists allows same ID in different feeds")
    func createIfNotExistsSameIdDifferentFeeds() throws {
        let context = CoreDataTestHelper.makeContext()
        let feed1 = CDFeed.create(
            in: context,
            title: "Feed 1",
            feedURL: "https://example.com/feed1"
        )
        let feed2 = CDFeed.create(
            in: context,
            title: "Feed 2",
            feedURL: "https://example.com/feed2"
        )

        let (article1, isNew1) = CDArticle.createIfNotExists(
            in: context,
            id: "shared-id",
            title: "Article in Feed 1",
            link: "https://example.com/1",
            published: Date(),
            feed: feed1
        )

        let (article2, isNew2) = CDArticle.createIfNotExists(
            in: context,
            id: "shared-id",
            title: "Article in Feed 2",
            link: "https://example.com/2",
            published: Date(),
            feed: feed2
        )
        try context.save()

        #expect(isNew1 == true)
        #expect(isNew2 == true)
        #expect(article1 !== article2)
        #expect(article1.feed === feed1)
        #expect(article2.feed === feed2)

        let request = CDArticle.fetchRequest()
        let count = try context.count(for: request)
        #expect(count == 2)
    }
}
