//
//  OPMLService.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import CoreData
import Foundation

/// Handles OPML file import: parses the XML, then
/// creates Core Data folder and feed entities while
/// skipping duplicates and preserving hierarchy.
struct OPMLService {

    /// Result of an OPML import operation.
    struct ImportResult: Equatable {
        let foldersCreated: Int
        let feedsCreated: Int
        let feedsSkipped: Int
    }

    /// Parses an OPML file at `url` and returns the
    /// parsed document.
    ///
    /// - Throws: `RSSReaderError.parsingFailed` if the
    ///   file cannot be read or parsed.
    func parseOPML(
        from url: URL
    ) throws -> OPMLDocument {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw RSSReaderError.parsingFailed(
                "Cannot read OPML file: "
                    + error.localizedDescription
            )
        }
        let parser = OPMLParser(data: data)
        return try parser.parse()
    }

    /// Parses raw OPML data and returns the document.
    ///
    /// - Throws: `RSSReaderError.parsingFailed`
    func parseOPML(
        data: Data
    ) throws -> OPMLDocument {
        let parser = OPMLParser(data: data)
        return try parser.parse()
    }

    /// Creates Core Data entities from a parsed OPML
    /// document, skipping feeds whose `feedURL`
    /// already exists.
    ///
    /// - Returns: An `ImportResult` summarising the
    ///   operation.
    @discardableResult
    func importFeeds(
        from document: OPMLDocument,
        in context: NSManagedObjectContext
    ) throws -> ImportResult {
        let existingURLs = try fetchExistingFeedURLs(
            in: context
        )

        var result = ImportCounter()

        for outline in document.outlines {
            if outline.isFolder {
                importFolder(
                    outline,
                    sortOrder: Int32(result.folderCount),
                    existingURLs: existingURLs,
                    counter: &result,
                    in: context
                )
            } else if outline.isFeed {
                importFeed(
                    outline,
                    folder: nil,
                    existingURLs: existingURLs,
                    counter: &result,
                    in: context
                )
            }
        }

        try context.save()

        return ImportResult(
            foldersCreated: result.folderCount,
            feedsCreated: result.feedsCreated,
            feedsSkipped: result.feedsSkipped
        )
    }
}

// MARK: - Private Helpers

private extension OPMLService {

    struct ImportCounter {
        var folderCount = 0
        var feedsCreated = 0
        var feedsSkipped = 0
    }

    func fetchExistingFeedURLs(
        in context: NSManagedObjectContext
    ) throws -> Set<String> {
        let request = CDFeed.fetchRequest()
        request.propertiesToFetch = ["feedURL"]
        let feeds = try context.fetch(request)
        return Set(
            feeds.compactMap { $0.feedURL }
        )
    }

    func importFolder(
        _ outline: OPMLOutline,
        sortOrder: Int32,
        existingURLs: Set<String>,
        counter: inout ImportCounter,
        in context: NSManagedObjectContext
    ) {
        let folder = CDFolder.create(
            in: context,
            name: outline.title,
            sortOrder: sortOrder
        )
        counter.folderCount += 1

        for child in outline.children {
            if child.isFeed {
                importFeed(
                    child,
                    folder: folder,
                    existingURLs: existingURLs,
                    counter: &counter,
                    in: context
                )
            }
            // Nested sub-folders are flattened — OPML
            // spec allows nesting, but our UI only
            // supports one level.
        }
    }

    func importFeed(
        _ outline: OPMLOutline,
        folder: CDFolder?,
        existingURLs: Set<String>,
        counter: inout ImportCounter,
        in context: NSManagedObjectContext
    ) {
        guard let xmlURL = outline.xmlURL else {
            return
        }

        let feedURLString = xmlURL.absoluteString

        guard !existingURLs.contains(feedURLString)
        else {
            counter.feedsSkipped += 1
            return
        }

        let feed = CDFeed.create(
            in: context,
            title: outline.title,
            feedURL: feedURLString
        )

        if let htmlURL = outline.htmlURL {
            feed.siteURL = htmlURL.absoluteString
        }

        feed.folder = folder
        counter.feedsCreated += 1
    }
}
