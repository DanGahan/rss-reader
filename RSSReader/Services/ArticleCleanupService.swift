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
    /// Returns true if the store supports batch operations.
    /// In-memory stores do NOT support batch delete.
    func supportsBatchOperations(
        _ context: NSManagedObjectContext
    ) -> Bool {
        guard let coordinator = context
            .persistentStoreCoordinator
        else { return false }

        return coordinator.persistentStores.allSatisfy {
            $0.type == NSSQLiteStoreType
        }
    }

    /// Deletes all read articles added before the
    /// cutoff date. Uses batch delete for SQLite stores,
    /// falls back to regular delete for in-memory stores.
    func deleteByAge(
        before cutoffDate: Date,
        in context: NSManagedObjectContext
    ) throws -> Int {
        let fetchRequest: NSFetchRequest<CDArticle> =
            CDArticle.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "isRead == YES AND dateAdded < %@",
            cutoffDate as NSDate
        )

        // Use batch delete only for SQLite stores
        if supportsBatchOperations(context) {
            return try batchDelete(
                fetchRequest: fetchRequest, in: context
            )
        }

        // Regular delete for in-memory stores
        let articles = try context.fetch(fetchRequest)
        for article in articles {
            context.delete(article)
        }
        return articles.count
    }

    /// Performs batch delete (only call for SQLite stores).
    private func batchDelete<T: NSManagedObject>(
        fetchRequest: NSFetchRequest<T>,
        in context: NSManagedObjectContext
    ) throws -> Int {
        let batchRequest = NSBatchDeleteRequest(
            fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>
        )
        batchRequest.resultType = .resultTypeCount

        let result = try context.execute(batchRequest)
            as? NSBatchDeleteResult
        let deletedCount = result?.result as? Int ?? 0

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

    /// Deletes excess read articles for a single feed.
    /// Uses batch delete for SQLite, regular delete for
    /// in-memory stores.
    func deleteExcess(
        for feed: CDFeed,
        maxCount: Int,
        in context: NSManagedObjectContext
    ) throws -> Int {
        let countRequest: NSFetchRequest<CDArticle> =
            CDArticle.fetchRequest()
        countRequest.predicate = NSPredicate(
            format: "feed == %@ AND isRead == YES",
            feed
        )
        countRequest.sortDescriptors = [
            NSSortDescriptor(
                key: "dateAdded", ascending: false
            )
        ]

        let articles = try context.fetch(countRequest)

        guard articles.count > maxCount else {
            return 0
        }

        // Get articles to delete (all beyond maxCount)
        let articlesToDelete = Array(
            articles.dropFirst(maxCount)
        )

        guard !articlesToDelete.isEmpty else { return 0 }

        // Use batch delete only for SQLite stores
        if supportsBatchOperations(context) {
            let objectIDs = articlesToDelete.map {
                $0.objectID
            }
            return try batchDeleteByIDs(objectIDs, in: context)
        }

        // Regular delete for in-memory stores
        for article in articlesToDelete {
            context.delete(article)
        }
        return articlesToDelete.count
    }

    /// Performs batch delete by object IDs.
    private func batchDeleteByIDs(
        _ objectIDs: [NSManagedObjectID],
        in context: NSManagedObjectContext
    ) throws -> Int {
        let batchDelete = NSBatchDeleteRequest(
            objectIDs: objectIDs
        )
        batchDelete.resultType = .resultTypeCount

        let result = try context.execute(batchDelete)
            as? NSBatchDeleteResult
        return result?.result as? Int ?? objectIDs.count
    }
}
