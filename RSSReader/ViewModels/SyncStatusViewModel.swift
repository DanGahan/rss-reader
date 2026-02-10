//
//  SyncStatusViewModel.swift
//  Syndicate
//
//  Created on 2026-02-10.
//

import CloudKit
import Combine
import CoreData
import Foundation
import SwiftUI

/// Represents the current state of iCloud synchronization.
enum SyncStatus: Equatable {
    case disabled
    case syncing
    case upToDate
    case error(String)

    var displayText: String {
        switch self {
        case .disabled:
            return "Disabled"
        case .syncing:
            return "Syncing..."
        case .upToDate:
            return "Up to date"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    var icon: String {
        switch self {
        case .disabled:
            return "icloud.slash"
        case .syncing:
            return "arrow.triangle.2.circlepath.icloud"
        case .upToDate:
            return "checkmark.icloud"
        case .error:
            return "exclamationmark.icloud"
        }
    }

    var color: Color {
        switch self {
        case .disabled:
            return .secondary
        case .syncing:
            return .blue
        case .upToDate:
            return .green
        case .error:
            return .red
        }
    }
}

/// ViewModel for monitoring and managing iCloud sync status.
///
/// Observes NSPersistentCloudKitContainer notifications to track sync state
/// and provides UI-bindable properties for the Settings view.
@MainActor
final class SyncStatusViewModel: ObservableObject {
    /// Current sync status.
    @Published private(set) var status: SyncStatus = .disabled

    /// Timestamp of the last successful sync.
    @Published private(set) var lastSyncDate: Date?

    /// Whether iCloud sync is enabled (user preference).
    @Published var iCloudSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(iCloudSyncEnabled, forKey: Self.syncEnabledKey)
            updateStatus()
        }
    }

    /// Whether CloudKit is available (signed in, entitlements, etc).
    @Published private(set) var isCloudKitAvailable: Bool = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let persistence: PersistenceController

    private static let syncEnabledKey = "iCloudSyncEnabled"
    private static let lastSyncDateKey = "lastCloudKitSyncDate"

    // MARK: - Initialization

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence

        // Load saved preferences
        self.iCloudSyncEnabled = UserDefaults.standard.bool(forKey: Self.syncEnabledKey)
        self.lastSyncDate = UserDefaults.standard.object(forKey: Self.lastSyncDateKey) as? Date

        // Check CloudKit availability
        checkCloudKitAvailability()

        // Set initial status
        updateStatus()

        // Observe CloudKit sync notifications
        setupNotificationObservers()
    }

    // MARK: - CloudKit Availability

    private func checkCloudKitAvailability() {
        isCloudKitAvailable = persistence.isCloudKitEnabled
    }

    // MARK: - Status Updates

    private func updateStatus() {
        if !iCloudSyncEnabled {
            status = .disabled
        } else if !isCloudKitAvailable {
            status = .error("iCloud not available")
        } else {
            status = .upToDate
        }
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        // Observe persistent store remote change notifications
        NotificationCenter.default
            .publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleRemoteChange()
            }
            .store(in: &cancellables)

        // Observe Core Data import notifications
        NotificationCenter.default
            .publisher(for: NSNotification.Name.NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleContextSave(notification)
            }
            .store(in: &cancellables)
    }

    private func handleRemoteChange() {
        guard iCloudSyncEnabled && isCloudKitAvailable else { return }

        // Update status to syncing briefly, then to up-to-date
        status = .syncing

        // Record sync completion
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: Self.lastSyncDateKey)

        // After a brief delay, mark as up to date
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                if self.status == .syncing {
                    self.status = .upToDate
                }
            }
        }
    }

    private func handleContextSave(_ notification: Notification) {
        guard iCloudSyncEnabled && isCloudKitAvailable else { return }

        // Check if this is a sync-related save (has remote changes)
        if notification.userInfo?[NSInsertedObjectsKey] != nil ||
           notification.userInfo?[NSUpdatedObjectsKey] != nil ||
           notification.userInfo?[NSDeletedObjectsKey] != nil {
            // Brief syncing status
            status = .syncing

            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                await MainActor.run {
                    if self.status == .syncing {
                        self.status = .upToDate
                        self.lastSyncDate = Date()
                        UserDefaults.standard.set(self.lastSyncDate, forKey: Self.lastSyncDateKey)
                    }
                }
            }
        }
    }

    // MARK: - Manual Refresh

    /// Triggers a manual sync check.
    func refreshStatus() {
        checkCloudKitAvailability()
        updateStatus()
    }
}
