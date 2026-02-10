//
//  RichTextView.swift
//  RSSReader
//
//  Created on 2026-02-10.
//

import AppKit
import SwiftUI

/// SwiftUI wrapper for NSTextView displaying rich text content.
///
/// Provides a non-editable, selectable text view with link detection
/// and proper dark mode support for rendering NSAttributedString content.
struct RichTextView: NSViewRepresentable {
    /// The attributed string to display.
    let attributedString: NSAttributedString

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        // Configure for reading
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false

        // Remove text container insets for cleaner layout
        textView.textContainerInset = NSSize(width: 0, height: 0)

        // Reader-friendly settings
        textView.isAutomaticLinkDetectionEnabled = true
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        // Link styling
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand
        ]

        // Accessibility
        textView.setAccessibilityLabel("Article content")
        textView.setAccessibilityRole(.textArea)

        // Configure scroll view
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        // Set initial content
        textView.textStorage?.setAttributedString(attributedString)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else {
            return
        }

        // Only update if content changed
        if textView.textStorage?.string != attributedString.string {
            textView.textStorage?.setAttributedString(attributedString)

            // Scroll to top when content changes
            textView.scrollToBeginningOfDocument(nil)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Rich Text View") {
    let sampleHTML = """
    <h1>Welcome to the Article</h1>
    <p>This is a <strong>bold</strong> and <em>italic</em> text example.</p>
    <h2>Code Example</h2>
    <pre><code>let greeting = "Hello, World!"
    print(greeting)</code></pre>
    <blockquote>This is a quoted section that should be indented.</blockquote>
    <h3>A List</h3>
    <ul>
        <li>First item</li>
        <li>Second item</li>
        <li>Third item</li>
    </ul>
    <p>Visit <a href="https://example.com">Example.com</a> for more.</p>
    """

    let converter = HTMLAttributedStringConverter()
    let attributedString = converter.convert(sampleHTML)

    return RichTextView(attributedString: attributedString)
        .frame(width: 600, height: 400)
        .padding()
}
#endif
