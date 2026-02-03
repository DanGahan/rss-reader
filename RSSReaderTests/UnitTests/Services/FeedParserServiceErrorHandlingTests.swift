//
//  FeedParserServiceErrorHandlingTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-03.
//

import Foundation
import Testing
@testable import RSSReader

@Suite("FeedParserService Error Handling Tests")
struct FeedParserServiceErrorHandlingTests {
    private let sut = FeedParserService()

    // MARK: - Error Handling

    @Test("Throws parsingFailed for malformed XML")
    func malformedXML() throws {
        let data = Data("not xml at all <><>".utf8)
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
        let data = Data(xml.utf8)
        let feed = try sut.parse(data: data)
        #expect(feed.title == "Empty Feed")
        #expect(feed.articles.isEmpty)
    }
}
