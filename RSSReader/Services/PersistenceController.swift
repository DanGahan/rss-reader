//
//  PersistenceController.swift
//  Syndicate
//
//  Created on 2026-01-29.
//

import CloudKit
import CoreData
import Foundation

/// Manages the Core Data stack for local RSS data persistence with iCloud sync support.
///
/// Provides both a main-thread `viewContext` for reads/UI binding
/// and a factory method for background contexts used in write
/// operations (feed refresh, article imports, cleanup).
///
/// When iCloud sync is enabled, uses `NSPersistentCloudKitContainer` to
/// automatically sync data to the user's private CloudKit database.
final class PersistenceController: @unchecked Sendable {
    /// Shared instance for the app. Uses on-disk SQLite store with iCloud sync.
    static let shared = PersistenceController()

    /// In-memory instance for SwiftUI previews and unit tests.
    /// Does not sync to iCloud.
    static func inMemory() -> PersistenceController {
        PersistenceController(inMemory: true)
    }

    /// The iCloud container identifier for CloudKit sync.
    static let cloudKitContainerIdentifier = "iCloud.com.syndicate.app"

    /// Whether CloudKit sync is enabled for this controller.
    let isCloudKitEnabled: Bool

    /// The underlying persistent container with CloudKit support.
    let container: NSPersistentCloudKitContainer

    /// Main-thread context for UI reads and light writes.
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Creates a new background context for write operations.
    ///
    /// Use this for feed refreshes, article imports, and any
    /// batch operations to avoid blocking the main thread.
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    /// Saves the view context if it has pending changes.
    func save() throws {
        let context = viewContext
        guard context.hasChanges else { return }
        try context.save()
    }

    // MARK: - Initialisation

    init(inMemory: Bool = false) {
        let model = CoreDataModel.makeModel()
        container = NSPersistentCloudKitContainer(
            name: "Syndicate",
            managedObjectModel: model
        )

        if inMemory {
            // Create a fresh in-memory store description without any CloudKit config
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            description.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [description]
            isCloudKitEnabled = false
        } else {
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("No persistent store descriptions found")
            }

            // Enable persistent history tracking for CloudKit sync
            description.setOption(
                true as NSNumber,
                forKey: NSPersistentHistoryTrackingKey
            )
            description.setOption(
                true as NSNumber,
                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
            )

            // Check if CloudKit is available before enabling sync
            // CloudKit requires:
            // 1. A signed-in iCloud account
            // 2. The app to be properly code-signed with iCloud entitlements
            let cloudKitAvailable = Self.isCloudKitAvailable()

            if cloudKitAvailable {
                let cloudKitOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: Self.cloudKitContainerIdentifier
                )
                description.cloudKitContainerOptions = cloudKitOptions
                isCloudKitEnabled = true
            } else {
                // CloudKit not available - run in local-only mode
                description.cloudKitContainerOptions = nil
                isCloudKitEnabled = false
            }
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError(
                    "Core Data store failed to load: \(error)"
                )
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy =
            NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - CloudKit Availability

    /// Checks if CloudKit is available for use.
    ///
    /// CloudKit requires the user to be signed into iCloud and the app
    /// to be properly code-signed with iCloud entitlements.
    private static func isCloudKitAvailable() -> Bool {
        // Check if we're running in a test environment
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return false
        }

        // Check if iCloud is available by trying to access the container
        let container = CKContainer(identifier: cloudKitContainerIdentifier)
        var isAvailable = false

        let semaphore = DispatchSemaphore(value: 0)
        container.accountStatus { status, _ in
            isAvailable = (status == .available)
            semaphore.signal()
        }

        // Wait briefly for the check to complete (max 2 seconds)
        _ = semaphore.wait(timeout: .now() + 2.0)

        return isAvailable
    }
}
