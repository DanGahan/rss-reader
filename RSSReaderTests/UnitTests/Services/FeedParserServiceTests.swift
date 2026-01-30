// swiftlint:disable file_length
//
//  FeedParserServiceTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-30.
//

import Foundation
import Testing
@testable import RSSReader

// swiftlint:disable:next type_body_length
@Suite("FeedParserService Tests")
struct FeedParserServiceTests {

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
        let data = xml.data(using: .utf8)!  // swiftlint:disable:this force_unwrapping
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
        let data = xml.data(using: .utf8)!  // swiftlint:disable:this force_unwrapping
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
        let data = xml.data(using: .utf8)!  // swiftlint:disable:this force_unwrapping
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
        let data = xml.data(using: .utf8)!  // swiftlint:disable:this force_unwrapping
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
        let data = xml.data(using: .utf8)!  // swiftlint:disable:this force_unwrapping
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
        let data = xml.data(using: .utf8)!  // swiftlint:disable:this force_unwrapping
        let feed = try sut.parse(data: data)
        #expect(
            feed.articles[0].title == "Spaced Title"
        )
    }

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
                <link rel="self" \
        href="https://example.com/self"/>
                <link rel="alternate" \
        href="https://example.com/alt"/>
            </entry>
        </feed>
        """
        let data = xml.data(using: .utf8)!  // swiftlint:disable:this force_unwrapping
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
        let data = xml.data(using: .utf8)!  // swiftlint:disable:this force_unwrapping
        let feed = try sut.parse(data: data)
        #expect(feed.articles.count == 1)
        #expect(
            feed.articles[0].title == "Valid Entry"
        )
    }

    // MARK: - JSON Feed Parsing

    @Test("Parses JSON Feed title")
    func jsonTitle() throws {
        let data = Self.makeJSONFeedData()
        let feed = try sut.parse(data: data)
        #expect(feed.title == "Test JSON Feed")
    }

    @Test("Parses JSON Feed home page URL")
    func jsonSiteURL() throws {
        let data = Self.makeJSONFeedData()
        let feed = try sut.parse(data: data)
        #expect(
            feed.siteURL
                == URL(string: "https://json.example.com")
        )
    }

    @Test("Parses JSON Feed description")
    func jsonDescription() throws {
        let data = Self.makeJSONFeedData()
        let feed = try sut.parse(data: data)
        #expect(
            feed.feedDescription == "A JSON test feed"
        )
    }

    @Test("Parses JSON Feed items")
    func jsonItems() throws {
        let data = Self.makeJSONFeedData()
        let feed = try sut.parse(data: data)
        #expect(feed.articles.count == 1)
    }

    @Test("Parses JSON Feed item fields")
    func jsonItemFields() throws {
        let data = Self.makeJSONFeedData()
        let feed = try sut.parse(data: data)
        let article = feed.articles[0]

        #expect(article.title == "JSON Article")
        #expect(article.author == "Charlie")
        #expect(article.id == "json-1")
        #expect(
            article.link
                == URL(
                    string: "https://json.example.com/1"
                )
        )
        #expect(
            article.content == "<p>JSON content</p>"
        )
        #expect(
            article.summary == "JSON summary"
        )
    }

    @Test("JSON Feed uses contentText when no contentHtml")
    func jsonContentTextFallback() throws {
        let json = """
        {
            "version": "https://jsonfeed.org/version/1.1",
            "title": "Test",
            "items": [{
                "id": "1",
                "title": "Plain",
                "url": "https://example.com/1",
                "content_text": "Plain text content"
            }]
        }
        """
        let data = json.data(using: .utf8)!  // swiftlint:disable:this force_unwrapping
        let feed = try sut.parse(data: data)
        #expect(
            feed.articles[0].content
                == "Plain text content"
        )
    }

    @Test("JSON Feed prefers contentHtml over contentText")
    func jsonContentHtmlPreferred() throws {
        let json = """
        {
            "version": "https://jsonfeed.org/version/1.1",
            "title": "Test",
            "items": [{
                "id": "1",
                "title": "Both",
                "url": "https://example.com/1",
                "content_html": "<p>HTML</p>",
                "content_text": "Text"
            }]
        }
        """
        let data = json.data(using: .utf8)!  // swiftlint:disable:this force_unwrapping
        let feed = try sut.parse(data: data)
        #expect(
            feed.articles[0].content == "<p>HTML</p>"
        )
    }

    @Test("JSON Feed item image as thumbnailURL")
    func jsonItemImage() throws {
        let json = """
        {
            "version": "https://jsonfeed.org/version/1.1",
            "title": "Test",
            "items": [{
                "id": "1",
                "title": "With Image",
                "url": "https://example.com/1",
                "image": "https://example.com/img.jpg"
            }]
        }
        """
        let data = json.data(using: .utf8)!  // swiftlint:disable:this force_unwrapping
        let feed = try sut.parse(data: data)
        #expect(
            feed.articles[0].thumbnailURL
                == URL(
                    string: "https://example.com/img.jpg"
                )
        )
    }

    // MARK: - Error Handling

    @Test("Throws parsingFailed for malformed XML")
    func malformedXML() throws {
        let data = "not xml at all <><>".data(
            using: .utf8
        )!  // swiftlint:disable:this force_unwrapping
        #expect(throws: RSSReaderError.self) {
            try sut.parse(data: data)
        }
    }

    @Test("Empty feed produces zero articles")
    func emptyFeed() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
            <title>Empty Feed</title>
        </channel>
        </rss>
        """
        let data = xml.data(using: .utf8)!  // swiftlint:disable:this force_unwrapping
        let feed = try sut.parse(data: data)
        #expect(feed.title == "Empty Feed")
        #expect(feed.articles.isEmpty)
    }

    // MARK: - RSS Dublin Core Author Fallback

    @Test("RSS falls back to dc:creator for author")
    func rssDublinCoreAuthor() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" \
        xmlns:dc="http://purl.org/dc/elements/1.1/">
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
        let data = xml.data(using: .utf8)!  // swiftlint:disable:this force_unwrapping
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
                <pubDate>\
        Mon, 01 Jan 2024 12:00:00 +0000\
        </pubDate>
                <description>\
        Summary of first article\
        </description>
            </item>
            <item>
                <guid>guid-2</guid>
                <title>Second Article</title>
                <link>https://example.com/2</link>
                <author>Bob</author>
                <pubDate>\
        Tue, 02 Jan 2024 12:00:00 +0000\
        </pubDate>
                <description>\
        Summary of second article\
        </description>
            </item>
        </channel>
        </rss>
        """
        // swiftlint:disable:next force_unwrapping
        return xml.data(using: .utf8)!
    }

    private static func makeAtomData() -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
            <title>Test Atom Feed</title>
            <subtitle>An Atom test feed</subtitle>
            <link rel="alternate" \
        href="https://atom.example.com"/>
            <link rel="self" \
        href="https://atom.example.com/feed.xml"/>
            <entry>
                <title>Atom Entry</title>
                <id>urn:uuid:atom-1</id>
                <link rel="alternate" \
        href="https://atom.example.com/1"/>
                <author><name>Bob</name></author>
                <published>\
        2024-01-01T12:00:00Z\
        </published>
                <summary>Atom summary</summary>
                <content type="html">\
        &lt;p&gt;Atom content&lt;/p&gt;\
        </content>
            </entry>
        </feed>
        """
        // swiftlint:disable:next force_unwrapping
        return xml.data(using: .utf8)!
    }

    private static func makeJSONFeedData() -> Data {
        let json = """
        {
            "version": "https://jsonfeed.org/version/1.1",
            "title": "Test JSON Feed",
            "home_page_url": "https://json.example.com",
            "description": "A JSON test feed",
            "items": [
                {
                    "id": "json-1",
                    "title": "JSON Article",
                    "url": "https://json.example.com/1",
                    "content_html": "<p>JSON content</p>",
                    "summary": "JSON summary",
                    "author": {
                        "name": "Charlie"
                    },
                    "date_published": \
        "2024-01-01T12:00:00+00:00"
                }
            ]
        }
        """
        // swiftlint:disable:next force_unwrapping
        return json.data(using: .utf8)!
    }
}
// swiftlint:enable file_length
