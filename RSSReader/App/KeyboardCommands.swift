//
//  KeyboardCommands.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import SwiftUI

/// Keyboard shortcuts for the application menu.
struct KeyboardCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add Feed") {
                NotificationCenter.default.post(
                    name: .addFeed,
                    object: nil
                )
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("New Folder") {
                NotificationCenter.default.post(
                    name: .newFolder,
                    object: nil
                )
            }
            .keyboardShortcut(
                "n",
                modifiers: [.command, .shift]
            )
        }

        CommandGroup(after: .importExport) {
            Button("Import Subscriptions...") {
                NotificationCenter.default.post(
                    name: .importOPML,
                    object: nil
                )
            }
            .keyboardShortcut(
                "i",
                modifiers: [.command, .shift]
            )

            Button("Export Subscriptions...") {
                NotificationCenter.default.post(
                    name: .exportOPML,
                    object: nil
                )
            }
            .keyboardShortcut(
                "e",
                modifiers: [.command, .shift]
            )
        }

        CommandMenu("Navigation") {
            Button("Mark All as Read") {
                NotificationCenter.default.post(
                    name: .markAllAsRead,
                    object: nil
                )
            }
            .keyboardShortcut(
                "a",
                modifiers: [.command, .shift]
            )

            Divider()

            Button("Next Unread") {
                NotificationCenter.default.post(name: .nextUnread, object: nil)
            }
            .keyboardShortcut("n", modifiers: [])

            Button("Previous Article") {
                NotificationCenter.default.post(name: .previousArticle, object: nil)
            }
            .keyboardShortcut(.upArrow, modifiers: [])

            Button("Next Article") {
                NotificationCenter.default.post(name: .nextArticle, object: nil)
            }
            .keyboardShortcut(.downArrow, modifiers: [])

            Divider()

            Button("Refresh") {
                NotificationCenter.default.post(name: .refresh, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command])

            Divider()

            Button("Open in Safari") {
                NotificationCenter.default.post(
                    name: .openInSafari,
                    object: nil
                )
            }
            .keyboardShortcut(.return, modifiers: [])

            Button("Open in Background Tab") {
                NotificationCenter.default.post(
                    name: .openInSafari,
                    object: nil
                )
            }
            .keyboardShortcut(.space, modifiers: [])
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let nextUnread = Notification.Name(
        "nextUnread"
    )
    static let previousArticle = Notification.Name(
        "previousArticle"
    )
    static let nextArticle = Notification.Name(
        "nextArticle"
    )
    static let refresh = Notification.Name("refresh")
    static let openInSafari = Notification.Name("openInSafari")
    static let markAllAsRead = Notification.Name(
        "markAllAsRead"
    )
    static let addFeed = Notification.Name("addFeed")
    static let exportOPML = Notification.Name(
        "exportOPML"
    )
    static let importOPML = Notification.Name(
        "importOPML"
    )
    static let newFolder = Notification.Name(
        "newFolder"
    )
    static let refreshIntervalChanged = Notification.Name(
        "refreshIntervalChanged"
    )
}
