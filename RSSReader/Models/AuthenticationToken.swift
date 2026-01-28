//
//  AuthenticationToken.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Foundation

/// Represents an OAuth authentication token from Feedly.
struct AuthenticationToken: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresIn: TimeInterval
    let scope: String?

    /// The date when this token was created.
    let createdAt: Date

    /// The date when this token expires.
    var expirationDate: Date {
        createdAt.addingTimeInterval(expiresIn)
    }

    /// Whether the token has expired.
    var isExpired: Bool {
        Date() >= expirationDate
    }

    init(
        accessToken: String,
        refreshToken: String? = nil,
        tokenType: String = "Bearer",
        expiresIn: TimeInterval = 3600,
        scope: String? = nil,
        createdAt: Date = Date()
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.scope = scope
        self.createdAt = createdAt
    }
}
