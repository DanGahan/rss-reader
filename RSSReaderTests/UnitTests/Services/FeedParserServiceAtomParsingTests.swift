//
//  FeedParserServiceAtomParsingTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-03.
//

import Foundation
import Testing
@testable import RSSReader

@Suite("FeedParserService Atom Parsing Tests")
struct FeedParserServiceAtomParsingTests {
    private let sut = FeedParserService()

    // MARK: - Atom Parsing

    @Test("Parses Atom feed title")
    func atomTitle() throws {
        let data = Self.makeAtomData()
        let feed = try sut.parse(data: data)
        #expect(feed.title == "Test Atom Feed")
    }

    @Test("Parses Atom feed site URL from alternate link")
    func atomSiteURL() throws {
        let data = Self.makeAtomData()
        let feed = try sut.parse(data: data)
        #expect(
            feed.siteURL
                == URL(string: "https://atom.example.com")
        )
    }

    @Test("Parses Atom feed subtitle as description")
    func atomDescription() throws {
        let data = Self.makeAtomData()
        let feed = try sut.parse(data: data)
        #expect(
            feed.feedDescription == "An Atom test feed"
        )
    }

    @Test("Parses Atom entries")
    func atomEntries() throws {
        let data = Self.makeAtomData()
        let feed = try sut.parse(data: data)
        #expect(feed.articles.count == 1)
    }

    @Test("Parses Atom entry fields")
    func atomEntryFields() throws {
        let data = Self.makeAtomData()
        let feed = try sut.parse(data: data)
        let article = feed.articles[0]

        #expect(article.title == "Atom Entry")
        #expect(article.author == "Bob")
        #expect(article.id == "urn:uuid:atom-1")
        #expect(
            article.link
                == URL(
                    string: "https://atom.example.com/1"
                )
        )
        #expect(
            article.summary == "Atom summary"
        )
        #expect(
            article.content == "<p>Atom content</p>"
        )
    }

    @Test("Atom entry uses alternate link over self link")
    func atomAlternateLink() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
            <title>Test</title>
            <entry>
                <title>Entry</title>
                <id>urn:test</id>
                <link rel="self" href="https://example.com/self"/>
                <link rel="alternate" href="https://example.com/alt"/>
            </entry>
        </feed>
        """
        let data = Data(xml.utf8)
        let feed = try sut.parse(data: data)
        #expect(
            feed.articles[0].link
                == URL(string: "https://example.com/alt")
        )
    }

    @Test("Atom skips entries without title and link")
    func atomSkipsInvalidEntries() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
            <title>Test</title>
            <entry>
                <id>urn:empty</id>
                <summary>No title or link</summary>
            </entry>
            <entry>
                <title>Valid Entry</title>
                <id>urn:valid</id>
                <link href="https://example.com/valid"/>
            </entry>
        </feed>
        """
        let data = Data(xml.utf8)
        let feed = try sut.parse(data: data)
        #expect(feed.articles.count == 1)
        #expect(
            feed.articles[0].title == "Valid Entry"
        )
    }

    // MARK: - Test Fixture Builders

    private static func makeAtomData() -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
            <title>Test Atom Feed</title>
            <subtitle>An Atom test feed</subtitle>
            <link rel="alternate" href="https://atom.example.com"/>
            <link rel="self" href="https://atom.example.com/feed.xml"/>
            <entry>
                <title>Atom Entry</title>
                <id>urn:uuid:atom-1</id>
                <link rel="alternate" href="https://atom.example.com/1"/>
                <author><name>Bob</name></author>
                <published>2024-01-01T12:00:00Z</published>
                <summary>Atom summary</summary>
                <content type="html">&lt;p&gt;Atom content&lt;/p&gt;</content>
            </entry>
        </feed>
        """
        return Data(xml.utf8)
    }
}
