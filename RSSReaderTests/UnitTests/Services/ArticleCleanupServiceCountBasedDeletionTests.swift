//
//  ArticleCleanupServiceCountBasedDeletionTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-03.
//

import CoreData
import Foundation
import Testing
@testable import RSSReader

@Suite("ArticleCleanupService Count-Based Deletion Tests")
struct ArticleCleanupServiceCountBasedDeletionTests {
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

    // MARK: - Count-Based Deletion

    @Test("Deletes excess read articles per feed")
    @MainActor
    func deletesByCount() throws {
        let context = makeContext()
        let feed = makeFeed(context)

        // Set low retention count for testing
        let settings = try CDAppSettings.current(
            in: context
        )
        settings.articleRetentionCount = 3
        // Set high retention days so age rule
        // doesn't interfere
        settings.articleRetentionDays = 365

        // Create 5 read articles (0-4 days old)
        for day in 0..<5 {
            _ = makeArticle(
                context,
                feed: feed,
                daysOld: day
            )
        }
        try context.save()

        let result = try sut.performCleanup(
            in: context
        )
        // 5 read - 3 kept = 2 excess
        #expect(result.deletedByCount == 2)

        let remaining = try context.fetch(
            CDArticle.fetchRequest()
        )
        #expect(remaining.count == 3)
    }

    @Test("Count-based keeps newest articles")
    @MainActor
    func countKeepsNewest() throws {
        let context = makeContext()
        let feed = makeFeed(context)

        let settings = try CDAppSettings.current(
            in: context
        )
        settings.articleRetentionCount = 2
        settings.articleRetentionDays = 365

        let a1 = makeArticle(
            context,
            feed: feed,
            daysOld: 1
        )
        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 10
        )
        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 20
        )
        let a4 = makeArticle(
            context,
            feed: feed,
            daysOld: 0
        )
        try context.save()

        _ = try sut.performCleanup(in: context)

        let remaining = try context.fetch(
            CDArticle.fetchRequest()
        )
        let remainingIds = Set(
            remaining.map { $0.id }
        )
        // Should keep the 2 newest (0d and 1d old)
        #expect(remainingIds.contains(a4.id))
        #expect(remainingIds.contains(a1.id))
        #expect(remaining.count == 2)
    }

    @Test("Count-based never deletes unread")
    @MainActor
    func countPreservesUnread() throws {
        let context = makeContext()
        let feed = makeFeed(context)

        let settings = try CDAppSettings.current(
            in: context
        )
        settings.articleRetentionCount = 1
        settings.articleRetentionDays = 365

        // 3 unread articles — all should survive
        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 1,
            isRead: false
        )
        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 2,
            isRead: false
        )
        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 3,
            isRead: false
        )
        try context.save()

        let result = try sut.performCleanup(
            in: context
        )
        #expect(result.deletedByCount == 0)

        let remaining = try context.fetch(
            CDArticle.fetchRequest()
        )
        #expect(remaining.count == 3)
    }
}
