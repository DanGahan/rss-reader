//
//  OPMLServiceTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-30.
//

import CoreData
import Foundation
import Testing
@testable import RSSReader

@Suite("OPMLService Tests")
struct OPMLServiceTests {

    private let sut = OPMLService()

    // MARK: - Parse from Data

    @Test("parseOPML returns document from valid data")
    @MainActor
    func parseValidData() throws {
        let data = Self.sampleOPML.data(
            using: .utf8
        )!  // swiftlint:disable:this force_unwrapping
        let doc = try sut.parseOPML(data: data)
        #expect(doc.title == "Test Export")
        #expect(doc.outlines.count == 3)
    }

    @Test("parseOPML throws for invalid data")
    @MainActor
    func parseInvalidData() {
        let data = "garbage".data(
            using: .utf8
        )!  // swiftlint:disable:this force_unwrapping
        #expect(throws: RSSReaderError.self) {
            try sut.parseOPML(data: data)
        }
    }

    // MARK: - Import Creates Entities

    @Test("importFeeds creates folders")
    @MainActor
    func importCreatesFolders() throws {
        let context = CoreDataTestHelper.makeContext()
        let doc = try parseTestDoc()
        let result = try sut.importFeeds(
            from: doc, in: context
        )
        #expect(result.foldersCreated == 2)

        let request = CDFolder.fetchRequest()
        let folders = try context.fetch(request)
        #expect(folders.count == 2)
    }

    @Test("importFeeds creates feeds inside folders")
    @MainActor
    func importCreatesFeedsInFolders() throws {
        let context = CoreDataTestHelper.makeContext()
        let doc = try parseTestDoc()
        _ = try sut.importFeeds(
            from: doc, in: context
        )

        let request = CDFeed.fetchRequest()
        let feeds = try context.fetch(request)
        #expect(feeds.count == 4)
    }

    @Test("importFeeds sets feed folder relationship")
    @MainActor
    func feedFolderRelationship() throws {
        let context = CoreDataTestHelper.makeContext()
        let doc = try parseTestDoc()
        _ = try sut.importFeeds(
            from: doc, in: context
        )

        let request = CDFeed.fetchRequest()
        request.predicate = NSPredicate(
            format: "feedURL == %@",
            "https://feeds.arstechnica.com/feed"
        )
        let feeds = try context.fetch(request)
        #expect(feeds.first?.folder?.name == "Tech")
    }

    @Test("importFeeds handles unfiled feeds")
    @MainActor
    func unfiledFeeds() throws {
        let context = CoreDataTestHelper.makeContext()
        let doc = try parseTestDoc()
        _ = try sut.importFeeds(
            from: doc, in: context
        )

        let request = CDFeed.fetchRequest()
        request.predicate = NSPredicate(
            format: "folder == nil"
        )
        let unfiled = try context.fetch(request)
        #expect(unfiled.count == 1)
        #expect(
            unfiled.first?.title == "Unfiled Blog"
        )
    }

    @Test("importFeeds sets siteURL from htmlUrl")
    @MainActor
    func siteURLFromHtmlUrl() throws {
        let context = CoreDataTestHelper.makeContext()
        let doc = try parseTestDoc()
        _ = try sut.importFeeds(
            from: doc, in: context
        )

        let request = CDFeed.fetchRequest()
        request.predicate = NSPredicate(
            format: "feedURL == %@",
            "https://feeds.arstechnica.com/feed"
        )
        let feeds = try context.fetch(request)
        #expect(
            feeds.first?.siteURL
                == "https://arstechnica.com"
        )
    }

    @Test("importFeeds assigns folder sort order")
    @MainActor
    func folderSortOrder() throws {
        let context = CoreDataTestHelper.makeContext()
        let doc = try parseTestDoc()
        _ = try sut.importFeeds(
            from: doc, in: context
        )

        let request = CDFolder.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(
                key: "sortOrder", ascending: true
            )
        ]
        let folders = try context.fetch(request)
        #expect(folders[0].sortOrder == 0)
        #expect(folders[1].sortOrder == 1)
    }

    // MARK: - Duplicate Skipping

    @Test("importFeeds skips duplicate feedURLs")
    @MainActor
    func skipsDuplicates() throws {
        let context = CoreDataTestHelper.makeContext()
        let doc = try parseTestDoc()

        // Pre-create a feed with same URL
        _ = CDFeed.create(
            in: context,
            title: "Existing Ars",
            feedURL: "https://feeds.arstechnica.com/feed"
        )
        try context.save()

        let result = try sut.importFeeds(
            from: doc, in: context
        )
        #expect(result.feedsSkipped == 1)
        #expect(result.feedsCreated == 3)

        let request = CDFeed.fetchRequest()
        let allFeeds = try context.fetch(request)
        #expect(allFeeds.count == 4) // 1 pre + 3 new
    }

    @Test("importFeeds reports zero skipped when no dups")
    @MainActor
    func noDuplicates() throws {
        let context = CoreDataTestHelper.makeContext()
        let doc = try parseTestDoc()
        let result = try sut.importFeeds(
            from: doc, in: context
        )
        #expect(result.feedsSkipped == 0)
        #expect(result.feedsCreated == 4)
    }

    // MARK: - Import Result

    @Test("importFeeds returns correct result summary")
    @MainActor
    func importResultSummary() throws {
        let context = CoreDataTestHelper.makeContext()
        let doc = try parseTestDoc()
        let result = try sut.importFeeds(
            from: doc, in: context
        )
        #expect(result.foldersCreated == 2)
        #expect(result.feedsCreated == 4)
        #expect(result.feedsSkipped == 0)
    }

    // MARK: - Empty Document

    @Test("importFeeds handles empty document")
    @MainActor
    func emptyDocument() throws {
        let context = CoreDataTestHelper.makeContext()
        let doc = OPMLDocument(
            title: "Empty", outlines: []
        )
        let result = try sut.importFeeds(
            from: doc, in: context
        )
        #expect(result.foldersCreated == 0)
        #expect(result.feedsCreated == 0)
        #expect(result.feedsSkipped == 0)
    }

    // MARK: - Export

    @Test("exportOPML produces valid XML output")
    @MainActor
    func exportValidXML() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(
            in: context, name: "Tech", sortOrder: 0
        )
        let feed = CDFeed.create(
            in: context,
            title: "Ars Technica",
            feedURL: "https://feeds.arstechnica.com/feed"
        )
        feed.siteURL = "https://arstechnica.com"
        feed.folder = folder
        try context.save()

        let data = try sut.exportOPML(from: context)
        let xml = String(
            data: data,
            encoding: .utf8
        )!  // swiftlint:disable:this force_unwrapping
        #expect(xml.contains("<opml version=\"2.0\">"))
        #expect(xml.contains("Ars Technica"))
        #expect(
            xml.contains(
                "https://feeds.arstechnica.com/feed"
            )
        )
    }

    @Test("exportOPML preserves folder hierarchy")
    @MainActor
    func exportFolderHierarchy() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(
            in: context, name: "News", sortOrder: 0
        )
        let feed = CDFeed.create(
            in: context,
            title: "BBC",
            feedURL: "https://bbc.co.uk/feed"
        )
        feed.folder = folder
        try context.save()

        let data = try sut.exportOPML(from: context)
        let xml = String(
            data: data,
            encoding: .utf8
        )!  // swiftlint:disable:this force_unwrapping
        #expect(xml.contains("title=\"News\""))
        #expect(xml.contains("</outline>"))
    }

    @Test("exportOPML includes unfiled feeds")
    @MainActor
    func exportUnfiledFeeds() throws {
        let context = CoreDataTestHelper.makeContext()
        _ = CDFeed.create(
            in: context,
            title: "Standalone Blog",
            feedURL: "https://blog.example.com/feed"
        )
        try context.save()

        let data = try sut.exportOPML(from: context)
        let xml = String(
            data: data,
            encoding: .utf8
        )!  // swiftlint:disable:this force_unwrapping
        #expect(xml.contains("Standalone Blog"))
    }

    @Test("exportOPML handles empty database")
    @MainActor
    func exportEmptyDB() throws {
        let context = CoreDataTestHelper.makeContext()
        let data = try sut.exportOPML(from: context)
        let xml = String(
            data: data,
            encoding: .utf8
        )!  // swiftlint:disable:this force_unwrapping
        #expect(xml.contains("<opml"))
        #expect(xml.contains("</body>"))
    }

    @Test("exportOPML escapes XML special characters")
    @MainActor
    func exportXMLEscaping() throws {
        let context = CoreDataTestHelper.makeContext()
        _ = CDFeed.create(
            in: context,
            title: "Tom & Jerry's <Blog>",
            feedURL: "https://example.com/feed"
        )
        try context.save()

        let data = try sut.exportOPML(from: context)
        let xml = String(
            data: data,
            encoding: .utf8
        )!  // swiftlint:disable:this force_unwrapping
        #expect(xml.contains("&amp;"))
        #expect(xml.contains("&apos;"))
        #expect(xml.contains("&lt;"))
        #expect(xml.contains("&gt;"))
        #expect(!xml.contains("Tom & Jerry"))
    }

    @Test("exportOPML roundtrips with import")
    @MainActor
    func exportImportRoundtrip() throws {
        let context = CoreDataTestHelper.makeContext()
        let folder = CDFolder.create(
            in: context, name: "Tech", sortOrder: 0
        )
        let feed = CDFeed.create(
            in: context,
            title: "Test Feed",
            feedURL: "https://test.example.com/feed"
        )
        feed.siteURL = "https://test.example.com"
        feed.folder = folder
        try context.save()

        let exported = try sut.exportOPML(from: context)
        let doc = try sut.parseOPML(data: exported)

        #expect(doc.outlines.count >= 1)
        let techFolder = doc.outlines.first {
            $0.title == "Tech"
        }
        #expect(techFolder != nil)
        #expect(
            techFolder?.children.first?.title
                == "Test Feed"
        )
    }

    // MARK: - Helpers

    private func parseTestDoc() throws -> OPMLDocument {
        let data = Self.sampleOPML.data(
            using: .utf8
        )!  // swiftlint:disable:this force_unwrapping
        return try sut.parseOPML(data: data)
    }

    // MARK: - Fixtures

    private static let sampleOPML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <opml version="1.0">
    <head>
        <title>Test Export</title>
    </head>
    <body>
        <outline text="Tech" title="Tech">
            <outline type="rss" \
    text="Ars Technica" \
    title="Ars Technica" \
    xmlUrl="https://feeds.arstechnica.com/feed" \
    htmlUrl="https://arstechnica.com"/>
            <outline type="rss" \
    text="The Verge" \
    title="The Verge" \
    xmlUrl="https://theverge.com/rss/index.xml" \
    htmlUrl="https://www.theverge.com"/>
        </outline>
        <outline text="News" title="News">
            <outline type="rss" \
    text="BBC News" \
    title="BBC News" \
    xmlUrl="https://feeds.bbci.co.uk/news/rss.xml" \
    htmlUrl="https://www.bbc.co.uk/news"/>
        </outline>
        <outline type="rss" \
    text="Unfiled Blog" \
    title="Unfiled Blog" \
    xmlUrl="https://unfiled.example.com/feed" \
    htmlUrl="https://unfiled.example.com"/>
    </body>
    </opml>
    """
}
