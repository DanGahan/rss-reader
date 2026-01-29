//
//  CDAppSettings.swift
//  RSSReader
//
//  Created on 2026-01-29.
//

import CoreData
import Foundation

@objc(CDAppSettings)
public class CDAppSettings: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var refreshInterval: Int32
    @NSManaged public var articleRetentionDays: Int32
    @NSManaged public var articleRetentionCount: Int32
    @NSManaged public var lastCleanupDate: Date?
}

// MARK: - Fetch Request

public extension CDAppSettings {
    @nonobjc
    class func fetchRequest() -> NSFetchRequest<CDAppSettings> {
        NSFetchRequest<CDAppSettings>(entityName: "CDAppSettings")
    }
}

// MARK: - Defaults

extension CDAppSettings {
    /// Default refresh interval in seconds (10 minutes).
    static let defaultRefreshInterval: Int32 = 600

    /// Default article retention in days.
    static let defaultRetentionDays: Int32 = 30

    /// Default max articles per feed.
    static let defaultRetentionCount: Int32 = 1000
}

// MARK: - Convenience

extension CDAppSettings {
    /// Fetches the singleton settings, creating defaults if none
    /// exist.
    static func current(
        in context: NSManagedObjectContext
    ) throws -> CDAppSettings {
        let request = CDAppSettings.fetchRequest()
        request.fetchLimit = 1
        if let existing = try context.fetch(request).first {
            return existing
        }
        let settings = CDAppSettings(context: context)
        settings.id = UUID()
        settings.refreshInterval = defaultRefreshInterval
        settings.articleRetentionDays = defaultRetentionDays
        settings.articleRetentionCount = defaultRetentionCount
        return settings
    }
}
