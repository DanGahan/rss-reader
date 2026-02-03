//
//  OPMLServiceExportTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-03.
//

import CoreData
import Foundation
import Testing
@testable import RSSReader

@Suite("OPMLService Export Tests")
struct OPMLServiceExportTests {
    private let sut = OPMLService()

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
        let xml = try #require(String(
            data: data,
            encoding: .utf8
        ))
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
        let xml = try #require(String(
            data: data,
            encoding: .utf8
        ))
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
        let xml = try #require(String(
            data: data,
            encoding: .utf8
        ))
        #expect(xml.contains("Standalone Blog"))
    }

    @Test("exportOPML handles empty database")
    @MainActor
    func exportEmptyDB() throws {
        let context = CoreDataTestHelper.makeContext()
        let data = try sut.exportOPML(from: context)
        let xml = try #require(String(
            data: data,
            encoding: .utf8
        ))
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
        let xml = try #require(String(
            data: data,
            encoding: .utf8
        ))
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
        let doc = try OPMLService().parseOPML(data: exported)

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
}
