//
//  CoreDataIntegrationTests.swift
//  RSSReaderTests
//
//  Integration tests for Core Data CRUD operations.
//

import CoreData
import XCTest
@testable import RSSReader

// swiftlint:disable implicitly_unwrapped_optional
final class CoreDataIntegrationTests: XCTestCase {
    var persistence: PersistenceController!
    var context: NSManagedObjectContext!
// swiftlint:enable implicitly_unwrapped_optional

    override func setUp() {
        super.setUp()
        persistence = PersistenceController.inMemory()
        context = persistence.viewContext
    }

    override func tearDown() {
        context = nil
        persistence = nil
        super.tearDown()
    }

    // MARK: - Folder CRUD

    func testCreateFolder() throws {
        let folder = CDFolder(context: context)
        folder.id = UUID()
        folder.name = "Tech News"
        folder.sortOrder = 0
        folder.dateCreated = Date()

        try context.save()

        let request = CDFolder.fetchRequest()
        let folders = try context.fetch(request)

        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first?.name, "Tech News")
    }

    func testUpdateFolder() throws {
        let folder = CDFolder(context: context)
        folder.id = UUID()
        folder.name = "Original Name"
        folder.sortOrder = 0
        folder.dateCreated = Date()
        try context.save()

        folder.name = "Updated Name"
        try context.save()

        let request = CDFolder.fetchRequest()
        let folders = try context.fetch(request)
        XCTAssertEqual(folders.first?.name, "Updated Name")
    }

    func testDeleteFolder() throws {
        let folder = CDFolder(context: context)
        folder.id = UUID()
        folder.name = "To Delete"
        folder.sortOrder = 0
        folder.dateCreated = Date()
        try context.save()

        context.delete(folder)
        try context.save()

        let request = CDFolder.fetchRequest()
        let folders = try context.fetch(request)
        XCTAssertEqual(folders.count, 0)
    }

    // MARK: - Feed CRUD

    func testCreateFeed() throws {
        let feed = CDFeed(context: context)
        feed.id = UUID()
        feed.title = "Ars Technica"
        feed.feedURL = "https://feeds.arstechnica.com/arstechnica/index"
        feed.dateAdded = Date()

        try context.save()

        let request = CDFeed.fetchRequest()
        let feeds = try context.fetch(request)

        XCTAssertEqual(feeds.count, 1)
        XCTAssertEqual(feeds.first?.title, "Ars Technica")
    }

    func testFeedWithFolder() throws {
        let folder = CDFolder(context: context)
        folder.id = UUID()
        folder.name = "Tech"
        folder.sortOrder = 0
        folder.dateCreated = Date()

        let feed = CDFeed(context: context)
        feed.id = UUID()
        feed.title = "Test Feed"
        feed.feedURL = "https://example.com/feed"
        feed.dateAdded = Date()
        feed.folder = folder

        try context.save()

        let request = CDFeed.fetchRequest()
        let feeds = try context.fetch(request)

        XCTAssertEqual(feeds.first?.folder?.name, "Tech")
    }

    // MARK: - Article CRUD

    func testCreateArticle() throws {
        let feed = CDFeed(context: context)
        feed.id = UUID()
        feed.title = "Test Feed"
        feed.feedURL = "https://example.com/feed"
        feed.dateAdded = Date()

        let article = CDArticle(context: context)
        article.id = "article-1"
        article.title = "Test Article"
        article.link = "https://example.com/article/1"
        article.published = Date()
        article.dateAdded = Date()
        article.isRead = false
        article.feed = feed

        try context.save()

        let request = CDArticle.fetchRequest()
        let articles = try context.fetch(request)

        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles.first?.title, "Test Article")
        XCTAssertEqual(articles.first?.feed?.title, "Test Feed")
    }

    func testMarkArticleAsRead() throws {
        let feed = CDFeed(context: context)
        feed.id = UUID()
        feed.title = "Test Feed"
        feed.feedURL = "https://example.com/feed"
        feed.dateAdded = Date()

        let article = CDArticle(context: context)
        article.id = "article-1"
        article.title = "Test Article"
        article.link = "https://example.com/article/1"
        article.published = Date()
        article.dateAdded = Date()
        article.isRead = false
        article.feed = feed

        try context.save()

        XCTAssertFalse(article.isRead)

        article.isRead = true
        try context.save()

        let request = CDArticle.fetchRequest()
        let articles = try context.fetch(request)
        XCTAssertTrue(articles.first?.isRead ?? false)
    }

    // MARK: - Cascade Delete

    func testDeleteFeedCascadesToArticles() throws {
        let feed = CDFeed(context: context)
        feed.id = UUID()
        feed.title = "Test Feed"
        feed.feedURL = "https://example.com/feed"
        feed.dateAdded = Date()

        let article1 = CDArticle(context: context)
        article1.id = "article-1"
        article1.title = "Article 1"
        article1.link = "https://example.com/1"
        article1.published = Date()
        article1.dateAdded = Date()
        article1.isRead = false
        article1.feed = feed

        let article2 = CDArticle(context: context)
        article2.id = "article-2"
        article2.title = "Article 2"
        article2.link = "https://example.com/2"
        article2.published = Date()
        article2.dateAdded = Date()
        article2.isRead = false
        article2.feed = feed

        try context.save()

        let articleRequest = CDArticle.fetchRequest()
        XCTAssertEqual(try context.fetch(articleRequest).count, 2)

        context.delete(feed)
        try context.save()

        XCTAssertEqual(try context.fetch(articleRequest).count, 0)
    }

    // MARK: - Unread Count Queries

    func testUnreadCountPerFeed() throws {
        let feed = CDFeed(context: context)
        feed.id = UUID()
        feed.title = "Test Feed"
        feed.feedURL = "https://example.com/feed"
        feed.dateAdded = Date()

        for i in 1...5 {
            let article = CDArticle(context: context)
            article.id = "article-\(i)"
            article.title = "Article \(i)"
            article.link = "https://example.com/\(i)"
            article.published = Date()
            article.dateAdded = Date()
            article.isRead = i <= 2  // First 2 are read
            article.feed = feed
        }

        try context.save()

        let request = CDArticle.fetchRequest()
        request.predicate = NSPredicate(
            format: "feed == %@ AND isRead == NO",
            feed
        )
        let unreadCount = try context.count(for: request)

        XCTAssertEqual(unreadCount, 3)
    }
}
