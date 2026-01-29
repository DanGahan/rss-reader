//
//  Category.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Foundation

/// Represents a Feedly category containing grouped feeds.
struct Category: Identifiable, Hashable {
    let id: String
    let label: String
    var unreadCount: Int
    var feeds: [Feed]

    /// Display-friendly name, stripping the Feedly user prefix.
    var displayName: String {
        label.replacingOccurrences(
            of: "user/\\w+/category/",
            with: "",
            options: .regularExpression
        )
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
