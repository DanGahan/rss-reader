//
//  FeedlyAPIServiceTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-28.
//

import Foundation
import Testing
@testable import RSSReader

@Suite("FeedlyAPIService Tests", .serialized)
struct FeedlyAPIServiceTests {

    // MARK: - Test Helpers

    private func makeSUT() -> (FeedlyAPIService, URLSession) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let service = FeedlyAPIService(
            clientId: "test-client-id",
            clientSecret: "test-client-secret",
            redirectURI: "feedlyreader://oauth/callback",
            session: session,
            rateLimiter: RateLimiter(requestsPerMinute: 1000)
        )
        service.setAuthToken("test-token")

        MockURLProtocol.reset()
        return (service, session)
    }

    private func makeResponse(
        statusCode: Int,
        url: String = "https://cloud.feedly.com/v3/test"
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    // MARK: - Authorization URL Tests

    @Test("Authorization URL contains correct parameters")
    func authorizationURL() {
        let (service, _) = makeSUT()
        let url = service.getAuthorizationURL()
        let urlString = url.absoluteString

        #expect(urlString.contains("cloud.feedly.com/v3/auth/auth"))
        #expect(urlString.contains("response_type=code"))
        #expect(urlString.contains("client_id=test-client-id"))
        #expect(urlString.contains(
            "redirect_uri=feedlyreader://oauth/callback"
        ))
        #expect(urlString.contains("scope="))
    }

    // MARK: - Token Exchange Tests

    @Test("Exchange code for token returns token")
    func exchangeCodeForToken() async throws {
        let (service, _) = makeSUT()

        let tokenJSON = """
        {
            "accessToken": "access-123",
            "refreshToken": "refresh-456",
            "tokenType": "Bearer",
            "expiresIn": 3600,
            "scope": "https://cloud.feedly.com/subscriptions",
            "createdAt": 1706400000
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(
                request.url?.path.contains("auth/token") == true
            )
            return (self.makeResponse(statusCode: 200), tokenJSON)
        }

        let token = try await service.exchangeCodeForToken(
            code: "auth-code"
        )
        #expect(token.accessToken == "access-123")
        #expect(token.refreshToken == "refresh-456")
        #expect(token.tokenType == "Bearer")
    }

    // MARK: - User Profile Tests

    @Test("Get current user returns user profile")
    func getCurrentUser() async throws {
        let (service, _) = makeSUT()

        let userJSON = """
        {
            "id": "user/123",
            "email": "test@example.com",
            "fullName": "Test User"
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "GET")
            #expect(
                request.url?.path.contains("profile") == true
            )
            #expect(
                request.value(forHTTPHeaderField: "Authorization")
                    == "Bearer test-token"
            )
            return (self.makeResponse(statusCode: 200), userJSON)
        }

        let user = try await service.getCurrentUser()
        #expect(user.id == "user/123")
        #expect(user.email == "test@example.com")
        #expect(user.fullName == "Test User")
    }

    // MARK: - Subscription Tests

    @Test("Get subscriptions returns subscription list")
    func getSubscriptions() async throws {
        let (service, _) = makeSUT()

        let subsJSON = """
        [
            {
                "id": "feed/1",
                "title": "Test Feed",
                "categories": [
                    {"id": "cat/1", "label": "Tech"}
                ]
            }
        ]
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            #expect(
                request.url?.path.contains("subscriptions") == true
            )
            return (self.makeResponse(statusCode: 200), subsJSON)
        }

        let subs = try await service.getSubscriptions()
        #expect(subs.count == 1)
        #expect(subs[0].title == "Test Feed")
        #expect(subs[0].categories.count == 1)
        #expect(subs[0].categories[0].label == "Tech")
    }

    // MARK: - Unread Counts Tests

    @Test("Get unread counts returns counts")
    func getUnreadCounts() async throws {
        let (service, _) = makeSUT()

        let countsJSON = """
        {
            "unreadcounts": [
                {"id": "feed/1", "count": 42},
                {"id": "feed/2", "count": 7}
            ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            #expect(
                request.url?.path.contains("markers/counts") == true
            )
            return (self.makeResponse(statusCode: 200), countsJSON)
        }

        let counts = try await service.getUnreadCounts()
        #expect(counts.count == 2)
        #expect(counts[0].id == "feed/1")
        #expect(counts[0].count == 42)
    }

    // MARK: - Stream Contents Tests

    @Test("Get stream contents with parameters")
    func getStreamContents() async throws {
        let (service, _) = makeSUT()

        let streamJSON = """
        {
            "id": "feed/1",
            "title": "Test Stream",
            "continuation": "next-page-token"
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let url = request.url!.absoluteString
            #expect(url.contains("streams/contents"))
            #expect(url.contains("streamId=feed/1"))
            #expect(url.contains("unreadOnly=true"))
            #expect(url.contains("count=50"))
            return (self.makeResponse(statusCode: 200), streamJSON)
        }

        let stream = try await service.getStreamContents(
            streamId: "feed/1",
            unreadOnly: true,
            newerThan: nil,
            continuation: nil
        )
        #expect(stream.id == "feed/1")
        #expect(stream.continuation == "next-page-token")
    }

    @Test("Get stream contents with continuation")
    func getStreamContentsWithContinuation() async throws {
        let (service, _) = makeSUT()

        let streamJSON = """
        {
            "id": "feed/1"
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let url = request.url!.absoluteString
            #expect(url.contains("continuation=abc123"))
            return (self.makeResponse(statusCode: 200), streamJSON)
        }

        _ = try await service.getStreamContents(
            streamId: "feed/1",
            unreadOnly: false,
            newerThan: nil,
            continuation: "abc123"
        )
    }

    // MARK: - Mark as Read Tests

    @Test("Mark articles as read sends correct request")
    func markArticlesAsRead() async throws {
        let (service, _) = makeSUT()

        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(
                request.url?.path.contains("markers") == true
            )

            if let body = request.httpBody {
                let json = try? JSONSerialization.jsonObject(
                    with: body
                ) as? [String: Any]
                #expect(json?["action"] as? String == "markAsRead")
                #expect(json?["type"] as? String == "entries")
                let ids = json?["entryIds"] as? [String]
                #expect(ids?.count == 2)
            }

            return (self.makeResponse(statusCode: 200), Data())
        }

        try await service.markArticlesAsRead(
            articleIds: ["article-1", "article-2"]
        )
    }

    @Test("Mark single article as read")
    func markSingleArticleAsRead() async throws {
        let (service, _) = makeSUT()

        MockURLProtocol.requestHandler = { request in
            if let body = request.httpBody {
                let json = try? JSONSerialization.jsonObject(
                    with: body
                ) as? [String: Any]
                let ids = json?["entryIds"] as? [String]
                #expect(ids == ["article-1"])
            }
            return (self.makeResponse(statusCode: 200), Data())
        }

        try await service.markArticleAsRead(articleId: "article-1")
    }

    // MARK: - Error Handling Tests

    @Test("401 response throws tokenExpired")
    func unauthorizedThrowsTokenExpired() async {
        let (service, _) = makeSUT()

        MockURLProtocol.requestHandler = { _ in
            (self.makeResponse(statusCode: 401), Data())
        }

        do {
            let _: FeedlyUser = try await service.getCurrentUser()
            Issue.record("Expected tokenExpired error")
        } catch let error as AppError {
            #expect(error == .tokenExpired)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("429 response throws rateLimitExceeded")
    func rateLimitThrowsRateLimitExceeded() async {
        let (service, _) = makeSUT()

        MockURLProtocol.requestHandler = { _ in
            (self.makeResponse(statusCode: 429), Data())
        }

        do {
            let _: FeedlyUser = try await service.getCurrentUser()
            Issue.record("Expected rateLimitExceeded error")
        } catch let error as AppError {
            #expect(error == .rateLimitExceeded)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("500 response throws apiError with status code")
    func serverErrorThrowsAPIError() async {
        let (service, _) = makeSUT()

        let errorBody = "Internal Server Error".data(using: .utf8)!
        MockURLProtocol.requestHandler = { _ in
            (self.makeResponse(statusCode: 500), errorBody)
        }

        do {
            let _: FeedlyUser = try await service.getCurrentUser()
            Issue.record("Expected apiError")
        } catch let error as AppError {
            if case .apiError(let code, let message) = error {
                #expect(code == 500)
                #expect(message == "Internal Server Error")
            } else {
                Issue.record("Expected apiError, got: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("No auth token throws tokenExpired")
    func noAuthTokenThrowsTokenExpired() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let service = FeedlyAPIService(
            clientId: "test",
            clientSecret: "test",
            session: session,
            rateLimiter: RateLimiter(requestsPerMinute: 1000)
        )
        // Deliberately NOT setting auth token

        MockURLProtocol.reset()
        MockURLProtocol.requestHandler = { _ in
            (self.makeResponse(statusCode: 200), Data())
        }

        do {
            let _: FeedlyUser = try await service.getCurrentUser()
            Issue.record("Expected tokenExpired error")
        } catch let error as AppError {
            #expect(error == .tokenExpired)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Request Format Tests

    @Test("Requests include correct headers")
    func requestHeaders() async throws {
        let (service, _) = makeSUT()

        let userJSON = """
        {"id": "user/1", "email": "test@test.com"}
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            #expect(
                request.value(forHTTPHeaderField: "Content-Type")
                    == "application/json"
            )
            #expect(
                request.value(forHTTPHeaderField: "Authorization")
                    == "Bearer test-token"
            )
            return (self.makeResponse(statusCode: 200), userJSON)
        }

        _ = try await service.getCurrentUser()
    }
}

// MARK: - RateLimiter Tests

@Suite("RateLimiter Tests")
struct RateLimiterTests {

    @Test("Allows requests within limit")
    func allowsRequestsWithinLimit() async throws {
        let limiter = RateLimiter(requestsPerMinute: 10)

        // Should complete without blocking
        for _ in 0..<5 {
            try await limiter.waitForSlot()
        }

        let remaining = await limiter.remainingRequests
        #expect(remaining == 5)
    }

    @Test("Reports correct remaining requests")
    func reportsRemainingRequests() async throws {
        let limiter = RateLimiter(requestsPerMinute: 3)

        try await limiter.waitForSlot()
        try await limiter.waitForSlot()

        let remaining = await limiter.remainingRequests
        #expect(remaining == 1)
    }
}
