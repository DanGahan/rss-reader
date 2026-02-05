//
//  SettingsView.swift
//  RSSReader
//
//  Created on 2026-02-04.
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var settings: CDAppSettings?
    @State private var errorMessage: String?

    // Refresh interval options in seconds
    private let refreshIntervals: [(String, Int32)] = [
        ("5 minutes", 300),
        ("10 minutes", 600),
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("1 hour", 3600),
        ("2 hours", 7200)
    ]

    // Article retention day options
    private let retentionDayOptions: [(String, Int32)] = [
        ("7 days", 7),
        ("14 days", 14),
        ("30 days", 30),
        ("60 days", 60),
        ("90 days", 90),
        ("Never", -1)
    ]

    // Article count options
    private let retentionCountOptions: [(String, Int32)] = [
        ("100 articles", 100),
        ("500 articles", 500),
        ("1000 articles", 1000),
        ("2000 articles", 2000),
        ("5000 articles", 5000),
        ("Unlimited", -1)
    ]

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            cleanupTab
                .tabItem {
                    Label("Cleanup", systemImage: "trash")
                }
        }
        .frame(width: 500, height: 300)
        .onAppear {
            loadSettings()
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section {
                refreshIntervalPicker
            } header: {
                Text("Refresh Settings")
                    .font(.headline)
            } footer: {
                Text("How often feeds should be automatically refreshed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }

    private var refreshIntervalPicker: some View {
        HStack {
            Text("Refresh interval:")
                .frame(width: 150, alignment: .trailing)

            Picker("", selection: Binding(
                get: { settings?.refreshInterval ?? CDAppSettings.defaultRefreshInterval },
                set: { newValue in
                    settings?.refreshInterval = newValue
                    saveSettings()
                }
            )) {
                ForEach(refreshIntervals, id: \.1) { option in
                    Text(option.0).tag(option.1)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)
        }
    }

    // MARK: - Cleanup Tab

    private var cleanupTab: some View {
        Form {
            Section {
                retentionDaysPicker
                retentionCountPicker

                if let lastCleanup = settings?.lastCleanupDate {
                    HStack {
                        Text("Last cleanup:")
                            .frame(width: 150, alignment: .trailing)
                        Text(lastCleanup, style: .relative)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            } header: {
                Text("Article Cleanup")
                    .font(.headline)
            } footer: {
                Text("Old articles will be automatically removed based on these settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }

    private var retentionDaysPicker: some View {
        HStack {
            Text("Keep articles for:")
                .frame(width: 150, alignment: .trailing)

            Picker("", selection: Binding(
                get: { settings?.articleRetentionDays ?? CDAppSettings.defaultRetentionDays },
                set: { newValue in
                    settings?.articleRetentionDays = newValue
                    saveSettings()
                }
            )) {
                ForEach(retentionDayOptions, id: \.1) { option in
                    Text(option.0).tag(option.1)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)
        }
    }

    private var retentionCountPicker: some View {
        HStack {
            Text("Max articles per feed:")
                .frame(width: 150, alignment: .trailing)

            Picker("", selection: Binding(
                get: { settings?.articleRetentionCount ?? CDAppSettings.defaultRetentionCount },
                set: { newValue in
                    settings?.articleRetentionCount = newValue
                    saveSettings()
                }
            )) {
                ForEach(retentionCountOptions, id: \.1) { option in
                    Text(option.0).tag(option.1)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)
        }
    }

    // MARK: - Data Management

    private func loadSettings() {
        do {
            settings = try CDAppSettings.current(in: viewContext)
        } catch {
            errorMessage = "Failed to load settings: \(error.localizedDescription)"
        }
    }

    private func saveSettings() {
        guard viewContext.hasChanges else { return }

        do {
            try viewContext.save()
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
            // Rollback changes on error
            viewContext.rollback()
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.inMemory().viewContext)
}
