//
//  OPMLIntegrationTests.swift
//  RSSReaderTests
//
//  Integration tests for OPML import/export pipeline.
//

import CoreData
import XCTest
@testable import RSSReader

final class OPMLIntegrationTests: XCTestCase {
    var persistence: PersistenceController!
    var context: NSManagedObjectContext!
    var opmlService: OPMLService!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController.inMemory()
        context = persistence.viewContext
        opmlService = OPMLService()
    }

    override func tearDown() {
        opmlService = nil
        context = nil
        persistence = nil
        super.tearDown()
    }

    // MARK: - Import -> Create -> Verify

    // swiftlint:disable line_length
    func testImportOPMLCreatesFeedsAndFolders() throws {
        let opmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
        <head><title>Test Export</title></head>
        <body>
            <outline text="Tech" title="Tech">
                <outline type="rss" text="Ars Technica" xmlUrl="https://feeds.arstechnica.com/arstechnica/index"/>
                <outline type="rss" text="The Verge" xmlUrl="https://www.theverge.com/rss/index.xml"/>
            </outline>
            <outline type="rss" text="BBC News" xmlUrl="http://feeds.bbci.co.uk/news/rss.xml"/>
        </body>
        </opml>
        """
    // swiftlint:enable line_length

        guard let data = opmlContent.data(using: .utf8) else {
            XCTFail("Failed to create OPML data")
            return
        }

        // Import OPML
        let document = try opmlService.parseOPML(from: data)

        // Verify parsed structure
        XCTAssertEqual(document.folders.count, 1)
        XCTAssertEqual(document.folders.first?.name, "Tech")
        XCTAssertEqual(document.folders.first?.feeds.count, 2)
        XCTAssertEqual(document.unfiledFeeds.count, 1)
        XCTAssertTrue(document.unfiledFeeds.first?.title.contains("BBC") ?? false)

        // Create in Core Data
        let folder = CDFolder(context: context)
        folder.id = UUID()
        folder.name = document.folders.first?.name ?? ""
        folder.sortOrder = 0
        folder.dateCreated = Date()

        for opmlFeed in document.folders.first?.feeds ?? [] {
            let feed = CDFeed(context: context)
            feed.id = UUID()
            feed.title = opmlFeed.title
            feed.feedURL = opmlFeed.feedURL
            feed.siteURL = opmlFeed.siteURL
            feed.dateAdded = Date()
            feed.folder = folder
        }

        for opmlFeed in document.unfiledFeeds {
            let feed = CDFeed(context: context)
            feed.id = UUID()
            feed.title = opmlFeed.title
            feed.feedURL = opmlFeed.feedURL
            feed.siteURL = opmlFeed.siteURL
            feed.dateAdded = Date()
        }

        try context.save()

        // Verify Core Data
        let folderRequest = CDFolder.fetchRequest()
        let folders = try context.fetch(folderRequest)
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first?.name, "Tech")

        let feedRequest = CDFeed.fetchRequest()
        let feeds = try context.fetch(feedRequest)
        XCTAssertEqual(feeds.count, 3)

        let techFeeds = feeds.filter { $0.folder != nil }
        XCTAssertEqual(techFeeds.count, 2)

        let unfiledFeeds = feeds.filter { $0.folder == nil }
        XCTAssertEqual(unfiledFeeds.count, 1)
    }

    // MARK: - Export -> Re-Import Roundtrip

    func testExportAndReimportRoundtrip() throws {
        // Create test data
        let folder = CDFolder(context: context)
        folder.id = UUID()
        folder.name = "News"
        folder.sortOrder = 0
        folder.dateCreated = Date()

        let feed1 = CDFeed(context: context)
        feed1.id = UUID()
        feed1.title = "Test Feed 1"
        feed1.feedURL = "https://example.com/feed1.xml"
        feed1.siteURL = "https://example.com"
        feed1.dateAdded = Date()
        feed1.folder = folder

        let feed2 = CDFeed(context: context)
        feed2.id = UUID()
        feed2.title = "Unfiled Feed"
        feed2.feedURL = "https://example.org/feed.xml"
        feed2.dateAdded = Date()

        try context.save()

        // Export
        let exportedData = try opmlService.exportOPML(from: context)
        XCTAssertFalse(exportedData.isEmpty)

        // Verify export contains expected content
        let exportedString = String(data: exportedData, encoding: .utf8)!
        XCTAssertTrue(exportedString.contains("Syndicate Export"))
        XCTAssertTrue(exportedString.contains("Test Feed 1"))
        XCTAssertTrue(exportedString.contains("Unfiled Feed"))
        XCTAssertTrue(exportedString.contains("News"))

        // Re-import into fresh context
        let persistence2 = PersistenceController.inMemory()
        let context2 = persistence2.viewContext

        let document = try opmlService.parseOPML(from: exportedData)

        // Verify re-imported structure matches
        XCTAssertEqual(document.folders.count, 1)
        XCTAssertEqual(document.folders.first?.name, "News")
        XCTAssertEqual(document.folders.first?.feeds.count, 1)
        XCTAssertEqual(document.unfiledFeeds.count, 1)

        // Create in new context
        for opmlFolder in document.folders {
            let newFolder = CDFolder(context: context2)
            newFolder.id = UUID()
            newFolder.name = opmlFolder.name
            newFolder.sortOrder = 0
            newFolder.dateCreated = Date()

            for opmlFeed in opmlFolder.feeds {
                let newFeed = CDFeed(context: context2)
                newFeed.id = UUID()
                newFeed.title = opmlFeed.title
                newFeed.feedURL = opmlFeed.feedURL
                newFeed.dateAdded = Date()
                newFeed.folder = newFolder
            }
        }

        for opmlFeed in document.unfiledFeeds {
            let newFeed = CDFeed(context: context2)
            newFeed.id = UUID()
            newFeed.title = opmlFeed.title
            newFeed.feedURL = opmlFeed.feedURL
            newFeed.dateAdded = Date()
        }

        try context2.save()

        // Verify final state
        let feedRequest = CDFeed.fetchRequest()
        let feeds = try context2.fetch(feedRequest)
        XCTAssertEqual(feeds.count, 2)
    }

    // MARK: - Malformed OPML

    func testMalformedOPMLThrowsError() {
        let malformedContent = """
        <?xml version="1.0"?>
        <opml version="2.0">
        <head><title>Bad OPML</title></head>
        <!-- Missing body tag -->
        </opml>
        """

        guard let data = malformedContent.data(using: .utf8) else {
            XCTFail("Failed to create data")
            return
        }

        XCTAssertThrowsError(try opmlService.parseOPML(from: data))
    }
}
