//
//  CDArticle.swift
//  RSSReader
//
//  Created on 2026-01-29.
//

import CoreData
import Foundation

@objc(CDArticle)
public class CDArticle: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var title: String
    @NSManaged public var author: String?
    @NSManaged public var published: Date
    @NSManaged public var summary: String?
    @NSManaged public var content: String?
    @NSManaged public var link: String
    @NSManaged public var thumbnailURL: String?
    @NSManaged public var isRead: Bool
    @NSManaged public var dateAdded: Date
    @NSManaged public var feed: CDFeed?
}

// MARK: - Fetch Request

public extension CDArticle {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<CDArticle> {
        NSFetchRequest<CDArticle>(entityName: "CDArticle")
    }
}

// MARK: - Convenience

extension CDArticle {
    /// Creates a new article with sensible defaults.
    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
        id: String,
        title: String,
        link: String,
        published: Date,
        feed: CDFeed? = nil
    ) -> CDArticle {
        let article = CDArticle(context: context)
        article.id = id
        article.title = title
        article.link = link
        article.published = published
        article.dateAdded = Date()
        article.isRead = false
        article.feed = feed
        return article
    }
}

// MARK: - De-duplication (CloudKit Compatibility)

extension CDArticle {
    /// Checks if an article with the given ID already exists for a feed.
    ///
    /// This method performs an explicit fetch request to verify uniqueness,
    /// which is required for CloudKit compatibility since Core Data unique
    /// constraints are not supported.
    ///
    /// - Parameters:
    ///   - articleId: The article ID to check for.
    ///   - feed: The feed to check within.
    ///   - context: The managed object context to use.
    /// - Returns: The existing article if found, nil otherwise.
    static func findExisting(
        articleId: String,
        feed: CDFeed,
        in context: NSManagedObjectContext
    ) -> CDArticle? {
        let request = CDArticle.fetchRequest()
        request.predicate = NSPredicate(
            format: "id == %@ AND feed == %@",
            articleId,
            feed
        )
        request.fetchLimit = 1

        do {
            let results = try context.fetch(request)
            return results.first
        } catch {
            return nil
        }
    }

    /// Creates a new article only if one with the same ID doesn't exist for the feed.
    ///
    /// This method implements manual de-duplication for CloudKit compatibility.
    /// Core Data's unique constraints are not supported with NSPersistentCloudKitContainer,
    /// so we perform an explicit check before creating new articles.
    ///
    /// - Parameters:
    ///   - context: The managed object context.
    ///   - id: The unique article identifier.
    ///   - title: The article title.
    ///   - link: The article link.
    ///   - published: The publication date.
    ///   - feed: The feed this article belongs to.
    /// - Returns: A tuple containing the article and whether it was newly created.
    @discardableResult
    static func createIfNotExists(
        in context: NSManagedObjectContext,
        id: String,
        title: String,
        link: String,
        published: Date,
        feed: CDFeed
    ) -> (article: CDArticle, isNew: Bool) {
        // Check for existing article with same ID in this feed
        if let existing = findExisting(articleId: id, feed: feed, in: context) {
            return (existing, false)
        }

        // No duplicate found, create new article
        let article = create(
            in: context,
            id: id,
            title: title,
            link: link,
            published: published,
            feed: feed
        )
        return (article, true)
    }
}
