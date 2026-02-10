//
//  HTMLAttributedStringConverterTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-10.
//

import AppKit
import Foundation
import Testing
@testable import RSSReader

@Suite("HTMLAttributedStringConverter Tests")
struct HTMLAttributedStringConverterTests {
    private let sut = HTMLAttributedStringConverter()

    // MARK: - Basic Conversion

    @Test("Converts plain text correctly")
    func convertsPlainText() {
        let html = "Hello, World!"
        let result = sut.convert(html)
        #expect(result.string.contains("Hello, World!"))
    }

    @Test("Returns empty attributed string for empty input")
    func handlesEmptyInput() {
        let result = sut.convert("")
        #expect(result.length == 0)
    }

    @Test("Preserves paragraph content")
    func preservesParagraphContent() {
        let html = "<p>First paragraph</p><p>Second paragraph</p>"
        let result = sut.convert(html)
        #expect(result.string.contains("First paragraph"))
        #expect(result.string.contains("Second paragraph"))
    }

    // MARK: - Bold Formatting

    @Test("Applies bold formatting to strong tags")
    func appliesBoldToStrong() {
        let html = "<p><strong>Bold text</strong></p>"
        let result = sut.convert(html)

        let hasBold = containsBoldFont(in: result)
        #expect(hasBold, "Expected bold font for <strong> tag")
    }

    @Test("Applies bold formatting to b tags")
    func appliesBoldToB() {
        let html = "<p><b>Bold text</b></p>"
        let result = sut.convert(html)

        let hasBold = containsBoldFont(in: result)
        #expect(hasBold, "Expected bold font for <b> tag")
    }

    // MARK: - Italic Formatting

    @Test("Applies italic formatting to em tags")
    func appliesItalicToEm() {
        let html = "<p><em>Italic text</em></p>"
        let result = sut.convert(html)

        let hasItalic = containsItalicFont(in: result)
        #expect(hasItalic, "Expected italic font for <em> tag")
    }

    @Test("Applies italic formatting to i tags")
    func appliesItalicToI() {
        let html = "<p><i>Italic text</i></p>"
        let result = sut.convert(html)

        let hasItalic = containsItalicFont(in: result)
        #expect(hasItalic, "Expected italic font for <i> tag")
    }

    // MARK: - Heading Formatting

    @Test("Applies larger font to h1 tags")
    func appliesLargerFontToH1() {
        let html = "<h1>Heading 1</h1><p>Body text</p>"
        let result = sut.convert(html)

        let maxFontSize = findMaxFontSize(in: result)
        #expect(maxFontSize >= 30, "Expected h1 to have font size >= 30pt")
    }

    @Test("Applies correct font size hierarchy to headings")
    func appliesHeadingHierarchy() {
        let html = "<h1>H1</h1><h2>H2</h2><h3>H3</h3>"
        let result = sut.convert(html)

        let fontSizes = findAllFontSizes(in: result)
        // h1 should be larger than h2, h2 larger than h3
        #expect(fontSizes.count >= 3, "Expected at least 3 different font sizes")
    }

    @Test("Applies bold to heading tags")
    func appliesBoldToHeadings() {
        let html = "<h2>Heading 2</h2>"
        let result = sut.convert(html)

        let hasBold = containsBoldFont(in: result)
        #expect(hasBold, "Expected bold font for heading")
    }

    // MARK: - Code Formatting

    @Test("Applies monospace font to code tags")
    func appliesMonospaceToCode() {
        let html = "<p>Use <code>let x = 1</code> to declare</p>"
        let result = sut.convert(html)

        let hasMonospace = containsMonospaceFont(in: result)
        #expect(hasMonospace, "Expected monospace font for <code> tag")
    }

    @Test("Applies monospace font to pre tags")
    func appliesMonospaceToPre() {
        let html = "<pre>function test() { return 42; }</pre>"
        let result = sut.convert(html)

        let hasMonospace = containsMonospaceFont(in: result)
        #expect(hasMonospace, "Expected monospace font for <pre> tag")
    }

    @Test("Applies background to code blocks")
    func appliesBackgroundToCode() {
        let html = "<pre><code>let x = 1</code></pre>"
        let result = sut.convert(html)

        let hasBackground = containsBackgroundColor(in: result)
        #expect(hasBackground, "Expected background color for code block")
    }

    // MARK: - List Formatting

    @Test("Preserves unordered list content")
    func preservesUnorderedListContent() {
        let html = "<ul><li>Item 1</li><li>Item 2</li></ul>"
        let result = sut.convert(html)
        #expect(result.string.contains("Item 1"))
        #expect(result.string.contains("Item 2"))
    }

    @Test("Preserves ordered list content")
    func preservesOrderedListContent() {
        let html = "<ol><li>First</li><li>Second</li></ol>"
        let result = sut.convert(html)
        #expect(result.string.contains("First"))
        #expect(result.string.contains("Second"))
    }

    // MARK: - Blockquote Formatting

    @Test("Preserves blockquote content")
    func preservesBlockquoteContent() {
        let html = "<blockquote>Quoted text here</blockquote>"
        let result = sut.convert(html)
        #expect(result.string.contains("Quoted text here"))
    }

    // MARK: - Link Formatting

    @Test("Preserves link content")
    func preservesLinkContent() {
        let html = "<p>Visit <a href=\"https://example.com\">Example</a></p>"
        let result = sut.convert(html)
        #expect(result.string.contains("Example"))
    }

    @Test("Applies link styling")
    func appliesLinkStyling() {
        let html = "<p><a href=\"https://example.com\">Link</a></p>"
        let result = sut.convert(html)

        let hasLink = containsLinkAttribute(in: result)
        #expect(hasLink, "Expected link attribute")
    }

    // MARK: - Whitespace Handling

    @Test("Adds leading newline for spacing after header")
    func addsLeadingNewline() {
        let html = "<p>Content starts here</p>"
        let result = sut.convert(html)

        let string = result.string
        #expect(string.hasPrefix("\n"), "Expected leading newline for header spacing")
        #expect(!string.hasPrefix("\n\n"), "Expected only one leading newline")
    }

    @Test("Normalizes excessive leading whitespace to single newline")
    func normalizesLeadingWhitespace() {
        let html = "   \n\n  <p>Content starts here</p>"
        let result = sut.convert(html)

        let string = result.string
        // Should have exactly one leading newline after normalization
        #expect(string.hasPrefix("\n"), "Expected leading newline")
        #expect(string.dropFirst().first != "\n", "Expected only one leading newline")
    }

    // MARK: - Nested Formatting

    @Test("Handles nested bold inside italic")
    func handlesNestedBoldInsideItalic() {
        let html = "<p><em>Italic <strong>bold italic</strong></em></p>"
        let result = sut.convert(html)

        #expect(result.string.contains("bold italic"))
        #expect(containsBoldFont(in: result))
        #expect(containsItalicFont(in: result))
    }

    @Test("Handles deeply nested content")
    func handlesDeeplyNestedContent() {
        let html = """
        <blockquote>
            <p>Quote with <strong>bold</strong> and <em>italic</em></p>
        </blockquote>
        """
        let result = sut.convert(html)

        #expect(result.string.contains("Quote with"))
        #expect(result.string.contains("bold"))
        #expect(result.string.contains("italic"))
    }

    // MARK: - Text Color

    @Test("Applies text color attribute")
    func appliesTextColor() {
        let html = "<p>Text content</p>"
        let result = sut.convert(html)

        let hasTextColor = containsForegroundColor(in: result)
        #expect(hasTextColor, "Expected foreground color attribute")
    }

    // MARK: - Test Helpers

    private func containsBoldFont(in attributedString: NSAttributedString) -> Bool {
        var found = false
        attributedString.enumerateAttribute(
            .font,
            in: NSRange(location: 0, length: attributedString.length),
            options: []
        ) { value, _, stop in
            if let font = value as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.bold) {
                    found = true
                    stop.pointee = true
                }
            }
        }
        return found
    }

    private func containsItalicFont(in attributedString: NSAttributedString) -> Bool {
        var found = false
        attributedString.enumerateAttribute(
            .font,
            in: NSRange(location: 0, length: attributedString.length),
            options: []
        ) { value, _, stop in
            if let font = value as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.italic) {
                    found = true
                    stop.pointee = true
                }
            }
        }
        return found
    }

    private func containsMonospaceFont(in attributedString: NSAttributedString) -> Bool {
        var found = false
        attributedString.enumerateAttribute(
            .font,
            in: NSRange(location: 0, length: attributedString.length),
            options: []
        ) { value, _, stop in
            if let font = value as? NSFont {
                let fontName = font.fontName.lowercased()
                if fontName.contains("menlo") ||
                   fontName.contains("monaco") ||
                   fontName.contains("courier") ||
                   font.fontDescriptor.symbolicTraits.contains(.monoSpace) {
                    found = true
                    stop.pointee = true
                }
            }
        }
        return found
    }

    private func containsBackgroundColor(in attributedString: NSAttributedString) -> Bool {
        var found = false
        attributedString.enumerateAttribute(
            .backgroundColor,
            in: NSRange(location: 0, length: attributedString.length),
            options: []
        ) { value, _, stop in
            if value != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    private func containsLinkAttribute(in attributedString: NSAttributedString) -> Bool {
        var found = false
        attributedString.enumerateAttribute(
            .link,
            in: NSRange(location: 0, length: attributedString.length),
            options: []
        ) { value, _, stop in
            if value != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    private func containsForegroundColor(in attributedString: NSAttributedString) -> Bool {
        var found = false
        attributedString.enumerateAttribute(
            .foregroundColor,
            in: NSRange(location: 0, length: attributedString.length),
            options: []
        ) { value, _, stop in
            if value != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    private func findMaxFontSize(in attributedString: NSAttributedString) -> CGFloat {
        var maxSize: CGFloat = 0
        attributedString.enumerateAttribute(
            .font,
            in: NSRange(location: 0, length: attributedString.length),
            options: []
        ) { value, _, _ in
            if let font = value as? NSFont {
                maxSize = max(maxSize, font.pointSize)
            }
        }
        return maxSize
    }

    private func findAllFontSizes(in attributedString: NSAttributedString) -> Set<CGFloat> {
        var sizes: Set<CGFloat> = []
        attributedString.enumerateAttribute(
            .font,
            in: NSRange(location: 0, length: attributedString.length),
            options: []
        ) { value, _, _ in
            if let font = value as? NSFont {
                sizes.insert(font.pointSize)
            }
        }
        return sizes
    }
}
