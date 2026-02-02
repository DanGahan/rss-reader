// swiftlint:disable file_length
//
//  RefreshService.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import Combine
import CoreData
import Foundation

/// Fetches and refreshes all subscribed feeds, deduplicating
/// articles by ID before persisting new entries.
///
/// Supports both manual refresh (via `.refresh` notification)
/// and automatic periodic refresh via `startAutoRefresh()`.
@MainActor
final class RefreshService: ObservableObject {

    /// Whether a refresh cycle is currently in progress.
    @Published var isRefreshing = false

    /// Date of the last successful refresh cycle completion.
    @Published var lastRefreshDate: Date?

    // MARK: - Dependencies

    private let persistence: PersistenceController
    private let parser: FeedParserService
    private let urlSession: URLSession

    // MARK: - Auto-Refresh

    private var autoRefreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    /// Maximum number of concurrent feed fetches.
    private let maxConcurrency = 5

    // MARK: - Init

    init(
        persistence: PersistenceController = .shared,
        parser: FeedParserService = FeedParserService(),
        urlSession: URLSession = .shared
    ) {
        self.persistence = persistence
        self.parser = parser
        self.urlSession = urlSession

        NotificationCenter.default
            .publisher(for: .refresh)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.refreshAllFeeds()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Manual Refresh

    /// Fetches all feeds concurrently (max 5 at a time),
    /// parses new articles, and persists them.
    func refreshAllFeeds() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let context = persistence.newBackgroundContext()

        let feedObjectIDs: [NSManagedObjectID] =
            await context.perform {
                let request = CDFeed.fetchRequest()
                let feeds = (
                    try? context.fetch(request)
                ) ?? []
                return feeds.map(\.objectID)
            }

        guard !feedObjectIDs.isEmpty else {
            lastRefreshDate = Date()
            return
        }

        await withTaskGroup(of: Void.self) { group in
            var running = 0
            var index = 0

            while index < feedObjectIDs.count {
                if running >= maxConcurrency {
                    await group.next()
                    running -= 1
                }

                let objectID = feedObjectIDs[index]
                index += 1
                running += 1

                group.addTask { [weak self] in
                    guard let self else { return }
                    await self.refreshFeed(
                        objectID: objectID
                    )
                }
            }
        }

        lastRefreshDate = Date()
    }

    // MARK: - Single Feed Refresh

    private func refreshFeed(
        objectID: NSManagedObjectID
    ) async {
        let context = persistence.newBackgroundContext()
        let session = urlSession
        let feedParser = parser

        // Step 1: Read feed URL on the context queue.
        let feedURL: String? = await context.perform {
            guard let feed = try? context
                .existingObject(with: objectID) as? CDFeed
            else { return nil }
            return feed.feedURL
        }

        guard let feedURLString = feedURL,
              let url = URL(string: feedURLString)
        else {
            await context.perform {
                guard let feed = try? context
                    .existingObject(
                        with: objectID
                    ) as? CDFeed
                else { return }
                feed.lastError =
                    RSSReaderError.invalidFeedURL
                        .errorDescription
                ErrorLogger.log(
                    RSSReaderError.invalidFeedURL,
                    context: "Feed: \(feed.title)"
                )
                try? context.save()
            }
            return
        }

        // Step 2: Fetch data via async URLSession (outside
        // the Core Data perform block).
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(
                from: url
            )
        } catch {
            let rssError = RSSReaderError.networkError(
                error.localizedDescription
            )
            await context.perform {
                guard let feed = try? context
                    .existingObject(
                        with: objectID
                    ) as? CDFeed
                else { return }
                feed.lastError = rssError.errorDescription
                ErrorLogger.log(
                    rssError,
                    context: "Feed: \(feed.title)"
                )
                try? context.save()
            }
            return
        }

        // Step 3: Validate HTTP status.
        if let httpResponse = response
            as? HTTPURLResponse,
            httpResponse.statusCode < 200
                || httpResponse.statusCode >= 300
        {
            let rssError = RSSReaderError.networkError(
                "HTTP \(httpResponse.statusCode)"
            )
            await context.perform {
                guard let feed = try? context
                    .existingObject(
                        with: objectID
                    ) as? CDFeed
                else { return }
                feed.lastError = rssError.errorDescription
                ErrorLogger.log(
                    rssError,
                    context: "Feed: \(feed.title)"
                )
                try? context.save()
            }
            return
        }

        // Step 4: Parse feed data (thread-safe value type).
        let parsedFeed: ParsedFeed
        do {
            parsedFeed = try feedParser.parse(data: data)
        } catch {
            let rssError = RSSReaderError.parsingFailed(
                error.localizedDescription
            )
            await context.perform {
                guard let feed = try? context
                    .existingObject(
                        with: objectID
                    ) as? CDFeed
                else { return }
                feed.lastError = rssError.errorDescription
                ErrorLogger.log(
                    rssError,
                    context: "Feed: \(feed.title)"
                )
                try? context.save()
            }
            return
        }

        // Step 5: Persist new articles on context queue.
        await context.perform {
            guard let feed = try? context
                .existingObject(with: objectID) as? CDFeed
            else { return }

            // Dedup by existing article IDs.
            let existingIDs: Set<String>
            if let articles = feed.articles
                as? Set<CDArticle>
            {
                existingIDs = Set(articles.map(\.id))
            } else {
                existingIDs = []
            }

            for parsed in parsedFeed.articles
            where !existingIDs.contains(parsed.id) {
                let article = CDArticle(
                    context: context
                )
                article.id = parsed.id
                article.title = parsed.title
                article.author = parsed.author
                article.published = parsed.published
                article.summary = parsed.summary
                article.content = parsed.content
                article.link =
                    parsed.link.absoluteString
                article.thumbnailURL =
                    parsed.thumbnailURL?.absoluteString
                article.isRead = false
                article.dateAdded = Date()
                article.feed = feed
            }

            feed.lastFetched = Date()
            feed.lastError = nil
            try? context.save()
        }
    }

    // MARK: - Auto-Refresh

    /// Starts a periodic refresh loop.
    ///
    /// - Parameter interval: Seconds between refreshes.
    ///   Defaults to 600 (10 minutes).
    func startAutoRefresh(interval: TimeInterval = 600) {
        stopAutoRefresh()
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: UInt64(
                        interval * 1_000_000_000
                    )
                )
                guard !Task.isCancelled else { break }
                await self?.refreshAllFeeds()
            }
        }
    }

    /// Stops the periodic refresh loop.
    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }
}
// swiftlint:enable file_length
