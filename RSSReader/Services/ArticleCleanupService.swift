//
//  ArticleCleanupService.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import CoreData
import Foundation

/// Automatically deletes old, read articles to keep
/// the app fast and limit disk usage.
///
/// **Retention rules (never applied to unread):**
/// - Age: articles older than `retentionDays`
/// - Count: keep at most `retentionCount` per feed
///
/// Cleanup runs on a background context to avoid
/// blocking the UI.
struct ArticleCleanupService {
    /// Result of a cleanup operation.
    struct CleanupResult: Equatable {
        let deletedByAge: Int
        let deletedByCount: Int

        var totalDeleted: Int {
            deletedByAge + deletedByCount
        }
    }

    /// Whether cleanup should run, based on the time
    /// since the last cleanup (24-hour cooldown).
    func shouldRunCleanup(
        in context: NSManagedObjectContext
    ) throws -> Bool {
        let settings = try CDAppSettings.current(
            in: context
        )
        guard let lastCleanup = settings.lastCleanupDate
        else {
            return true // Never run before
        }

        let hoursSinceLast = Date()
            .timeIntervalSince(lastCleanup) / 3600
        return hoursSinceLast >= 24
    }

    /// Performs cleanup using the given context.
    ///
    /// Deletes read articles that exceed retention
    /// rules, then updates `lastCleanupDate`.
    @discardableResult
    func performCleanup(
        in context: NSManagedObjectContext
    ) throws -> CleanupResult {
        let settings = try CDAppSettings.current(
            in: context
        )

        let retentionDays = Int(
            settings.articleRetentionDays
        )
        let retentionCount = Int(
            settings.articleRetentionCount
        )

        let cutoffDate = Date().addingTimeInterval(
            -Double(retentionDays) * 86400
        )

        let deletedByAge = try deleteByAge(
            before: cutoffDate, in: context
        )

        let deletedByCount = try deleteByCount(
            maxPerFeed: retentionCount, in: context
        )

        settings.lastCleanupDate = Date()
        try context.save()

        return CleanupResult(
            deletedByAge: deletedByAge,
            deletedByCount: deletedByCount
        )
    }
}

// MARK: - Private Helpers

private extension ArticleCleanupService {
    /// Deletes all read articles added before the
    /// cutoff date using batch delete for performance.
    func deleteByAge(
        before cutoffDate: Date,
        in context: NSManagedObjectContext
    ) throws -> Int {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> =
            CDArticle.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "isRead == YES AND dateAdded < %@",
            cutoffDate as NSDate
        )

        let batchDelete = NSBatchDeleteRequest(
            fetchRequest: fetchRequest
        )
        batchDelete.resultType = .resultTypeCount

        let result = try context.execute(batchDelete)
            as? NSBatchDeleteResult
        let deletedCount = result?.result as? Int ?? 0

        // Merge changes into context to keep UI in sync
        if deletedCount > 0 {
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [
                    NSDeletedObjectsKey: []
                ],
                into: [context]
            )
        }

        return deletedCount
    }

    /// Deletes read articles beyond the per-feed
    /// retention count, keeping the newest.
    func deleteByCount(
        maxPerFeed: Int,
        in context: NSManagedObjectContext
    ) throws -> Int {
        let feedRequest = CDFeed.fetchRequest()
        let feeds = try context.fetch(feedRequest)

        var totalDeleted = 0

        for feed in feeds {
            totalDeleted += try deleteExcess(
                for: feed,
                maxCount: maxPerFeed,
                in: context
            )
        }

        return totalDeleted
    }

    /// Deletes excess read articles for a single feed using
    /// batch delete for performance.
    func deleteExcess(
        for feed: CDFeed,
        maxCount: Int,
        in context: NSManagedObjectContext
    ) throws -> Int {
        // First, fetch only IDs to minimize memory usage
        let countRequest = CDArticle.fetchRequest()
        countRequest.predicate = NSPredicate(
            format: "feed == %@ AND isRead == YES",
            feed
        )
        countRequest.sortDescriptors = [
            NSSortDescriptor(
                key: "dateAdded", ascending: false
            )
        ]
        countRequest.propertiesToFetch = ["id"]
        countRequest.resultType = .managedObjectIDResultType

        let objectIDs = try context.fetch(countRequest)
            as? [NSManagedObjectID] ?? []

        guard objectIDs.count > maxCount else {
            return 0
        }

        // Get IDs of articles to delete (all beyond maxCount)
        let idsToDelete = Array(objectIDs.dropFirst(maxCount))

        guard !idsToDelete.isEmpty else { return 0 }

        // Use batch delete with specific object IDs
        let batchDelete = NSBatchDeleteRequest(
            objectIDs: idsToDelete
        )
        batchDelete.resultType = .resultTypeCount

        let result = try context.execute(batchDelete)
            as? NSBatchDeleteResult

        return result?.result as? Int ?? idsToDelete.count
    }
}
