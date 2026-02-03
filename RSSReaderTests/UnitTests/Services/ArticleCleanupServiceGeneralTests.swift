//
//  ArticleCleanupServiceGeneralTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-03.
//

import CoreData
import Foundation
import Testing
@testable import RSSReader

@Suite("ArticleCleanupService General Tests")
struct ArticleCleanupServiceGeneralTests {
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

    // MARK: - Per-Feed Independence

    @Test("Count limit is per-feed, not global")
    @MainActor
    func countPerFeed() throws {
        let context = makeContext()
        let feed1 = makeFeed(context, title: "Feed1")
        let feed2 = makeFeed(context, title: "Feed2")

        let settings = try CDAppSettings.current(
            in: context
        )
        settings.articleRetentionCount = 2
        settings.articleRetentionDays = 365

        // Feed1: 3 read articles → 1 deleted
        for day in 0..<3 {
            _ = makeArticle(
                context,
                feed: feed1,
                daysOld: day
            )
        }

        // Feed2: 4 read articles → 2 deleted
        for day in 0..<4 {
            _ = makeArticle(
                context,
                feed: feed2,
                daysOld: day
            )
        }
        try context.save()

        let result = try sut.performCleanup(
            in: context
        )
        #expect(result.deletedByCount == 3)

        let remaining = try context.fetch(
            CDArticle.fetchRequest()
        )
        #expect(remaining.count == 4) // 2 + 2
    }

    // MARK: - Empty / No-op Cases

    @Test("Cleanup on empty database is no-op")
    @MainActor
    func emptyDatabase() throws {
        let context = makeContext()
        let result = try sut.performCleanup(
            in: context
        )
        #expect(result.totalDeleted == 0)
        #expect(result.deletedByAge == 0)
        #expect(result.deletedByCount == 0)
    }

    @Test("Cleanup with all recent articles deletes none")
    @MainActor
    func allRecentArticles() throws {
        let context = makeContext()
        let feed = makeFeed(context)

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
        #expect(result.deletedByAge == 0)
    }

    // MARK: - Combined Rules

    @Test("Age and count rules combine correctly")
    @MainActor
    func combinedRules() throws {
        let context = makeContext()
        let feed = makeFeed(context)

        let settings = try CDAppSettings.current(
            in: context
        )
        settings.articleRetentionCount = 3
        settings.articleRetentionDays = 30

        // 2 old+read (deleted by age)
        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 40
        )
        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 50
        )

        // 5 recent+read (2 deleted by count,
        // since max is 3)
        for day in 0..<5 {
            _ = makeArticle(
                context,
                feed: feed,
                daysOld: day
            )
        }

        // 1 unread old (preserved)
        _ = makeArticle(
            context,
            feed: feed,
            daysOld: 60,
            isRead: false
        )
        try context.save()

        let result = try sut.performCleanup(
            in: context
        )

        // Age deletes the 2 old read articles
        #expect(result.deletedByAge == 2)
        // Count: 5 recent read, keep 3 → delete 2
        #expect(result.deletedByCount == 2)
        #expect(result.totalDeleted == 4)

        let remaining = try context.fetch(
            CDArticle.fetchRequest()
        )
        // 3 recent read + 1 unread = 4
        #expect(remaining.count == 4)
    }

    @Test("totalDeleted sums age and count deletions")
    @MainActor
    func totalDeletedSum() throws {
        let result = ArticleCleanupService
            .CleanupResult(
                deletedByAge: 5,
                deletedByCount: 3
            )
        #expect(result.totalDeleted == 8)
    }
}
