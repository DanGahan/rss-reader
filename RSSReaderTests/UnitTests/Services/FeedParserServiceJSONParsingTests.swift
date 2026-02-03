//
//  FeedParserServiceJSONParsingTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-03.
//

import Foundation
import Testing
@testable import RSSReader

@Suite("FeedParserService JSON Parsing Tests")
struct FeedParserServiceJSONParsingTests {
    private let sut = FeedParserService()

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
        let data = Data(json.utf8)
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
        let data = Data(json.utf8)
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
        let data = Data(json.utf8)
        let feed = try sut.parse(data: data)
        #expect(
            feed.articles[0].thumbnailURL
                == URL(
                    string: "https://example.com/img.jpg"
                )
        )
    }

    // MARK: - Test Fixture Builders

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
                    "date_published": "2024-01-01T12:00:00+00:00"
                }
            ]
        }
        """
        return Data(json.utf8)
    }
}
