//
//  HTMLAttributedStringConverter.swift
//  RSSReader
//
//  Created on 2026-02-10.
//

import AppKit
import Foundation

/// Converts sanitized HTML to NSAttributedString with rich text formatting.
///
/// Applies custom styling for paragraphs, headings, lists, blockquotes,
/// and code blocks. Uses semantic colors for dark mode support.
struct HTMLAttributedStringConverter {
    // MARK: - Style Constants

    /// Base font size for body text (matches reader mode).
    static let baseFontSize: CGFloat = 16

    /// Paragraph spacing after each paragraph.
    static let paragraphSpacing: CGFloat = 12

    /// Spacing after headings.
    static let headingSpacing: CGFloat = 16

    /// Spacing between list items.
    static let listItemSpacing: CGFloat = 4

    /// Spacing before and after lists.
    static let listSpacing: CGFloat = 8

    /// Left indent for blockquotes.
    static let blockquoteIndent: CGFloat = 20

    /// Font sizes for headings.
    static let headingFontSizes: [Int: CGFloat] = [
        1: 32,
        2: 24,
        3: 20,
        4: 18,
        5: 18,
        6: 18
    ]

    // MARK: - Public API

    /// Converts HTML string to attributed string with formatting.
    ///
    /// - Parameter html: Sanitized HTML string to convert.
    /// - Returns: Formatted NSAttributedString ready for display.
    func convert(_ html: String) -> NSAttributedString {
        guard !html.isEmpty else {
            return NSAttributedString()
        }

        // Wrap in HTML document with base styling
        let wrappedHTML = wrapHTML(html)

        guard let data = wrappedHTML.data(using: .utf8),
              let attributedString = try? NSMutableAttributedString(
                  data: data,
                  options: [
                      .documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue
                  ],
                  documentAttributes: nil
              )
        else {
            // Fallback to plain text if HTML parsing fails
            return NSAttributedString(
                string: html.strippingHTMLTags(),
                attributes: [
                    .font: NSFont.systemFont(ofSize: Self.baseFontSize),
                    .foregroundColor: NSColor.textColor
                ]
            )
        }

        // Post-process the attributed string
        applyCustomStyling(to: attributedString)

        // Normalize whitespace: trim then add leading newline for spacing after header
        trimLeadingWhitespace(from: attributedString)
        addLeadingNewline(to: attributedString)

        return attributedString
    }

    // MARK: - Private Helpers

    /// Wraps HTML in a document with base styling.
    private func wrapHTML(_ html: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <style>\(Self.cssStyles)</style>
        </head>
        <body>\(html)</body>
        </html>
        """
    }

    /// CSS styles for the HTML document.
    private static var cssStyles: String {
        """
        body { font-family: -apple-system, sans-serif; font-size: \(baseFontSize)px; line-height: 1.5; }
        p { margin-bottom: \(paragraphSpacing)px; }
        h1, h2, h3, h4, h5, h6 { font-weight: bold; margin-top: \(headingSpacing * 1.5)px; \
        margin-bottom: \(headingSpacing / 2)px; }
        h1 { font-size: \(headingFontSizes[1] ?? 32)px; }
        h2 { font-size: \(headingFontSizes[2] ?? 24)px; }
        h3 { font-size: \(headingFontSizes[3] ?? 20)px; }
        h4, h5, h6 { font-size: \(headingFontSizes[4] ?? 18)px; }
        blockquote { margin-left: \(blockquoteIndent)px; padding-left: 10px; border-left: 3px solid #ccc; }
        pre, code { font-family: Menlo, Monaco, monospace; font-size: \(baseFontSize - 1)px; }
        pre { padding: 10px; border-radius: 4px; overflow-x: auto; }
        ul, ol { margin-top: \(listSpacing)px; margin-bottom: \(listSpacing * 2)px; }
        li { margin-bottom: \(listItemSpacing)px; }
        """
    }

    /// Applies custom styling post-processing to the attributed string.
    private func applyCustomStyling(to attributedString: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: attributedString.length)

        // Apply text color for dark mode support
        attributedString.addAttribute(
            .foregroundColor,
            value: NSColor.textColor,
            range: fullRange
        )

        // Process code blocks for background color
        applyCodeBlockStyling(to: attributedString)

        // Ensure links are styled appropriately
        applyLinkStyling(to: attributedString)
    }

    /// Applies styling to code blocks.
    private func applyCodeBlockStyling(to attributedString: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: attributedString.length)

        attributedString.enumerateAttribute(
            .font,
            in: fullRange,
            options: []
        ) { value, range, _ in
            guard let font = value as? NSFont else { return }

            // Detect monospace fonts (code blocks)
            if font.fontName.lowercased().contains("menlo") ||
               font.fontName.lowercased().contains("monaco") ||
               font.fontName.lowercased().contains("courier") ||
               font.isFixedPitch {
                // Apply subtle background for code
                let bgColor = NSColor.textBackgroundColor.blended(
                    withFraction: 0.05,
                    of: NSColor.labelColor
                ) ?? NSColor.textBackgroundColor

                attributedString.addAttribute(
                    .backgroundColor,
                    value: bgColor,
                    range: range
                )
            }
        }
    }

    /// Applies styling to links.
    private func applyLinkStyling(to attributedString: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: attributedString.length)

        attributedString.enumerateAttribute(
            .link,
            in: fullRange,
            options: []
        ) { value, range, _ in
            guard value != nil else { return }

            attributedString.addAttributes([
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: range)
        }
    }

    /// Trims leading whitespace from the attributed string.
    private func trimLeadingWhitespace(from attributedString: NSMutableAttributedString) {
        let string = attributedString.string
        var startIndex = string.startIndex

        // Find first non-whitespace character
        while startIndex < string.endIndex,
              string[startIndex].isWhitespace || string[startIndex].isNewline {
            startIndex = string.index(after: startIndex)
        }

        if startIndex > string.startIndex {
            let trimLength = string.distance(from: string.startIndex, to: startIndex)
            attributedString.deleteCharacters(
                in: NSRange(location: 0, length: trimLength)
            )
        }
    }

    /// Adds a leading newline for spacing after the article header.
    private func addLeadingNewline(to attributedString: NSMutableAttributedString) {
        guard attributedString.length > 0 else { return }

        let newline = NSAttributedString(
            string: "\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.baseFontSize),
                .foregroundColor: NSColor.textColor
            ]
        )
        attributedString.insert(newline, at: 0)
    }
}

// MARK: - String Extension

private extension String {
    /// Simple HTML tag stripping for fallback.
    func strippingHTMLTags() -> String {
        self.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - NSFont Extension

private extension NSFont {
    /// Checks if the font is fixed-pitch (monospace).
    var isFixedPitch: Bool {
        fontDescriptor.symbolicTraits.contains(.monoSpace)
    }
}
