//
//  SyndicateApp.swift
//  Syndicate
//
//  Created on 2026-01-28.
//

import SwiftUI

/// Check if running as a test host (unit tests inject XCTest bundle)
let isRunningTests: Bool = {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}()

@main
struct SyndicateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            if isRunningTests {
                EmptyView()
            } else {
                ContentView()
                    .environment(
                        \.managedObjectContext,
                        persistence.viewContext
                    )
                    .frame(
                        minWidth: 1000,
                        minHeight: 600
                    )
            }
        }
        .defaultSize(width: isRunningTests ? 1 : 1200, height: isRunningTests ? 1 : 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            KeyboardCommands()
        }

        Settings {
            SettingsView()
                .environment(
                    \.managedObjectContext,
                    persistence.viewContext
                )
        }
    }
}

/// App delegate to suppress windows during unit tests
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        if isRunningTests {
            // Set to accessory app before any windows are created
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if isRunningTests {
            // Close any windows that were created
            NSApplication.shared.windows.forEach { $0.close() }
        }
    }
}
