//
//  FeedlyUser.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Foundation

/// Represents a Feedly user profile.
struct FeedlyUser: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let fullName: String?
    let picture: URL?
    let givenName: String?
    let familyName: String?
    let locale: String?

    /// Display name, falling back to email if full name is unavailable.
    var displayName: String {
        fullName ?? email
    }
}
