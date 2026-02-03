//
//  FeedParserServiceRSSParsingTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-03.
//

import Foundation
import Testing
@testable import RSSReader

@Suite("FeedParserService RSS Parsing Tests")
struct FeedParserServiceRSSParsingTests {
    private let sut = FeedParserService()

    // MARK: - RSS 2.0 Parsing

    @Test("Parses RSS 2.0 feed title")
    func rssTitle() throws {
        let data = Self.makeRSSData()
        let feed = try sut.parse(data: data)
        #expect(feed.title == "Test RSS Feed")
    }

    @Test("Parses RSS 2.0 feed site URL")
    func rssSiteURL() throws {
        let data = Self.makeRSSData()
        let feed = try sut.parse(data: data)
        #expect(
            feed.siteURL == URL(string: "https://example.com")
        )
    }

    @Test("Parses RSS 2.0 feed description")
    func rssDescription() throws {
        let data = Self.makeRSSData()
        let feed = try sut.parse(data: data)
        #expect(
            feed.feedDescription == "A test RSS feed"
        )
    }

    @Test("Parses RSS 2.0 articles")
    func rssArticles() throws {
        let data = Self.makeRSSData()
        let feed = try sut.parse(data: data)
        #expect(feed.articles.count == 2)
    }

    @Test("Parses RSS 2.0 article fields")
    func rssArticleFields() throws {
        let data = Self.makeRSSData()
        let feed = try sut.parse(data: data)
        let article = feed.articles[0]

        #expect(article.title == "First Article")
        #expect(article.author == "Alice")
        #expect(
            article.link
                == URL(string: "https://example.com/1")
        )
        #expect(
            article.summary == "Summary of first article"
        )
        #expect(article.id == "guid-1")
    }

    @Test("RSS article uses guid as ID")
    func rssArticleGuidId() throws {
        let data = Self.makeRSSData()
        let feed = try sut.parse(data: data)
        #expect(feed.articles[0].id == "guid-1")
    }

    @Test("RSS article falls back to link as ID")
    func rssArticleLinkFallbackId() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <title>Test</title>
            <item>
                <title>No GUID</title>
                <link>https://example.com/no-guid</link>
            </item>
        </channel>
        </rss>
        """
        let data = try #require(xml.data(using: .utf8))
        let feed = try sut.parse(data: data)
        #expect(
            feed.articles[0].id
                == "https://example.com/no-guid"
        )
    }

    @Test("RSS article with only title is valid")
    func rssArticleTitleOnly() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <title>Test</title>
            <item>
                <title>Title Only</title>
            </item>
        </channel>
        </rss>
        """
        let data = try #require(xml.data(using: .utf8))
        let feed = try sut.parse(data: data)
        #expect(feed.articles.count == 1)
        #expect(feed.articles[0].title == "Title Only")
    }

    @Test("RSS article with only link is valid")
    func rssArticleLinkOnly() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <title>Test</title>
            <item>
                <link>https://example.com/link-only</link>
            </item>
        </channel>
        </rss>
        """
        let data = try #require(xml.data(using: .utf8))
        let feed = try sut.parse(data: data)
        #expect(feed.articles.count == 1)
        #expect(
            feed.articles[0].title == "Untitled"
        )
    }

    @Test("RSS skips articles without title and link")
    func rssSkipsInvalidArticles() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <title>Test</title>
            <item>
                <description>Only description</description>
            </item>
            <item>
                <title>Valid</title>
                <link>https://example.com/valid</link>
            </item>
        </channel>
        </rss>
        """
        let data = try #require(xml.data(using: .utf8))
        let feed = try sut.parse(data: data)
        #expect(feed.articles.count == 1)
        #expect(feed.articles[0].title == "Valid")
    }

    @Test("RSS feed with no title defaults to Untitled Feed")
    func rssFeedUntitled() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <item>
                <title>Article</title>
                <link>https://example.com/1</link>
            </item>
        </channel>
        </rss>
        """
        let data = try #require(xml.data(using: .utf8))
        let feed = try sut.parse(data: data)
        #expect(feed.title == "Untitled Feed")
    }

    @Test("RSS article title is trimmed")
    func rssArticleTitleTrimmed() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <title>Test</title>
            <item>
                <title>  Spaced Title  </title>
                <link>https://example.com/1</link>
            </item>
        </channel>
        </rss>
        """
        let data = try #require(xml.data(using: .utf8))
        let feed = try sut.parse(data: data)
        #expect(
            feed.articles[0].title == "Spaced Title"
        )
    }

    // MARK: - RSS Dublin Core Author Fallback

    @Test("RSS falls back to dc:creator for author")
    func rssDublinCoreAuthor() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
        <channel>
            <title>Test</title>
            <item>
                <title>DC Article</title>
                <link>https://example.com/dc</link>
                <dc:creator>DC Author</dc:creator>
            </item>
        </channel>
        </rss>
        """
        let data = try #require(xml.data(using: .utf8))
        let feed = try sut.parse(data: data)
        #expect(
            feed.articles[0].author == "DC Author"
        )
    }

    // MARK: - Test Fixture Builders

    private static func makeRSSData() -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <title>Test RSS Feed</title>
            <link>https://example.com</link>
            <description>A test RSS feed</description>
            <item>
                <guid>guid-1</guid>
                <title>First Article</title>
                <link>https://example.com/1</link>
                <author>Alice</author>
                <pubDate>Mon, 01 Jan 2024 12:00:00 +0000</pubDate>
                <description>Summary of first article</description>
            </item>
            <item>
                <guid>guid-2</guid>
                <title>Second Article</title>
                <link>https://example.com/2</link>
                <author>Bob</author>
                <pubDate>Tue, 02 Jan 2024 12:00:00 +0000</pubDate>
                <description>Summary of second article</description>
            </item>
        </channel>
        </rss>
        """
        return Data(xml.utf8)
    }
}
