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
        CommandGroup(replacing: .newItem) {}

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
                NotificationCenter.default.post(name: .openInSafari, object: nil)
            }
            .keyboardShortcut(.return, modifiers: [])
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let nextUnread = Notification.Name("nextUnread")
    static let previousArticle = Notification.Name("previousArticle")
    static let nextArticle = Notification.Name("nextArticle")
    static let refresh = Notification.Name("refresh")
    static let openInSafari = Notification.Name("openInSafari")
    static let markAllAsRead = Notification.Name(
        "markAllAsRead"
    )
}
