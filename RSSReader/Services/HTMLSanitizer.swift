//
//  HTMLSanitizer.swift
//  RSSReader
//
//  Created on 2026-02-10.
//

import Foundation

/// Sanitizes HTML content by removing dangerous elements while preserving
/// safe formatting tags for rich text display.
///
/// Uses an allow-list approach: only explicitly allowed tags are preserved,
/// all others are removed. Dangerous attributes are stripped from all tags.
struct HTMLSanitizer {
    /// Tags allowed to pass through sanitization.
    static let allowedTags: Set<String> = [
        "p", "br",
        "ul", "ol", "li",
        "b", "strong", "i", "em",
        "blockquote",
        "h1", "h2", "h3", "h4", "h5", "h6",
        "pre", "code",
        "a"
    ]

    /// Tags that should be completely removed including their content.
    static let dangerousTags: Set<String> = [
        "script", "style", "iframe", "object", "embed",
        "form", "input", "textarea", "button", "select"
    ]

    /// Attributes that are always removed (security risk).
    private static let dangerousAttributePatterns: [String] = [
        "on\\w+",  // All event handlers (onclick, onload, etc.)
        "style",
        "class",
        "id"
    ]

    /// Safe attributes that can be preserved on allowed tags.
    private static let safeAttributes: Set<String> = [
        "href"  // For links
    ]

    /// Sanitizes HTML string, removing dangerous elements.
    ///
    /// - Parameter html: The HTML string to sanitize.
    /// - Returns: Sanitized HTML with only safe tags and attributes.
    func sanitize(_ html: String) -> String {
        var result = html

        // Step 1: Remove dangerous tags and their content entirely
        result = removeDangerousTags(result)

        // Step 2: Remove dangerous attributes from remaining tags
        result = removeDangerousAttributes(result)

        // Step 3: Remove tags not in the allow-list (but keep their content)
        result = removeDisallowedTags(result)

        return result
    }

    // MARK: - Private Helpers

    /// Removes dangerous tags and all their content.
    private func removeDangerousTags(_ html: String) -> String {
        var result = html

        for tag in Self.dangerousTags {
            // Match opening tag, content, and closing tag (case insensitive)
            // Handle self-closing variants too
            let patterns = [
                "<\(tag)[^>]*>.*?</\(tag)>",  // With content
                "<\(tag)[^>]*/?>",             // Self-closing
                "</\(tag)>"                    // Orphan closing
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(
                    pattern: pattern,
                    options: [.caseInsensitive, .dotMatchesLineSeparators]
                ) {
                    result = regex.stringByReplacingMatches(
                        in: result,
                        range: NSRange(result.startIndex..., in: result),
                        withTemplate: ""
                    )
                }
            }
        }

        return result
    }

    /// Removes dangerous attributes from all tags.
    private func removeDangerousAttributes(_ html: String) -> String {
        var result = html

        for pattern in Self.dangerousAttributePatterns {
            // Match attribute="value" or attribute='value' or attribute=value
            let attrPattern = "\\s+\(pattern)\\s*=\\s*(?:\"[^\"]*\"|'[^']*'|[^\\s>]+)"

            if let regex = try? NSRegularExpression(
                pattern: attrPattern,
                options: .caseInsensitive
            ) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // Also remove javascript: URLs from href attributes
        if let jsRegex = try? NSRegularExpression(
            pattern: "href\\s*=\\s*[\"']?javascript:[^\"'\\s>]*[\"']?",
            options: .caseInsensitive
        ) {
            result = jsRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        return result
    }

    /// Removes tags not in the allow-list, preserving their content.
    private func removeDisallowedTags(_ html: String) -> String {
        var result = html

        guard let regex = try? NSRegularExpression(
            pattern: "</?([a-zA-Z][a-zA-Z0-9]*)(?:\\s[^>]*)?\\/?>",
            options: []
        ) else {
            return html
        }

        // Find all tags and filter out disallowed ones
        let matches = regex.matches(
            in: result,
            range: NSRange(result.startIndex..., in: result)
        )

        // Process matches in reverse order to preserve indices
        for match in matches.reversed() {
            guard let tagRange = Range(match.range(at: 1), in: result) else {
                continue
            }

            let tagName = String(result[tagRange]).lowercased()

            if !Self.allowedTags.contains(tagName) {
                // Remove the disallowed tag, keeping content
                if let fullRange = Range(match.range, in: result) {
                    result.replaceSubrange(fullRange, with: "")
                }
            }
        }

        return result
    }
}
