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
/// Calculates its own height based on content for proper SwiftUI layout.
struct RichTextView: NSViewRepresentable {
    /// The attributed string to display.
    let attributedString: NSAttributedString

    /// The width to use for calculating text height.
    let containerWidth: CGFloat

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()

        // Configure for reading
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false

        // Remove text container insets for cleaner layout
        textView.textContainerInset = NSSize(width: 0, height: 0)

        // Configure text container for proper wrapping
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false

        // Allow vertical resizing
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

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

        // Set initial content
        textView.textStorage?.setAttributedString(attributedString)

        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        // Only update if content changed
        if textView.textStorage?.string != attributedString.string {
            textView.textStorage?.setAttributedString(attributedString)
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView textView: NSTextView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? containerWidth

        // Set the text container width
        textView.textContainer?.containerSize = CGSize(
            width: width,
            height: CGFloat.greatestFiniteMagnitude
        )

        // Force layout
        textView.layoutManager?.ensureLayout(
            for: textView.textContainer!  // swiftlint:disable:this force_unwrapping
        )

        // Get the used rect
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return CGSize(width: width, height: 100)
        }

        let usedRect = layoutManager.usedRect(for: textContainer)
        return CGSize(width: width, height: usedRect.height + 20)
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

    return ScrollView {
        RichTextView(
            attributedString: attributedString,
            containerWidth: 600
        )
        .frame(width: 600)
        .padding()
    }
    .frame(width: 650, height: 400)
}
#endif
