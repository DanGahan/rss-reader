//
//  OPMLService.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import CoreData
import Foundation

/// Handles OPML file import and export: parses XML
/// for import and generates OPML 2.0 XML for export.
/// Creates Core Data folder and feed entities while
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

    // MARK: - Export

    /// Generates OPML 2.0 XML data from all folders
    /// and feeds in the given context.
    func exportOPML(
        from context: NSManagedObjectContext
    ) throws -> Data {
        let folders = try fetchSortedFolders(in: context)
        let unfiled = try fetchUnfiledFeeds(in: context)

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
        <head>
            <title>RSS Reader Export</title>
        </head>
        <body>\n
        """

        for folder in folders {
            xml += outlineXML(for: folder)
        }

        for feed in unfiled {
            xml += feedOutlineXML(for: feed)
        }

        xml += "</body>\n</opml>\n"

        guard let data = xml.data(using: .utf8) else {
            throw RSSReaderError.parsingFailed(
                "Failed to encode OPML as UTF-8"
            )
        }
        return data
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

        // Nested sub-folders are flattened — OPML
        // spec allows nesting, but our UI only
        // supports one level.
        for child in outline.children where child.isFeed {
            importFeed(
                child,
                folder: folder,
                existingURLs: existingURLs,
                counter: &counter,
                in: context
            )
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

    // MARK: - Export Helpers

    func fetchSortedFolders(
        in context: NSManagedObjectContext
    ) throws -> [CDFolder] {
        let request = CDFolder.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(
                key: "sortOrder", ascending: true
            ),
            NSSortDescriptor(
                key: "name", ascending: true
            )
        ]
        return try context.fetch(request)
    }

    func fetchUnfiledFeeds(
        in context: NSManagedObjectContext
    ) throws -> [CDFeed] {
        let request = CDFeed.fetchRequest()
        request.predicate = NSPredicate(
            format: "folder == nil"
        )
        request.sortDescriptors = [
            NSSortDescriptor(
                key: "title", ascending: true
            )
        ]
        return try context.fetch(request)
    }

    func outlineXML(for folder: CDFolder) -> String {
        let name = escapeXML(folder.name)
        var xml = "    <outline text=\"\(name)\""
        xml += " title=\"\(name)\">\n"
        for feed in folder.sortedFeeds {
            xml += "    " + feedOutlineXML(for: feed)
        }
        xml += "    </outline>\n"
        return xml
    }

    func feedOutlineXML(for feed: CDFeed) -> String {
        let title = escapeXML(feed.title)
        let feedURL = escapeXML(feed.feedURL)
        var xml = "    <outline type=\"rss\""
        xml += " text=\"\(title)\""
        xml += " title=\"\(title)\""
        xml += " xmlUrl=\"\(feedURL)\""
        if let siteURL = feed.siteURL {
            xml += " htmlUrl=\"\(escapeXML(siteURL))\""
        }
        xml += "/>\n"
        return xml
    }

    func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
