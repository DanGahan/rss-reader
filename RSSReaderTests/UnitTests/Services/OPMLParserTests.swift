//
//  OPMLParserTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-30.
//

import Foundation
import Testing
@testable import RSSReader

@Suite("OPMLParser Tests")
struct OPMLParserTests {
    // MARK: - Document-Level Parsing

    @Test("Parses document title from head")
    func documentTitle() throws {
        let doc = try parse(Self.feedlyExport)
        #expect(doc.title == "Feedly subscriptions")
    }

    @Test("Defaults title to Imported Feeds when missing")
    func defaultTitle() throws {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
        <body>
            <outline text="Feed" title="Feed" \
        type="rss" \
        xmlUrl="https://example.com/feed"/>
        </body>
        </opml>
        """
        let doc = try parse(opml)
        #expect(doc.title == "Imported Feeds")
    }

    // MARK: - Folder Parsing

    @Test("Parses folders from outline groups")
    func parseFolders() throws {
        let doc = try parse(Self.feedlyExport)
        let folders = doc.outlines.filter {
            $0.isFolder
        }
        #expect(folders.count == 2)
        #expect(folders[0].title == "Tech")
        #expect(folders[1].title == "News")
    }

    @Test("Folder isFolder is true, isFeed is false")
    func folderFlags() throws {
        let doc = try parse(Self.feedlyExport)
        let folder = doc.outlines.first {
            $0.title == "Tech"
        }
        #expect(folder?.isFolder == true)
        #expect(folder?.isFeed == false)
        #expect(folder?.xmlURL == nil)
    }

    @Test("Folder contains child feeds")
    func folderChildren() throws {
        let doc = try parse(Self.feedlyExport)
        let tech = doc.outlines.first {
            $0.title == "Tech"
        }
        #expect(tech?.children.count == 2)
        #expect(
            tech?.children[0].title == "Ars Technica"
        )
        #expect(
            tech?.children[1].title == "The Verge"
        )
    }

    // MARK: - Feed Parsing

    @Test("Parses feed title and URLs")
    func feedFields() throws {
        let doc = try parse(Self.feedlyExport)
        let tech = doc.outlines.first {
            $0.title == "Tech"
        }
        let ars = tech?.children.first
        #expect(ars?.title == "Ars Technica")
        #expect(
            ars?.xmlURL?.absoluteString
                == "https://feeds.arstechnica.com/feed"
        )
        #expect(
            ars?.htmlURL?.absoluteString
                == "https://arstechnica.com"
        )
    }

    @Test("Feed isFeed is true, isFolder is false")
    func feedFlags() throws {
        let doc = try parse(Self.feedlyExport)
        let tech = doc.outlines.first {
            $0.title == "Tech"
        }
        let feed = tech?.children.first
        #expect(feed?.isFeed == true)
        #expect(feed?.isFolder == false)
    }

    @Test("Feed children array is empty")
    func feedChildrenEmpty() throws {
        let doc = try parse(Self.feedlyExport)
        let tech = doc.outlines.first {
            $0.title == "Tech"
        }
        #expect(
            tech?.children.first?.children.isEmpty
                == true
        )
    }

    // MARK: - Unfiled Feeds

    @Test("Parses top-level unfiled feeds")
    func unfiledFeeds() throws {
        let doc = try parse(Self.feedlyExport)
        let unfiled = doc.outlines.filter {
            $0.isFeed
        }
        #expect(unfiled.count == 1)
        #expect(unfiled[0].title == "Unfiled Blog")
    }

    // MARK: - Text Attribute Fallback

    @Test("Falls back to text attribute when title missing")
    func textFallback() throws {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
        <body>
            <outline text="Text Only Feed" \
        type="rss" \
        xmlUrl="https://example.com/feed"/>
        </body>
        </opml>
        """
        let doc = try parse(opml)
        #expect(
            doc.outlines[0].title == "Text Only Feed"
        )
    }

    @Test("Defaults to Untitled when no title or text")
    func untitledFallback() throws {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
        <body>
            <outline type="rss" \
        xmlUrl="https://example.com/feed"/>
        </body>
        </opml>
        """
        let doc = try parse(opml)
        #expect(doc.outlines[0].title == "Untitled")
    }

    // MARK: - Edge Cases

    @Test("Empty body produces empty outlines")
    func emptyBody() throws {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
        <head><title>Empty</title></head>
        <body></body>
        </opml>
        """
        let doc = try parse(opml)
        #expect(doc.title == "Empty")
        #expect(doc.outlines.isEmpty)
    }

    @Test("Throws for malformed XML")
    func malformedXML() {
        let data = Data("not valid xml <><>".utf8)
        let parser = OPMLParser(data: data)
        #expect(throws: RSSReaderError.self) {
            try parser.parse()
        }
    }

    @Test("Folder with no children has isFolder false")
    func emptyFolderNotFolder() throws {
        let opml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="1.0">
        <body>
            <outline text="Empty Folder" \
        title="Empty Folder">
            </outline>
        </body>
        </opml>
        """
        let doc = try parse(opml)
        // No xmlURL and no children → not a folder
        #expect(doc.outlines[0].isFolder == false)
        #expect(doc.outlines[0].isFeed == false)
    }

    // MARK: - Helpers

    private func parse(
        _ xml: String
    ) throws -> OPMLDocument {
        // swiftlint:disable:next force_unwrapping
        let data = xml.data(using: .utf8)!
        let parser = OPMLParser(data: data)
        return try parser.parse()
    }

    // MARK: - Fixtures

    private static let feedlyExport = """
    <?xml version="1.0" encoding="UTF-8"?>
    <opml version="1.0">
    <head>
        <title>Feedly subscriptions</title>
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
    xmlUrl="https://www.theverge.com/rss/index.xml" \
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
