//
//  ArticleCleanupServiceSchedulingTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-03.
//

import CoreData
import Foundation
import Testing
@testable import RSSReader

@Suite("ArticleCleanupService Scheduling Tests")
struct ArticleCleanupServiceSchedulingTests {
    private let sut = ArticleCleanupService()

    private func makeContext() -> NSManagedObjectContext {
        CoreDataTestHelper.makeContext()
    }

    // MARK: - Should Run Cleanup

    @Test("shouldRunCleanup returns true when never run")
    @MainActor
    func shouldRunNeverRun() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(
            in: context
        )
        settings.lastCleanupDate = nil
        try context.save()

        #expect(
            try sut.shouldRunCleanup(in: context)
        )
    }

    @Test("shouldRunCleanup returns true after 24 hours")
    @MainActor
    func shouldRunAfter24h() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(
            in: context
        )
        settings.lastCleanupDate = Date()
            .addingTimeInterval(-25 * 3600) // 25h ago
        try context.save()

        #expect(
            try sut.shouldRunCleanup(in: context)
        )
    }

    @Test("shouldRunCleanup returns false within 24 hours")
    @MainActor
    func shouldNotRunWithin24h() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(
            in: context
        )
        settings.lastCleanupDate = Date()
            .addingTimeInterval(-1 * 3600) // 1h ago
        try context.save()

        #expect(
            try !sut.shouldRunCleanup(in: context)
        )
    }

    @Test("performCleanup updates lastCleanupDate")
    @MainActor
    func updatesLastCleanupDate() throws {
        let context = makeContext()
        let settings = try CDAppSettings.current(
            in: context
        )
        settings.lastCleanupDate = nil
        try context.save()

        let beforeCleanup = Date()
        _ = try sut.performCleanup(in: context)

        let updatedSettings = try CDAppSettings.current(
            in: context
        )
        #expect(
            updatedSettings.lastCleanupDate != nil
        )
        #expect(
            try #require(updatedSettings.lastCleanupDate)
                >= beforeCleanup
        )
    }
}
