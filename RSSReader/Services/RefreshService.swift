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
    private let errorHandler: FeedErrorHandler

    // MARK: - Auto-Refresh

    private var autoRefreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    /// Maximum number of concurrent feed fetches.
    private let maxConcurrency = 5

    /// Remaining time when auto-refresh was paused.
    private var remainingInterval: TimeInterval?

    /// The configured auto-refresh interval.
    private var currentInterval: TimeInterval = 600

    /// Tracks the next allowed refresh time per feed UUID.
    private var feedBackoffUntil: [UUID: Date] = [:]

    // MARK: - Init

    init(
        persistence: PersistenceController = .shared,
        parser: FeedParserService = FeedParserService(),
        urlSession: URLSession = .shared,
        errorHandler: FeedErrorHandler? = nil
    ) {
        self.persistence = persistence
        self.parser = parser
        self.urlSession = urlSession
        self.errorHandler = errorHandler ?? FeedErrorHandler()

        NotificationCenter.default
            .publisher(for: .refresh)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.refreshAllFeeds()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .refreshIntervalChanged)
            .sink { [weak self] notification in
                guard let self else { return }
                let newInterval = notification.userInfo?["interval"]
                    as? TimeInterval ?? 600
                Task { @MainActor in
                    self.startAutoRefresh(interval: newInterval)
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

        let feedData: [(NSManagedObjectID, UUID)] =
            await context.perform {
                let request = CDFeed.fetchRequest()
                let feeds = (
                    try? context.fetch(request)
                ) ?? []
                return feeds.map { ($0.objectID, $0.id) }
            }

        guard !feedData.isEmpty else {
            lastRefreshDate = Date()
            return
        }

        await withTaskGroup(of: Void.self) { group in
            var running = 0
            var index = 0

            while index < feedData.count {
                if running >= maxConcurrency {
                    await group.next()
                    running -= 1
                }

                let (objectID, feedId) = feedData[index]
                index += 1

                // Skip feeds in backoff period
                if isInBackoff(feedId: feedId) {
                    continue
                }

                running += 1

                group.addTask { [weak self] in
                    guard let self else { return }
                    await self.refreshFeed(
                        objectID: objectID,
                        feedId: feedId
                    )
                }
            }
        }

        lastRefreshDate = Date()
    }

    // MARK: - Single Feed Refresh

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func refreshFeed(
        objectID: NSManagedObjectID,
        feedId: UUID
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
            let rssError = RSSReaderError.invalidFeedURL
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
            let delay = errorHandler.nextRetryDelay(for: feedId)
            setBackoff(feedId: feedId, delay: delay)
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
            let delay = errorHandler.nextRetryDelay(for: feedId)
            setBackoff(feedId: feedId, delay: delay)
            return
        }

        // Step 3: Validate HTTP status.
        if let httpResponse = response
            as? HTTPURLResponse,
            httpResponse.statusCode < 200
                || httpResponse.statusCode >= 300 {
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
            let delay = errorHandler.nextRetryDelay(for: feedId)
            setBackoff(feedId: feedId, delay: delay)
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
            let delay = errorHandler.nextRetryDelay(for: feedId)
            setBackoff(feedId: feedId, delay: delay)
            return
        }

        // Step 5: Persist new articles on context queue.
        // Uses explicit fetch-based de-duplication for CloudKit compatibility.
        await context.perform {
            guard let feed = try? context
                .existingObject(with: objectID) as? CDFeed
            else { return }

            for parsed in parsedFeed.articles {
                // Use createIfNotExists for CloudKit-compatible de-duplication.
                // This performs an explicit fetch request instead of relying on
                // unique constraints (which CloudKit doesn't support).
                let (article, isNew) = CDArticle.createIfNotExists(
                    in: context,
                    id: parsed.id,
                    title: parsed.title,
                    link: parsed.link.absoluteString,
                    published: parsed.published,
                    feed: feed
                )

                // Only set additional properties for new articles
                if isNew {
                    article.author = parsed.author
                    article.summary = parsed.summary
                    article.content = parsed.content
                    article.thumbnailURL =
                        parsed.thumbnailURL?.absoluteString
                }
            }

            feed.lastFetched = Date()
            feed.lastError = nil
            try? context.save()
        }

        // Clear backoff and reset retry count on success
        errorHandler.resetRetryCount(for: feedId)
        clearBackoff(feedId: feedId)
    }

    // MARK: - Auto-Refresh

    /// Starts a periodic refresh loop.
    ///
    /// - Parameter interval: Seconds between refreshes.
    ///   Defaults to 600 (10 minutes).
    func startAutoRefresh(interval: TimeInterval = 600) {
        stopAutoRefresh()
        currentInterval = interval
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

    /// Pauses auto-refresh, preserving the state for resume.
    func pauseAutoRefresh() {
        guard autoRefreshTask != nil else { return }
        remainingInterval = currentInterval
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    /// Resumes auto-refresh if it was paused.
    func resumeAutoRefresh() {
        guard remainingInterval != nil else { return }
        startAutoRefresh(interval: currentInterval)
        remainingInterval = nil
    }

    // MARK: - Backoff Helpers

    /// Returns true if the feed is currently in backoff period.
    private func isInBackoff(feedId: UUID) -> Bool {
        guard let until = feedBackoffUntil[feedId] else {
            return false
        }
        return Date() < until
    }

    /// Clears backoff for a feed after successful refresh.
    private func clearBackoff(feedId: UUID) {
        feedBackoffUntil[feedId] = nil
    }

    /// Sets backoff for a feed based on delay from error handler.
    private func setBackoff(feedId: UUID, delay: TimeInterval) {
        feedBackoffUntil[feedId] = Date()
            .addingTimeInterval(delay)
    }
}
