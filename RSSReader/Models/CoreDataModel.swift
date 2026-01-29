//
//  CoreDataModel.swift
//  RSSReader
//
//  Created on 2026-01-29.
//

import CoreData
import Foundation

// swiftlint:disable function_body_length

/// Builds the Core Data NSManagedObjectModel programmatically.
///
/// This allows SPM-based tests to run without a compiled
/// `.xcdatamodeld` bundle, which only Xcode produces.
enum CoreDataModel {
    // Shared model instance. Core Data requires a single model
    // per class name to avoid ambiguity, so we cache it.
    private static let shared: NSManagedObjectModel = buildModel()

    /// Returns the shared managed object model.
    static func makeModel() -> NSManagedObjectModel {
        shared
    }

    private static func buildModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // MARK: - Entities

        let folderEntity = makeFolderEntity()
        let feedEntity = makeFeedEntity()
        let articleEntity = makeArticleEntity()
        let settingsEntity = makeAppSettingsEntity()

        // MARK: - Relationships

        configureFolderFeedRelationship(
            folder: folderEntity,
            feed: feedEntity
        )
        configureFeedArticleRelationship(
            feed: feedEntity,
            article: articleEntity
        )

        model.entities = [
            folderEntity,
            feedEntity,
            articleEntity,
            settingsEntity
        ]

        return model
    }

    // MARK: - Entity Builders

    private static func makeFolderEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CDFolder"
        entity.managedObjectClassName = "CDFolder"
        entity.properties = [
            makeAttribute(
                name: "id",
                type: .UUIDAttributeType
            ),
            makeAttribute(
                name: "name",
                type: .stringAttributeType
            ),
            makeAttribute(
                name: "sortOrder",
                type: .integer32AttributeType,
                defaultValue: Int32(0)
            ),
            makeAttribute(
                name: "dateCreated",
                type: .dateAttributeType
            )
        ]
        return entity
    }

    private static func makeFeedEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CDFeed"
        entity.managedObjectClassName = "CDFeed"
        entity.properties = [
            makeAttribute(
                name: "id",
                type: .UUIDAttributeType
            ),
            makeAttribute(
                name: "title",
                type: .stringAttributeType
            ),
            makeAttribute(
                name: "feedURL",
                type: .stringAttributeType
            ),
            makeAttribute(
                name: "siteURL",
                type: .stringAttributeType,
                isOptional: true
            ),
            makeAttribute(
                name: "iconURL",
                type: .stringAttributeType,
                isOptional: true
            ),
            makeAttribute(
                name: "lastFetched",
                type: .dateAttributeType,
                isOptional: true
            ),
            makeAttribute(
                name: "lastError",
                type: .stringAttributeType,
                isOptional: true
            ),
            makeAttribute(
                name: "refreshInterval",
                type: .integer32AttributeType,
                defaultValue: Int32(600)
            )
        ]
        return entity
    }

    private static func makeArticleEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CDArticle"
        entity.managedObjectClassName = "CDArticle"
        entity.properties = [
            makeAttribute(
                name: "id",
                type: .stringAttributeType
            ),
            makeAttribute(
                name: "title",
                type: .stringAttributeType
            ),
            makeAttribute(
                name: "author",
                type: .stringAttributeType,
                isOptional: true
            ),
            makeAttribute(
                name: "published",
                type: .dateAttributeType
            ),
            makeAttribute(
                name: "summary",
                type: .stringAttributeType,
                isOptional: true
            ),
            makeAttribute(
                name: "content",
                type: .stringAttributeType,
                isOptional: true
            ),
            makeAttribute(
                name: "link",
                type: .stringAttributeType
            ),
            makeAttribute(
                name: "thumbnailURL",
                type: .stringAttributeType,
                isOptional: true
            ),
            makeAttribute(
                name: "isRead",
                type: .booleanAttributeType,
                defaultValue: false
            ),
            makeAttribute(
                name: "dateAdded",
                type: .dateAttributeType
            )
        ]
        return entity
    }

    private static func makeAppSettingsEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "CDAppSettings"
        entity.managedObjectClassName = "CDAppSettings"
        entity.properties = [
            makeAttribute(
                name: "id",
                type: .UUIDAttributeType
            ),
            makeAttribute(
                name: "refreshInterval",
                type: .integer32AttributeType,
                defaultValue: Int32(600)
            ),
            makeAttribute(
                name: "articleRetentionDays",
                type: .integer32AttributeType,
                defaultValue: Int32(30)
            ),
            makeAttribute(
                name: "articleRetentionCount",
                type: .integer32AttributeType,
                defaultValue: Int32(1000)
            ),
            makeAttribute(
                name: "lastCleanupDate",
                type: .dateAttributeType,
                isOptional: true
            )
        ]
        return entity
    }

    // MARK: - Relationship Configuration

    private static func configureFolderFeedRelationship(
        folder: NSEntityDescription,
        feed: NSEntityDescription
    ) {
        let folderToFeeds = NSRelationshipDescription()
        folderToFeeds.name = "feeds"
        folderToFeeds.destinationEntity = feed
        folderToFeeds.minCount = 0
        folderToFeeds.maxCount = 0 // to-many
        folderToFeeds.deleteRule = .cascadeDeleteRule
        folderToFeeds.isOptional = true

        let feedToFolder = NSRelationshipDescription()
        feedToFolder.name = "folder"
        feedToFolder.destinationEntity = folder
        feedToFolder.minCount = 0
        feedToFolder.maxCount = 1
        feedToFolder.deleteRule = .nullifyDeleteRule
        feedToFolder.isOptional = true

        folderToFeeds.inverseRelationship = feedToFolder
        feedToFolder.inverseRelationship = folderToFeeds

        folder.properties.append(folderToFeeds)
        feed.properties.append(feedToFolder)
    }

    private static func configureFeedArticleRelationship(
        feed: NSEntityDescription,
        article: NSEntityDescription
    ) {
        let feedToArticles = NSRelationshipDescription()
        feedToArticles.name = "articles"
        feedToArticles.destinationEntity = article
        feedToArticles.minCount = 0
        feedToArticles.maxCount = 0 // to-many
        feedToArticles.deleteRule = .cascadeDeleteRule
        feedToArticles.isOptional = true

        let articleToFeed = NSRelationshipDescription()
        articleToFeed.name = "feed"
        articleToFeed.destinationEntity = feed
        articleToFeed.minCount = 0
        articleToFeed.maxCount = 1
        articleToFeed.deleteRule = .nullifyDeleteRule
        articleToFeed.isOptional = true

        feedToArticles.inverseRelationship = articleToFeed
        articleToFeed.inverseRelationship = feedToArticles

        feed.properties.append(feedToArticles)
        article.properties.append(articleToFeed)
    }

    // MARK: - Attribute Helper

    private static func makeAttribute(
        name: String,
        type: NSAttributeType,
        isOptional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        if let defaultValue {
            attribute.defaultValue = defaultValue
        }
        return attribute
    }
}

// swiftlint:enable function_body_length
