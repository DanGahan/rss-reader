//
//  PersistenceController.swift
//  RSSReader
//
//  Created on 2026-01-29.
//

import CoreData
import Foundation

/// Manages the Core Data stack for local RSS data persistence.
///
/// Provides both a main-thread `viewContext` for reads/UI binding
/// and a factory method for background contexts used in write
/// operations (feed refresh, article imports, cleanup).
final class PersistenceController: @unchecked Sendable {
    /// Shared instance for the app. Uses on-disk SQLite store.
    static let shared = PersistenceController()

    /// In-memory instance for SwiftUI previews and unit tests.
    static func inMemory() -> PersistenceController {
        PersistenceController(inMemory: true)
    }

    /// The underlying persistent container.
    let container: NSPersistentContainer

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
        container = NSPersistentContainer(
            name: "RSSReader",
            managedObjectModel: model
        )

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
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
}
