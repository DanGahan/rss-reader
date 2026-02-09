//
//  StringExtensions.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Foundation

extension String {
    /// Strips HTML tags from a string, returning plain text content.
    func stripHTML() -> String {
        guard let data = self.data(using: .utf8) else {
            return self
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        if let attributedString = try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) {
            return attributedString.string
        }

        // Fallback: basic regex-based HTML stripping
        return self
            .replacingOccurrences(
                of: "<[^>]+>",
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Converts HTML to formatted plain text, preserving paragraph
    /// structure with double line breaks between paragraphs and
    /// adding a leading line break if not present.
    ///
    /// Inspired by Safari Reader Mode for clean, readable output.
    func htmlToFormattedText() -> String {
        // Convert HTML block elements to newlines, then strip tags
        let text = convertBlockElementsToNewlines().stripHTML()

        // Clean up whitespace while preserving paragraph structure
        var result = cleanupWhitespace(text)

        // Add leading line break if not empty (for spacing after header)
        if !result.isEmpty {
            result = "\n" + result
        }
        return result
    }

    /// Converts HTML block elements to newlines for paragraph preservation.
    private func convertBlockElementsToNewlines() -> String {
        var html = self
        // Replace closing </p> tags with double newline for paragraph spacing
        html = html.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        // Remove opening <p> tags
        html = html.replacingOccurrences(of: "<p[^>]*>", with: "", options: .regularExpression)
        // Convert <br> tags to single newlines
        html = html.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        // Convert block-level closing tags to double newlines
        html = html.replacingOccurrences(
            of: "</(?:div|h[1-6]|blockquote|li|tr)>",
            with: "\n\n",
            options: .regularExpression
        )
        // Add bullet before list items
        html = html.replacingOccurrences(of: "<li[^>]*>", with: "• ", options: .regularExpression)
        return html
    }

    /// Cleans up whitespace while preserving paragraph breaks.
    private func cleanupWhitespace(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        // Collapse 3+ newlines to 2
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        // Trim each line
        result = result.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Decodes HTML entities like &#8217; to their proper characters.
    func decodingHTMLEntities() -> String {
        guard contains("&") else { return self }

        // Wrap in minimal HTML to leverage NSAttributedString decoding
        let wrapped = "<span>\(self)</span>"
        guard let data = wrapped.data(using: .utf8) else { return self }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        if let attributed = try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) {
            return attributed.string
        }

        return self
    }

    /// Normalizes whitespace by collapsing newlines and multiple spaces
    /// into single spaces, then trims leading/trailing whitespace.
    /// Useful for cleaning up author names and other metadata that may
    /// contain stray formatting.
    func normalizingWhitespace() -> String {
        self
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
