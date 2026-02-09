//
//  StringExtensionsTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-09.
//

import Foundation
import Testing
@testable import RSSReader

@Suite("String Extensions Tests")
struct StringExtensionsTests {
    // MARK: - normalizingWhitespace

    @Test("normalizingWhitespace removes newlines")
    func normalizingWhitespaceRemovesNewlines() {
        let input = "John\nDoe"
        let result = input.normalizingWhitespace()
        #expect(result == "John Doe")
    }

    @Test("normalizingWhitespace removes carriage returns")
    func normalizingWhitespaceRemovesCarriageReturns() {
        let input = "John\rDoe"
        let result = input.normalizingWhitespace()
        #expect(result == "John Doe")
    }

    @Test("normalizingWhitespace removes CRLF")
    func normalizingWhitespaceRemovesCRLF() {
        let input = "John\r\nDoe"
        let result = input.normalizingWhitespace()
        #expect(result == "John Doe")
    }

    @Test("normalizingWhitespace removes tabs")
    func normalizingWhitespaceRemovesTabs() {
        let input = "John\tDoe"
        let result = input.normalizingWhitespace()
        #expect(result == "John Doe")
    }

    @Test("normalizingWhitespace collapses multiple spaces")
    func normalizingWhitespaceCollapsesSpaces() {
        let input = "John    Doe"
        let result = input.normalizingWhitespace()
        #expect(result == "John Doe")
    }

    @Test("normalizingWhitespace trims leading and trailing")
    func normalizingWhitespaceTrims() {
        let input = "  John Doe  "
        let result = input.normalizingWhitespace()
        #expect(result == "John Doe")
    }

    @Test("normalizingWhitespace handles complex case")
    func normalizingWhitespaceHandlesComplexCase() {
        // Simulates Ars Technica author format with icon/newline
        let input = "\n    Kyle Orland\n"
        let result = input.normalizingWhitespace()
        #expect(result == "Kyle Orland")
    }

    @Test("normalizingWhitespace preserves simple strings")
    func normalizingWhitespacePreservesSimpleStrings() {
        let input = "John Doe"
        let result = input.normalizingWhitespace()
        #expect(result == "John Doe")
    }

    // MARK: - decodingHTMLEntities

    @Test("decodingHTMLEntities decodes apostrophe")
    func decodingHTMLEntitiesDecodesApostrophe() {
        let input = "It&#8217;s a test"
        let result = input.decodingHTMLEntities()
        #expect(result.contains("'"))
    }

    @Test("decodingHTMLEntities decodes ampersand")
    func decodingHTMLEntitiesDecodesAmpersand() {
        let input = "Tom &amp; Jerry"
        let result = input.decodingHTMLEntities()
        #expect(result == "Tom & Jerry")
    }

    @Test("decodingHTMLEntities preserves plain strings")
    func decodingHTMLEntitiesPreservesPlainStrings() {
        let input = "Hello World"
        let result = input.decodingHTMLEntities()
        #expect(result == "Hello World")
    }
}
