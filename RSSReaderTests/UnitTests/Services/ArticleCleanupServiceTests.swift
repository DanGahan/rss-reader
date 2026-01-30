// swiftlint:disable file_length
//
//  ArticleCleanupServiceTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-30.
//

import CoreData
import Foundation
import Testing
@testable import RSSReader

// swiftlint:disable:next type_body_length
@Suite("ArticleCleanupService Tests")
struct ArticleCleanupServiceTests {

    private let sut = ArticleCleanupService()

    // MARK: - Helpers

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

    // MARK: - Should Run Cleanup

    @Test("shouldRunCleanup returns true when never run")
    @MainActor
    func shouldRunNeverRun() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(
            in: context
        )
        settings.lastCleanupDate = nil
        try context.save()

        #expect(
            try sut.shouldRunCleanup(in: context)
        )
    }

    @Test("shouldRunCleanup returns true after 24 hours")
    @MainActor
    func shouldRunAfter24h() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(
            in: context
        )
        settings.lastCleanupDate = Date()
            .addingTimeInterval(-25 * 3600) // 25h ago
        try context.save()

        #expect(
            try sut.shouldRunCleanup(in: context)
        )
    }

    @Test("shouldRunCleanup returns false within 24 hours")
    @MainActor
    func shouldNotRunWithin24h() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(
            in: context
        )
        settings.lastCleanupDate = Date()
            .addingTimeInterval(-1 * 3600) // 1h ago
        try context.save()

        #expect(
            try !sut.shouldRunCleanup(in: context)
        )
    }

    // MARK: - Age-Based Deletion

    @Test("Deletes read articles older than retention")
    @MainActor
    func deletesByAge() throws {
        let context = makeContext()
        let feed = makeFeed(context)

        _ = makeArticle(context, feed: feed, daysOld: 5)
        _ = makeArticle(
            context, feed: feed, daysOld: 40
        )
        _ = makeArticle(
            context, feed: feed, daysOld: 60
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
            context, feed: feed, daysOld: 60,
            isRead: false
        )
        _ = makeArticle(
            context, feed: feed, daysOld: 90,
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
            context, feed: feed, daysOld: 40,
            isRead: true
        )
        _ = makeArticle(
            context, feed: feed, daysOld: 40,
            isRead: false
        )
        _ = makeArticle(
            context, feed: feed, daysOld: 5,
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
                context, feed: feed, daysOld: day
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
            context, feed: feed, daysOld: 1
        )
        _ = makeArticle(
            context, feed: feed, daysOld: 10
        )
        _ = makeArticle(
            context, feed: feed, daysOld: 20
        )
        let a4 = makeArticle(
            context, feed: feed, daysOld: 0
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
            context, feed: feed, daysOld: 1,
            isRead: false
        )
        _ = makeArticle(
            context, feed: feed, daysOld: 2,
            isRead: false
        )
        _ = makeArticle(
            context, feed: feed, daysOld: 3,
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
                context, feed: feed1, daysOld: day
            )
        }

        // Feed2: 4 read articles → 2 deleted
        for day in 0..<4 {
            _ = makeArticle(
                context, feed: feed2, daysOld: day
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

    // MARK: - Last Cleanup Date

    @Test("performCleanup updates lastCleanupDate")
    @MainActor
    func updatesLastCleanupDate() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(
            in: context
        )
        settings.lastCleanupDate = nil
        try context.save()

        let beforeCleanup = Date()
        _ = try sut.performCleanup(in: context)

        let updatedSettings = try CDAppSettings.current(
            in: context
        )
        #expect(
            updatedSettings.lastCleanupDate != nil
        )
        #expect(
            updatedSettings.lastCleanupDate!  // swiftlint:disable:this force_unwrapping
                >= beforeCleanup
        )
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
                context, feed: feed, daysOld: day
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
            context, feed: feed, daysOld: 40
        )
        _ = makeArticle(
            context, feed: feed, daysOld: 50
        )

        // 5 recent+read (2 deleted by count,
        // since max is 3)
        for day in 0..<5 {
            _ = makeArticle(
                context, feed: feed, daysOld: day
            )
        }

        // 1 unread old (preserved)
        _ = makeArticle(
            context, feed: feed, daysOld: 60,
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
// swiftlint:enable file_length
