//
//  CoreDataTestHelper.swift
//  RSSReaderTests
//
//  Created on 2026-01-29.
//

import CoreData
@testable import RSSReader

/// Provides an in-memory Core Data stack for unit tests.
enum CoreDataTestHelper {
    /// Creates a fresh in-memory managed object context.
    static func makeContext() -> NSManagedObjectContext {
        let controller = PersistenceController.inMemory()
        return controller.viewContext
    }
}
