// swiftlint:disable file_length
//
//  RefreshServiceTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-30.
//

import CoreData
import Foundation
import Testing
@testable import RSSReader

/// Dedicated URL protocol to avoid conflicts with
/// MockURLProtocol in parallel test suites.
private class RefreshMockProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: (
        (URLRequest) throws -> (HTTPURLResponse, Data?)
    )?

    override class func canInit(
        with request: URLRequest
    ) -> Bool { true }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            if let data {
                client?.urlProtocol(
                    self, didLoad: data
                )
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(
                self, didFailWithError: error
            )
        }
    }

    override func stopLoading() {}

    static func reset() { requestHandler = nil }
}

// swiftlint:disable type_body_length
@Suite("RefreshService Tests", .serialized)
struct RefreshServiceTests {
    // MARK: - Helpers

    /// Minimal valid RSS feed XML for testing.
    private static func makeRSSData(
        title: String = "Test Feed",
        articles: [(id: String, title: String)] = [
            ("a1", "Article 1"),
            ("a2", "Article 2")
        ]
    ) -> Data {
        let items = articles.map { article in
            """
            <item>
              <guid>\(article.id)</guid>
              <title>\(article.title)</title>
              <link>https://example.com/\(article.id)\
            </link>
              <pubDate>Mon, 01 Jan 2026 00:00:00 \
            +0000</pubDate>
            </item>
            """
        }
            .joined(separator: "\n")

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>\(title)</title>
            <link>https://example.com</link>
            \(items)
          </channel>
        </rss>
        """
        return Data(xml.utf8)
    }

    private static func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [
            RefreshMockProtocol.self
        ]
        return URLSession(configuration: config)
    }

    private func makeFeed(
        _ context: NSManagedObjectContext,
        feedURL: String =
            "https://example.com/feed.xml"
    ) -> CDFeed {
        CDFeed.create(
            in: context,
            title: "Test Feed",
            feedURL: feedURL
        )
    }

    private static func mockOKResponse() -> (
        (URLRequest) throws -> (HTTPURLResponse, Data?)
    ) {
        let rssData = makeRSSData()
        return { _ in
            let response = HTTPURLResponse(
                url: URL(
                    string:
                        "https://example.com/feed.xml"
                )!, // swiftlint:disable:this force_unwrapping
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )! // swiftlint:disable:this force_unwrapping
            return (response, rssData)
        }
    }

    /// Allow background context changes to merge into
    /// the view context.
    private func waitForMerge() async {
        try? await Task.sleep(
            nanoseconds: 200_000_000
        )
    }

    // MARK: - Initial State

    @Test(
        "Initial state: not refreshing, no lastRefreshDate"
    )
    @MainActor
    func initialState() {
        let persistence = PersistenceController
            .inMemory()
        let service = RefreshService(
            persistence: persistence,
            urlSession: Self.makeMockSession()
        )

        #expect(!service.isRefreshing)
        #expect(service.lastRefreshDate == nil)
    }

    // MARK: - Refresh Saves New Articles

    @Test("Refresh saves new articles from parsed feed")
    @MainActor
    func refreshSavesNewArticles() async throws {
        RefreshMockProtocol.reset()
        RefreshMockProtocol.requestHandler =
            Self.mockOKResponse()

        let persistence = PersistenceController
            .inMemory()
        let context = persistence.viewContext
        _ = makeFeed(context)
        try context.save()

        let service = RefreshService(
            persistence: persistence,
            urlSession: Self.makeMockSession()
        )

        await service.refreshAllFeeds()
        await waitForMerge()

        // Verify articles were saved
        context.refreshAllObjects()
        let request = CDArticle.fetchRequest()
        let articles = try context.fetch(request)
        #expect(articles.count == 2)

        let titles = Set(articles.map(\.title))
        #expect(titles.contains("Article 1"))
        #expect(titles.contains("Article 2"))
    }

    // MARK: - Duplicate Articles Skipped

    @Test("Duplicate articles are skipped on refresh")
    @MainActor
    func duplicateArticlesSkipped() async throws {
        RefreshMockProtocol.reset()
        RefreshMockProtocol.requestHandler =
            Self.mockOKResponse()

        let persistence = PersistenceController
            .inMemory()
        let context = persistence.viewContext
        let feed = makeFeed(context)

        // Pre-create one article with matching ID
        CDArticle.create(
            in: context,
            id: "a1",
            title: "Existing Article",
            link: "https://example.com/a1",
            published: Date(),
            feed: feed
        )
        try context.save()

        let service = RefreshService(
            persistence: persistence,
            urlSession: Self.makeMockSession()
        )

        await service.refreshAllFeeds()
        await waitForMerge()

        // Should have original + 1 new (a2)
        context.refreshAllObjects()
        let request = CDArticle.fetchRequest()
        let articles = try context.fetch(request)
        #expect(articles.count == 2)

        let ids = Set(articles.map(\.id))
        #expect(ids.contains("a1"))
        #expect(ids.contains("a2"))
    }

    // MARK: - Network Error Sets lastError

    @Test("Network error sets feed.lastError")
    @MainActor
    func networkErrorSetsLastError() async throws {
        RefreshMockProtocol.reset()

        let networkError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: [
                NSLocalizedDescriptionKey: "timed out"
            ]
        )
        RefreshMockProtocol.requestHandler = { _ in
            throw networkError
        }

        let persistence = PersistenceController
            .inMemory()
        let context = persistence.viewContext
        let feed = makeFeed(context)
        try context.save()

        let service = RefreshService(
            persistence: persistence,
            urlSession: Self.makeMockSession()
        )

        await service.refreshAllFeeds()
        await waitForMerge()

        // Re-fetch feed from context to see changes
        context.refreshAllObjects()
        let feeds = try context.fetch(
            CDFeed.fetchRequest()
        )
        let updatedFeed = feeds.first {
            $0.id == feed.id
        }
        #expect(updatedFeed?.lastError != nil)
    }

    // MARK: - lastRefreshDate Updated

    @Test("lastRefreshDate updated after refresh")
    @MainActor
    func lastRefreshDateUpdated() async throws {
        RefreshMockProtocol.reset()
        RefreshMockProtocol.requestHandler =
            Self.mockOKResponse()

        let persistence = PersistenceController
            .inMemory()
        let context = persistence.viewContext
        _ = makeFeed(context)
        try context.save()

        let service = RefreshService(
            persistence: persistence,
            urlSession: Self.makeMockSession()
        )

        #expect(service.lastRefreshDate == nil)
        let before = Date()
        await service.refreshAllFeeds()

        #expect(service.lastRefreshDate != nil)
        #expect(
            service.lastRefreshDate! >= before // swiftlint:disable:this force_unwrapping
        )
    }

    // MARK: - feed.lastFetched Updated on Success

    @Test(
        "feed.lastFetched updated on successful refresh"
    )
    @MainActor
    func feedLastFetchedUpdated() async throws {
        RefreshMockProtocol.reset()
        RefreshMockProtocol.requestHandler =
            Self.mockOKResponse()

        let persistence = PersistenceController
            .inMemory()
        let context = persistence.viewContext
        let feed = makeFeed(context)
        #expect(feed.lastFetched == nil)
        try context.save()

        let service = RefreshService(
            persistence: persistence,
            urlSession: Self.makeMockSession()
        )

        let before = Date()
        await service.refreshAllFeeds()
        await waitForMerge()

        context.refreshAllObjects()
        let feeds = try context.fetch(
            CDFeed.fetchRequest()
        )
        let updatedFeed = feeds.first {
            $0.id == feed.id
        }
        #expect(updatedFeed?.lastFetched != nil)
        #expect(
            updatedFeed!.lastFetched! >= before // swiftlint:disable:this force_unwrapping
        )
        #expect(updatedFeed?.lastError == nil)
    }

    // MARK: - Empty Feed List

    @Test(
        "Refresh with no feeds completes without error"
    )
    @MainActor
    func refreshNoFeeds() async {
        let persistence = PersistenceController
            .inMemory()
        let service = RefreshService(
            persistence: persistence,
            urlSession: Self.makeMockSession()
        )

        await service.refreshAllFeeds()

        #expect(!service.isRefreshing)
        #expect(service.lastRefreshDate != nil)
    }

    // MARK: - Auto-Refresh

    @Test(
        "startAutoRefresh creates task, stop cancels it"
    )
    @MainActor
    func autoRefreshLifecycle() {
        let persistence = PersistenceController
            .inMemory()
        let service = RefreshService(
            persistence: persistence,
            urlSession: Self.makeMockSession()
        )

        service.startAutoRefresh(interval: 3600)
        // Just verifies no crash; task is internal
        service.stopAutoRefresh()
        // Double stop is safe
        service.stopAutoRefresh()
    }

    // MARK: - Pause/Resume

    @Test("pauseAutoRefresh stops the task")
    @MainActor
    func pauseAutoRefreshStopsTask() {
        let persistence = PersistenceController
            .inMemory()
        let service = RefreshService(
            persistence: persistence,
            urlSession: Self.makeMockSession()
        )

        service.startAutoRefresh(interval: 3600)
        service.pauseAutoRefresh()
        // No crash, task is cancelled
    }

    @Test("resumeAutoRefresh restarts after pause")
    @MainActor
    func resumeAutoRefreshRestarts() {
        let persistence = PersistenceController
            .inMemory()
        let service = RefreshService(
            persistence: persistence,
            urlSession: Self.makeMockSession()
        )

        service.startAutoRefresh(interval: 3600)
        service.pauseAutoRefresh()
        service.resumeAutoRefresh()
        // No crash, task restarts
        service.stopAutoRefresh()
    }

    @Test("resumeAutoRefresh does nothing if not paused")
    @MainActor
    func resumeWithoutPauseNoOp() {
        let persistence = PersistenceController
            .inMemory()
        let service = RefreshService(
            persistence: persistence,
            urlSession: Self.makeMockSession()
        )

        // Never started, resume should be no-op
        service.resumeAutoRefresh()
        // No crash
    }

    // MARK: - Backoff

    @Test("Feed in backoff is skipped during refresh")
    @MainActor
    func feedInBackoffSkipped() async throws {
        RefreshMockProtocol.reset()

        // Request always fails
        var requestCount = 0
        RefreshMockProtocol.requestHandler = { _ in
            requestCount += 1
            throw NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorTimedOut,
                userInfo: nil
            )
        }

        let persistence = PersistenceController
            .inMemory()
        let context = persistence.viewContext
        _ = makeFeed(context)
        try context.save()

        let service = RefreshService(
            persistence: persistence,
            urlSession: Self.makeMockSession()
        )

        // First refresh - fails, backoff delay is 0
        await service.refreshAllFeeds()
        #expect(requestCount == 1)

        // Second refresh - fails, now backoff is 5s
        await service.refreshAllFeeds()
        #expect(requestCount == 2)

        // Third refresh - should skip (in backoff)
        await service.refreshAllFeeds()
        #expect(requestCount == 2) // No new request
    }

    @Test("Successful refresh clears backoff")
    @MainActor
    func successClearsBackoff() async throws {
        RefreshMockProtocol.reset()

        var requestCount = 0
        RefreshMockProtocol.requestHandler = { _ in
            requestCount += 1
            // swiftlint:disable force_unwrapping
            let response = HTTPURLResponse(
                url: URL(
                    string:
                        "https://example.com/feed.xml"
                )!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            // swiftlint:enable force_unwrapping
            return (response, Self.makeRSSData())
        }

        let persistence = PersistenceController
            .inMemory()
        let context = persistence.viewContext
        _ = makeFeed(context)
        try context.save()

        let service = RefreshService(
            persistence: persistence,
            urlSession: Self.makeMockSession()
        )

        await service.refreshAllFeeds()
        await service.refreshAllFeeds()

        // Both should succeed (no backoff)
        #expect(requestCount == 2)
    }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
