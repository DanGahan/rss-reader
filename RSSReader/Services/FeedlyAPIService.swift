//
//  FeedlyAPIService.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Foundation

/// Concrete implementation of the Feedly API v3 client.
final class FeedlyAPIService: FeedlyAPIServiceProtocol {
    // MARK: - Properties

    private let baseURL = "https://cloud.feedly.com/v3"
    private let clientId: String
    private let clientSecret: String
    private let redirectURI: String
    private var authToken: String?
    private let session: URLSession
    private let rateLimiter: RateLimiter
    private let decoder: JSONDecoder

    // MARK: - Initialization

    init(
        clientId: String,
        clientSecret: String,
        redirectURI: String = "feedlyreader://oauth/callback",
        session: URLSession? = nil,
        rateLimiter: RateLimiter? = nil
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.rateLimiter = rateLimiter ?? RateLimiter(
            requestsPerMinute: 60
        )

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.session = session ?? URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    // MARK: - Token Management

    /// Updates the authentication token used for API requests.
    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    // MARK: - Authentication

    // swiftlint:disable force_unwrapping
    func getAuthorizationURL() -> URL {
        var components = URLComponents(
            string: "\(baseURL)/auth/auth"
        )!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(
                name: "scope",
                value: "https://cloud.feedly.com/subscriptions"
            )
        ]
        return components.url!
    }
    // swiftlint:enable force_unwrapping

    func exchangeCodeForToken(
        code: String
    ) async throws -> AuthenticationToken {
        let body: [String: String] = [
            "code": code,
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]
        return try await performRequest(
            "/auth/token",
            method: "POST",
            body: try JSONSerialization.data(
                withJSONObject: body
            ),
            authenticated: false
        )
    }

    func refreshToken(
        refreshToken: String
    ) async throws -> AuthenticationToken {
        let body: [String: String] = [
            "refresh_token": refreshToken,
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "refresh_token"
        ]
        return try await performRequest(
            "/auth/token",
            method: "POST",
            body: try JSONSerialization.data(
                withJSONObject: body
            ),
            authenticated: false
        )
    }

    // MARK: - User Profile

    func getCurrentUser() async throws -> FeedlyUser {
        try await performRequest("/profile")
    }

    // MARK: - Subscriptions & Categories

    func getSubscriptions() async throws -> [Subscription] {
        try await performRequest("/subscriptions")
    }

    func getUnreadCounts() async throws -> [UnreadCount] {
        let response: UnreadCountsResponse = try await performRequest(
            "/markers/counts"
        )
        return response.unreadcounts
    }

    // MARK: - Articles

    func getStreamContents(
        streamId: String,
        unreadOnly: Bool,
        newerThan: Date?,
        continuation: String?
    ) async throws -> StreamContents {
        var queryItems = [
            URLQueryItem(name: "streamId", value: streamId),
            URLQueryItem(
                name: "unreadOnly",
                value: unreadOnly ? "true" : "false"
            ),
            URLQueryItem(name: "count", value: "50")
        ]

        if let newerThan {
            let timestamp = Int(
                newerThan.timeIntervalSince1970 * 1000
            )
            queryItems.append(
                URLQueryItem(
                    name: "newerThan",
                    value: String(timestamp)
                )
            )
        }

        if let continuation {
            queryItems.append(
                URLQueryItem(
                    name: "continuation",
                    value: continuation
                )
            )
        }

        return try await performRequest(
            "/streams/contents",
            queryItems: queryItems
        )
    }

    // MARK: - Mark as Read

    func markArticleAsRead(articleId: String) async throws {
        try await markArticlesAsRead(articleIds: [articleId])
    }

    func markArticlesAsRead(articleIds: [String]) async throws {
        let body: [String: Any] = [
            "action": "markAsRead",
            "type": "entries",
            "entryIds": articleIds
        ]
        let _: EmptyResponse = try await performRequest(
            "/markers",
            method: "POST",
            body: try JSONSerialization.data(
                withJSONObject: body
            )
        )
    }

    // MARK: - Private Request Handler

    private func performRequest<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: Data? = nil,
        queryItems: [URLQueryItem]? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        try await rateLimiter.waitForSlot()

        let request = try buildURLRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            queryItems: queryItems,
            authenticated: authenticated
        )

        let (data, response) = try await executeRequest(request)
        return try handleAPIResponse(data: data, response: response)
    }

    private func buildURLRequest(
        endpoint: String,
        method: String,
        body: Data?,
        queryItems: [URLQueryItem]?,
        authenticated: Bool
    ) throws -> URLRequest {
        guard var components = URLComponents(
            string: baseURL + endpoint
        ) else {
            throw AppError.invalidResponse
        }
        if let queryItems {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw AppError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        if authenticated {
            guard let token = authToken else {
                throw AppError.tokenExpired
            }
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        if let body {
            request.httpBody = body
        }

        return request
    }

    private func executeRequest(
        _ request: URLRequest
    ) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            if error.code == .notConnectedToInternet ||
                error.code == .networkConnectionLost {
                throw AppError.noInternet
            }
            throw AppError.networkError(error.localizedDescription)
        } catch {
            throw AppError.networkError(error.localizedDescription)
        }
    }

    private func handleAPIResponse<T: Decodable>(
        data: Data,
        response: URLResponse
    ) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            if data.isEmpty || T.self == EmptyResponse.self {
                // swiftlint:disable:next force_cast
                return EmptyResponse() as! T
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw AppError.invalidResponse
            }
        case 401:
            throw AppError.tokenExpired
        case 429:
            throw AppError.rateLimitExceeded
        default:
            let message = String(
                data: data,
                encoding: .utf8
            ) ?? "Unknown error"
            throw AppError.apiError(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }
    }
}

// MARK: - Empty Response Helper

/// Placeholder type for API calls that return no meaningful body.
struct EmptyResponse: Decodable {}
