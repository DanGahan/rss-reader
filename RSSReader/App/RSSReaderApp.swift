//
//  RSSReaderApp.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import SwiftUI

@main
struct RSSReaderApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .commands {
            KeyboardCommands()
        }
    }
}
