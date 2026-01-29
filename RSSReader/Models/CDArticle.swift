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

extension CDArticle {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<CDArticle> {
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
