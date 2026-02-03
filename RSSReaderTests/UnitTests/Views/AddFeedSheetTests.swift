//
//  AddFeedSheetTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-30.
//

import CoreData
import Foundation
import Testing
@testable import RSSReader

@Suite("AddFeedSheet Tests")
struct AddFeedSheetTests {
    // MARK: - Helpers

    private func makeContext() -> NSManagedObjectContext {
        CoreDataTestHelper.makeContext()
    }

    // MARK: - Duplicate feedURL Detection

    @Test("Duplicate feedURL is detected")
    @MainActor
    func duplicateFeedURLDetected() throws {
        let context = makeContext()
        CDFeed.create(
            in: context,
            title: "Existing Feed",
            feedURL: "https://example.com/feed.xml"
        )
        try context.save()

        let request = CDFeed.fetchRequest()
        request.predicate = NSPredicate(
            format: "feedURL == %@",
            "https://example.com/feed.xml"
        )
        let count = try context.count(for: request)
        #expect(count > 0)
    }

    @Test("Non-duplicate feedURL passes check")
    @MainActor
    func nonDuplicateFeedURL() throws {
        let context = makeContext()
        CDFeed.create(
            in: context,
            title: "Existing",
            feedURL: "https://example.com/feed.xml"
        )
        try context.save()

        let request = CDFeed.fetchRequest()
        request.predicate = NSPredicate(
            format: "feedURL == %@",
            "https://other.com/feed.xml"
        )
        let count = try context.count(for: request)
        #expect(count == 0)
    }

    // MARK: - Feed Creation with Folder

    @Test("Feed created with folder relationship")
    @MainActor
    func feedCreatedWithFolder() throws {
        let context = makeContext()
        let folder = CDFolder.create(
            in: context,
            name: "Tech"
        )
        let feed = CDFeed.create(
            in: context,
            title: "Swift Blog",
            feedURL: "https://swift.org/blog/feed.xml"
        )
        feed.folder = folder
        try context.save()

        #expect(feed.folder?.id == folder.id)
        #expect(folder.sortedFeeds.contains { $0.id == feed.id })
    }

    @Test("Feed created without folder (unfiled)")
    @MainActor
    func feedCreatedWithoutFolder() throws {
        let context = makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Unfiled Feed",
            feedURL: "https://example.com/feed.xml"
        )
        try context.save()

        #expect(feed.folder == nil)
    }

    // MARK: - Cascade Delete

    @Test("Deleting feed removes its articles")
    @MainActor
    func cascadeDeleteFeedRemovesArticles() throws {
        let context = makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "Feed to Delete",
            feedURL: "https://example.com/feed.xml"
        )
        CDArticle.create(
            in: context,
            id: "a1",
            title: "Article 1",
            link: "https://example.com/1",
            published: Date(),
            feed: feed
        )
        CDArticle.create(
            in: context,
            id: "a2",
            title: "Article 2",
            link: "https://example.com/2",
            published: Date(),
            feed: feed
        )
        try context.save()

        // Verify articles exist
        let beforeCount = try context.count(
            for: CDArticle.fetchRequest()
        )
        #expect(beforeCount == 2)

        // Delete the feed
        context.delete(feed)
        try context.save()

        // Articles should be cascade deleted
        let afterCount = try context.count(
            for: CDArticle.fetchRequest()
        )
        #expect(afterCount == 0)
    }

    // MARK: - URL Scheme Validation

    @Test("ftp scheme is rejected")
    @MainActor
    func ftpSchemeRejected() {
        let url = URL(string: "ftp://example.com/feed")
        let scheme = url?.scheme?.lowercased()
        let isValid = scheme == "http"
            || scheme == "https"
        #expect(!isValid)
    }

    @Test("https scheme is accepted")
    @MainActor
    func httpsSchemeAccepted() {
        let url = URL(string: "https://example.com/feed")
        let scheme = url?.scheme?.lowercased()
        let isValid = scheme == "http"
            || scheme == "https"
        #expect(isValid)
    }

    @Test("http scheme is accepted")
    @MainActor
    func httpSchemeAccepted() {
        let url = URL(string: "http://example.com/feed")
        let scheme = url?.scheme?.lowercased()
        let isValid = scheme == "http"
            || scheme == "https"
        #expect(isValid)
    }

    @Test("Invalid URL string is rejected")
    @MainActor
    func invalidURLRejected() {
        let url = URL(string: "not a valid url")
        // URL(string:) may succeed for simple strings,
        // but scheme will be nil
        let scheme = url?.scheme?.lowercased()
        let isValid = scheme == "http"
            || scheme == "https"
        #expect(!isValid)
    }

    // MARK: - Feed With Articles Created

    @Test("Feed creation saves initial articles")
    @MainActor
    func feedWithInitialArticles() throws {
        let context = makeContext()
        let feed = CDFeed.create(
            in: context,
            title: "New Feed",
            feedURL: "https://example.com/feed.xml"
        )

        let article = CDArticle.create(
            in: context,
            id: "art-1",
            title: "First Article",
            link: "https://example.com/1",
            published: Date(),
            feed: feed
        )
        try context.save()

        #expect(article.feed?.id == feed.id)
        #expect(feed.unreadCount == 1)

        let articles = try context.fetch(
            CDArticle.fetchRequest()
        )
        #expect(articles.count == 1)
        #expect(articles.first?.title == "First Article")
    }
}
