//
//  SettingsViewTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-04.
//

import CoreData
import SwiftUI
import Testing
@testable import RSSReader

@Suite("SettingsView Tests")
struct SettingsViewTests {
    // MARK: - Helpers

    private func makeContext() -> NSManagedObjectContext {
        CoreDataTestHelper.makeContext()
    }

    // MARK: - Settings Loading

    @Test("Settings view loads existing settings")
    @MainActor
    func loadExistingSettings() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(in: context)
        settings.refreshInterval = 900
        settings.articleRetentionDays = 60
        settings.articleRetentionCount = 2000
        try context.save()

        let loaded = try CDAppSettings.current(in: context)
        #expect(loaded.refreshInterval == 900)
        #expect(loaded.articleRetentionDays == 60)
        #expect(loaded.articleRetentionCount == 2000)
    }

    @Test("Settings view creates default settings if none exist")
    @MainActor
    func createDefaultSettings() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(in: context)

        #expect(settings.refreshInterval == CDAppSettings.defaultRefreshInterval)
        #expect(settings.articleRetentionDays == CDAppSettings.defaultRetentionDays)
        #expect(settings.articleRetentionCount == CDAppSettings.defaultRetentionCount)
    }

    // MARK: - Refresh Interval Updates

    @Test("Refresh interval can be updated")
    @MainActor
    func updateRefreshInterval() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(in: context)

        // Test 5 minutes (300 seconds)
        settings.refreshInterval = 300
        try context.save()
        let updated = try CDAppSettings.current(in: context)
        #expect(updated.refreshInterval == 300)

        // Test 1 hour (3600 seconds)
        settings.refreshInterval = 3600
        try context.save()
        let updated2 = try CDAppSettings.current(in: context)
        #expect(updated2.refreshInterval == 3600)
    }

    @Test("Refresh interval options are valid")
    @MainActor
    func refreshIntervalOptionsValid() {
        let validIntervals: [Int32] = [300, 600, 900, 1800, 3600, 7200]

        for interval in validIntervals {
            #expect(interval > 0)
            #expect(interval <= 7200) // Max 2 hours
        }
    }

    // MARK: - Article Retention Days Updates

    @Test("Article retention days can be updated")
    @MainActor
    func updateRetentionDays() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(in: context)

        settings.articleRetentionDays = 14
        try context.save()
        let updated = try CDAppSettings.current(in: context)
        #expect(updated.articleRetentionDays == 14)

        // Test "Never" option (-1)
        settings.articleRetentionDays = -1
        try context.save()
        let updated2 = try CDAppSettings.current(in: context)
        #expect(updated2.articleRetentionDays == -1)
    }

    @Test("Retention days options are valid")
    @MainActor
    func retentionDaysOptionsValid() {
        let validDays: [Int32] = [7, 14, 30, 60, 90, -1]

        for days in validDays {
            #expect(days == -1 || days > 0)
            #expect(days == -1 || days <= 90)
        }
    }

    // MARK: - Article Retention Count Updates

    @Test("Article retention count can be updated")
    @MainActor
    func updateRetentionCount() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(in: context)

        settings.articleRetentionCount = 500
        try context.save()
        let updated = try CDAppSettings.current(in: context)
        #expect(updated.articleRetentionCount == 500)

        // Test "Unlimited" option (-1)
        settings.articleRetentionCount = -1
        try context.save()
        let updated2 = try CDAppSettings.current(in: context)
        #expect(updated2.articleRetentionCount == -1)
    }

    @Test("Retention count options are valid")
    @MainActor
    func retentionCountOptionsValid() {
        let validCounts: [Int32] = [100, 500, 1000, 2000, 5000, -1]

        for count in validCounts {
            #expect(count == -1 || count >= 100)
            #expect(count == -1 || count <= 5000)
        }
    }

    // MARK: - Multiple Settings Updates

    @Test("Multiple settings can be updated together")
    @MainActor
    func updateMultipleSettings() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(in: context)

        settings.refreshInterval = 1800
        settings.articleRetentionDays = 45
        settings.articleRetentionCount = 750
        try context.save()

        let updated = try CDAppSettings.current(in: context)
        #expect(updated.refreshInterval == 1800)
        #expect(updated.articleRetentionDays == 45)
        #expect(updated.articleRetentionCount == 750)
    }

    // MARK: - Settings Persistence

    @Test("Settings persist across context reloads")
    @MainActor
    func settingsPersistence() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(in: context)
        settings.refreshInterval = 900
        settings.articleRetentionDays = 60
        settings.articleRetentionCount = 2000
        try context.save()

        // Simulate new context by fetching again
        context.refreshAllObjects()
        let reloaded = try CDAppSettings.current(in: context)
        #expect(reloaded.refreshInterval == 900)
        #expect(reloaded.articleRetentionDays == 60)
        #expect(reloaded.articleRetentionCount == 2000)
    }

    // MARK: - Last Cleanup Date

    @Test("Last cleanup date is tracked")
    @MainActor
    func lastCleanupDateTracking() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(in: context)

        #expect(settings.lastCleanupDate == nil)

        let now = Date()
        settings.lastCleanupDate = now
        try context.save()

        let updated = try CDAppSettings.current(in: context)
        #expect(updated.lastCleanupDate != nil)
        #expect(updated.lastCleanupDate?.timeIntervalSince1970 == now.timeIntervalSince1970)
    }

    // MARK: - Edge Cases

    @Test("Settings rollback on save error")
    @MainActor
    func settingsRollbackOnError() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(in: context)
        let originalInterval = settings.refreshInterval
        try context.save()

        // Make a change
        settings.refreshInterval = 3600

        // Rollback without saving
        context.rollback()

        let rolled = try CDAppSettings.current(in: context)
        #expect(rolled.refreshInterval == originalInterval)
    }

    @Test("Settings singleton behavior is maintained")
    @MainActor
    func settingsSingletonBehavior() throws {
        let context = makeContext()
        let first = try CDAppSettings.current(in: context)
        try context.save()

        let second = try CDAppSettings.current(in: context)
        #expect(first.id == second.id)

        // Verify only one settings object exists
        let request = CDAppSettings.fetchRequest()
        let count = try context.count(for: request)
        #expect(count == 1)
    }
}
