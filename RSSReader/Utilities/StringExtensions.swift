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
}
