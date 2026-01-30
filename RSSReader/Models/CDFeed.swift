//
//  CDFeed.swift
//  RSSReader
//
//  Created on 2026-01-29.
//

import CoreData
import Foundation

@objc(CDFeed)
public class CDFeed: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var feedURL: String
    @NSManaged public var siteURL: String?
    @NSManaged public var iconURL: String?
    @NSManaged public var lastFetched: Date?
    @NSManaged public var lastError: String?
    @NSManaged public var refreshInterval: Int32
    @NSManaged public var folder: CDFolder?
    @NSManaged public var articles: NSSet?

    /// Computed unread count: number of unread articles in
    /// this feed.
    public var unreadCount: Int {
        guard let articles = articles as? Set<CDArticle> else {
            return 0
        }
        return articles.filter { !$0.isRead }.count
    }

    /// Whether the feed has a fetch error.
    public var hasError: Bool {
        lastError != nil
    }
}

// MARK: - Fetch Request

public extension CDFeed {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<CDFeed> {
        NSFetchRequest<CDFeed>(entityName: "CDFeed")
    }
}

// MARK: - Generated Accessors for Articles

public extension CDFeed {
    @objc(addArticlesObject:)
    @NSManaged func addToArticles(_ value: CDArticle)

    @objc(removeArticlesObject:)
    @NSManaged func removeFromArticles(_ value: CDArticle)

    @objc(addArticles:)
    @NSManaged func addToArticles(_ values: NSSet)

    @objc(removeArticles:)
    @NSManaged func removeFromArticles(_ values: NSSet)
}

// MARK: - Convenience

extension CDFeed {
    /// Creates a new feed with sensible defaults.
    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
        title: String,
        feedURL: String,
        refreshInterval: Int32 = 600
    ) -> CDFeed {
        let feed = CDFeed(context: context)
        feed.id = UUID()
        feed.title = title
        feed.feedURL = feedURL
        feed.refreshInterval = refreshInterval
        return feed
    }
}
