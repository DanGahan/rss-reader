//
//  CDAppSettingsTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-29.
//

import CoreData
import Testing
@testable import RSSReader

@Suite("CDAppSettings Tests")
struct CDAppSettingsTests {
    // MARK: - Entity Creation

    @Test("Settings created with correct defaults")
    func defaultSettings() throws {
        let context = CoreDataTestHelper.makeContext()
        let settings = try CDAppSettings.current(in: context)

        #expect(settings.refreshInterval == 600)
        #expect(settings.articleRetentionDays == 30)
        #expect(settings.articleRetentionCount == 1000)
        #expect(settings.lastCleanupDate == nil)
    }

    // MARK: - Singleton Behaviour

    @Test("Current returns same instance on repeated calls")
    func singletonBehaviour() throws {
        let context = CoreDataTestHelper.makeContext()
        let first = try CDAppSettings.current(in: context)
        try context.save()

        let second = try CDAppSettings.current(in: context)
        #expect(first.id == second.id)
    }

    // MARK: - Mutability

    @Test("Settings can be updated")
    func updateSettings() throws {
        let context = CoreDataTestHelper.makeContext()
        let settings = try CDAppSettings.current(in: context)
        settings.refreshInterval = 300
        settings.articleRetentionDays = 60
        settings.articleRetentionCount = 500
        settings.lastCleanupDate = Date()
        try context.save()

        let fetched = try CDAppSettings.current(in: context)
        #expect(fetched.refreshInterval == 300)
        #expect(fetched.articleRetentionDays == 60)
        #expect(fetched.articleRetentionCount == 500)
        #expect(fetched.lastCleanupDate != nil)
    }

    // MARK: - Default Constants

    @Test("Default constants match expected values")
    func defaultConstants() {
        #expect(CDAppSettings.defaultRefreshInterval == 600)
        #expect(CDAppSettings.defaultRetentionDays == 30)
        #expect(CDAppSettings.defaultRetentionCount == 1000)
    }
}
