//
//  Subscription.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Foundation

/// Represents a Feedly subscription with category associations.
struct Subscription: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let categories: [CategoryReference]
    let website: URL?
    let iconUrl: URL?
    let visualUrl: URL?

    /// Lightweight reference to a category from a subscription response.
    struct CategoryReference: Codable, Equatable {
        let id: String
        let label: String
    }
}
