//
//  RSSReaderApp.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import SwiftUI

@main
struct RSSReaderApp: App {
    let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
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
        .defaultSize(width: 1200, height: 800)
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
