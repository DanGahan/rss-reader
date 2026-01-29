//
//  PersistenceControllerTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-29.
//

import CoreData
import Testing
@testable import RSSReader

@Suite("PersistenceController Tests")
struct PersistenceControllerTests {
    // MARK: - Initialisation

    @Test("In-memory controller initialises successfully")
    func inMemoryInit() {
        let controller = PersistenceController.inMemory()
        #expect(controller.viewContext.persistentStoreCoordinator != nil)
    }

    @Test("View context is on main queue")
    func viewContextIsMainQueue() {
        let controller = PersistenceController.inMemory()
        #expect(
            controller.viewContext.concurrencyType == .mainQueueConcurrencyType
        )
    }

    // MARK: - Background Context

    @Test("Background context is created with private queue")
    func backgroundContextCreation() {
        let controller = PersistenceController.inMemory()
        let bgContext = controller.newBackgroundContext()
        #expect(
            bgContext.concurrencyType ==
                .privateQueueConcurrencyType
        )
    }

    @Test("Background context merges changes to view context")
    func backgroundContextMerge() async throws {
        let controller = PersistenceController.inMemory()
        let bgContext = controller.newBackgroundContext()

        try await bgContext.perform {
            CDFolder.create(in: bgContext, name: "BG Folder")
            try bgContext.save()
        }

        // Allow merge to propagate
        try await Task.sleep(for: .milliseconds(100))

        let request = CDFolder.fetchRequest()
        let folders = try controller.viewContext.fetch(request)
        #expect(folders.count == 1)
        #expect(folders.first?.name == "BG Folder")
    }

    // MARK: - Save

    @Test("Save persists changes")
    func saveChanges() throws {
        let controller = PersistenceController.inMemory()
        CDFolder.create(
            in: controller.viewContext,
            name: "Saved Folder"
        )
        try controller.save()

        let request = CDFolder.fetchRequest()
        let results = try controller.viewContext.fetch(request)
        #expect(results.count == 1)
    }

    @Test("Save does nothing when no changes")
    func saveNoChanges() throws {
        let controller = PersistenceController.inMemory()
        // Should not throw
        try controller.save()
    }

    // MARK: - Model Integrity

    @Test("Model contains all four entities")
    func modelEntities() {
        let model = CoreDataModel.makeModel()
        let names = model.entities.compactMap(\.name).sorted()
        #expect(names == [
            "CDAppSettings",
            "CDArticle",
            "CDFeed",
            "CDFolder"
        ])
    }

    @Test("Folder entity has feeds relationship")
    func folderEntityRelationship() {
        let model = CoreDataModel.makeModel()
        let folder = model.entitiesByName["CDFolder"]
        let rel = folder?.relationshipsByName["feeds"]
        #expect(rel != nil)
        #expect(rel?.isToMany == true)
        #expect(rel?.destinationEntity?.name == "CDFeed")
        #expect(rel?.inverseRelationship?.name == "folder")
    }

    @Test("Feed entity has articles relationship")
    func feedEntityRelationship() {
        let model = CoreDataModel.makeModel()
        let feed = model.entitiesByName["CDFeed"]
        let rel = feed?.relationshipsByName["articles"]
        #expect(rel != nil)
        #expect(rel?.isToMany == true)
        #expect(rel?.destinationEntity?.name == "CDArticle")
        #expect(rel?.inverseRelationship?.name == "feed")
    }

    @Test("Article entity has feed relationship")
    func articleEntityRelationship() {
        let model = CoreDataModel.makeModel()
        let article = model.entitiesByName["CDArticle"]
        let rel = article?.relationshipsByName["feed"]
        #expect(rel != nil)
        #expect(rel?.isToMany == false)
        #expect(rel?.destinationEntity?.name == "CDFeed")
    }
}
