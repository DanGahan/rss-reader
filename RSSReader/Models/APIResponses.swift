//
//  APIResponses.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Foundation

/// Response from the Feedly stream contents endpoint.
struct StreamContents: Codable {
    let id: String
    let title: String?
    let direction: String?
    let continuation: String?
    let updated: Date?
    // Note: items will be parsed as Article objects separately
    // since Article has custom logic beyond Codable
}

/// Individual unread count for a stream/feed.
struct UnreadCount: Codable, Equatable {
    let id: String
    let count: Int
    let updated: Date?
}

/// Response from the Feedly unread counts endpoint.
struct UnreadCountsResponse: Codable {
    let unreadcounts: [UnreadCount]
    let updated: Date?
}

/// Session cache for in-memory storage of current state.
struct SessionCache {
    var categories: [Category] = []
    var articles: [String: Article] = [:]
    var lastRefresh: Date?
    var selectedCategoryId: String?
    var selectedArticleId: String?
}
