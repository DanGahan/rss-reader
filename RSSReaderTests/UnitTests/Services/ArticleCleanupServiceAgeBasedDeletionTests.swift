//
//  ArticleCleanupServiceAgeBasedDeletionTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-03.
//

import CoreData
import Foundation
import Testing
@testable import RSSReader

@Suite("ArticleCleanupService Age-Based Deletion Tests")
struct ArticleCleanupServiceAgeBasedDeletionTests {
    private let sut = ArticleCleanupService()

    private func makeContext() -> NSManagedObjectContext {
        CoreDataTestHelper.makeContext()
    }

    private func makeFeed(
        _ context: NSManagedObjectContext,
        title: String = "Test Feed"
    ) -> CDFeed {
        CDFeed.create(
            in: context,
            title: title,
            feedURL: "https://\(title).com/feed"
        )
    }

    private func makeArticle(
        _ context: NSManagedObjectContext,
        feed: CDFeed,
        daysOld: Int,
        isRead: Bool = true
    ) -> CDArticle {
        let article = CDArticle.create(
            in: context,
            id: UUID().uuidString,
            title: "Article \(daysOld)d old",
            link: "https://example.com/\(daysOld)",
            published: Date(),
            feed: feed
        )
        article.dateAdded = Date()
            .addingTimeInterval(
                -Double(daysOld) * 86400
            )
        article.isRead = isRead
        return article
    }

    // MARK: - Age-Based Deletion

    @Test("Deletes read articles older than retention")
    @MainActor
    func deletesByAge() throws {
        let context = makeContext()
        let feed = makeFeed(context)

        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 5
        )
        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 40
        )
        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 60
        )
        try context.save()

        let result = try sut.performCleanup(
            in: context
        )
        #expect(result.deletedByAge == 2)

        let remaining = try context.fetch(
            CDArticle.fetchRequest()
        )
        #expect(remaining.count == 1)
    }

    @Test("Never deletes unread articles by age")
    @MainActor
    func preservesUnreadByAge() throws {
        let context = makeContext()
        let feed = makeFeed(context)

        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 60,
            isRead: false
        )
        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 90,
            isRead: false
        )
        try context.save()

        let result = try sut.performCleanup(
            in: context
        )
        #expect(result.deletedByAge == 0)

        let remaining = try context.fetch(
            CDArticle.fetchRequest()
        )
        #expect(remaining.count == 2)
    }

    @Test("Mixed read/unread: only deletes old read")
    @MainActor
    func mixedReadUnreadByAge() throws {
        let context = makeContext()
        let feed = makeFeed(context)

        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 40,
            isRead: true
        )
        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 40,
            isRead: false
        )
        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 5,
            isRead: true
        )
        try context.save()

        let result = try sut.performCleanup(
            in: context
        )
        #expect(result.deletedByAge == 1)

        let remaining = try context.fetch(
            CDArticle.fetchRequest()
        )
        #expect(remaining.count == 2)
    }
}
