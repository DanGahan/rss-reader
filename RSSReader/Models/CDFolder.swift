//
//  CDFolder.swift
//  RSSReader
//
//  Created on 2026-01-29.
//

import CoreData
import Foundation

@objc(CDFolder)
public class CDFolder: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var sortOrder: Int32
    @NSManaged public var dateCreated: Date
    @NSManaged public var feeds: NSSet?

    /// Computed unread count: sum of unread articles across
    /// all feeds in this folder.
    public var unreadCount: Int {
        guard let feeds = feeds as? Set<CDFeed> else {
            return 0
        }
        return feeds.reduce(0) { $0 + $1.unreadCount }
    }
}

// MARK: - Fetch Request

extension CDFolder {
    @nonobjc
    public class func fetchRequest() -> NSFetchRequest<CDFolder> {
        NSFetchRequest<CDFolder>(entityName: "CDFolder")
    }
}

// MARK: - Generated Accessors for Feeds

extension CDFolder {
    @objc(addFeedsObject:)
    @NSManaged public func addToFeeds(_ value: CDFeed)

    @objc(removeFeedsObject:)
    @NSManaged public func removeFromFeeds(_ value: CDFeed)

    @objc(addFeeds:)
    @NSManaged public func addToFeeds(_ values: NSSet)

    @objc(removeFeeds:)
    @NSManaged public func removeFromFeeds(_ values: NSSet)
}

// MARK: - Convenience

extension CDFolder {
    /// Creates a new folder with sensible defaults.
    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
        name: String,
        sortOrder: Int32 = 0
    ) -> CDFolder {
        let folder = CDFolder(context: context)
        folder.id = UUID()
        folder.name = name
        folder.sortOrder = sortOrder
        folder.dateCreated = Date()
        return folder
    }
}
