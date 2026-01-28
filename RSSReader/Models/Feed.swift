//
//  Feed.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Foundation

/// Represents an RSS feed subscription in Feedly.
struct Feed: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let website: URL?
    let iconUrl: URL?
    let description: String?
    var unreadCount: Int
    let visualUrl: URL?
    let updated: Date?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Feed, rhs: Feed) -> Bool {
        lhs.id == rhs.id
    }
}
