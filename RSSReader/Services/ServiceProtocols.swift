//
//  ServiceProtocols.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Foundation

// MARK: - Feedly API Service Protocol

/// Protocol for interacting with the Feedly API.
protocol FeedlyAPIServiceProtocol {
    // Authentication
    func getAuthorizationURL() -> URL
    func exchangeCodeForToken(code: String) async throws -> AuthenticationToken
    func refreshToken(refreshToken: String) async throws -> AuthenticationToken

    // User Profile
    func getCurrentUser() async throws -> FeedlyUser

    // Subscriptions & Categories
    func getSubscriptions() async throws -> [Subscription]
    func getUnreadCounts() async throws -> [UnreadCount]

    // Articles
    func getStreamContents(
        streamId: String,
        unreadOnly: Bool,
        newerThan: Date?,
        continuation: String?
    ) async throws -> StreamContents

    // Mark as read
    func markArticleAsRead(articleId: String) async throws
    func markArticlesAsRead(articleIds: [String]) async throws
}

// MARK: - Authentication Service Protocol

/// Protocol for managing OAuth 2.0 authentication.
protocol AuthenticationServiceProtocol {
    var isAuthenticated: Bool { get }
    var currentUser: FeedlyUser? { get }

    func startOAuthFlow() async throws -> URL
    func handleCallback(url: URL) async throws -> FeedlyUser
    func logout() async throws
    func refreshTokenIfNeeded() async throws
}

// MARK: - Cache Service Protocol

/// Protocol for in-memory session caching.
protocol CacheServiceProtocol {
    func cacheArticles(_ articles: [Article])
    func getArticle(id: String) -> Article?
    func updateArticleReadStatus(id: String, isRead: Bool)
    func clearCache()
    func getCachedCategories() -> [Category]
    func cacheCategories(_ categories: [Category])
}

// MARK: - Keychain Service Protocol

/// Protocol for secure token storage.
protocol KeychainServiceProtocol {
    func save(token: AuthenticationToken) throws
    func retrieveToken() throws -> AuthenticationToken?
    func deleteToken() throws
}
