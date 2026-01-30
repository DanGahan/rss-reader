//
//  RSSReaderApp.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import SwiftUI

@main
struct RSSReaderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(
                    minWidth: 1000,
                    minHeight: 600
                )
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            KeyboardCommands()
        }
    }
}
