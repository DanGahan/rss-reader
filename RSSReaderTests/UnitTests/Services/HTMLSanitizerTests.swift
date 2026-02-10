//
//  HTMLSanitizerTests.swift
//  RSSReaderTests
//
//  Created on 2026-02-10.
//

import Foundation
import Testing
@testable import RSSReader

@Suite("HTMLSanitizer Tests")
struct HTMLSanitizerTests {
    private let sut = HTMLSanitizer()

    // MARK: - Dangerous Tag Removal

    @Test("Removes script tags and content")
    func removesScriptTags() {
        let input = "<p>Hello</p><script>alert('xss')</script><p>World</p>"
        let result = sut.sanitize(input)
        #expect(!result.contains("script"))
        #expect(!result.contains("alert"))
        #expect(result.contains("<p>Hello</p>"))
        #expect(result.contains("<p>World</p>"))
    }

    @Test("Removes style tags and content")
    func removesStyleTags() {
        let input = "<style>.hidden { display: none; }</style><p>Content</p>"
        let result = sut.sanitize(input)
        #expect(!result.contains("style"))
        #expect(!result.contains("hidden"))
        #expect(result.contains("<p>Content</p>"))
    }

    @Test("Removes iframe tags")
    func removesIframeTags() {
        let input = "<p>Before</p><iframe src=\"evil.com\"></iframe><p>After</p>"
        let result = sut.sanitize(input)
        #expect(!result.contains("iframe"))
        #expect(!result.contains("evil.com"))
    }

    @Test("Removes object tags")
    func removesObjectTags() {
        let input = "<object data=\"flash.swf\"></object><p>Text</p>"
        let result = sut.sanitize(input)
        #expect(!result.contains("object"))
        #expect(!result.contains("flash"))
    }

    @Test("Removes embed tags")
    func removesEmbedTags() {
        let input = "<embed src=\"plugin.swf\"><p>Text</p>"
        let result = sut.sanitize(input)
        #expect(!result.contains("embed"))
        #expect(!result.contains("plugin"))
    }

    @Test("Removes form elements")
    func removesFormElements() {
        let input = "<form action=\"/steal\"><input type=\"text\"><button>Submit</button></form>"
        let result = sut.sanitize(input)
        #expect(!result.contains("form"))
        #expect(!result.contains("input"))
        #expect(!result.contains("button"))
    }

    // MARK: - Dangerous Attribute Removal

    @Test("Removes onclick attributes")
    func removesOnclickAttributes() {
        let input = "<p onclick=\"evil()\">Click me</p>"
        let result = sut.sanitize(input)
        #expect(!result.contains("onclick"))
        #expect(!result.contains("evil"))
        #expect(result.contains("<p>Click me</p>"))
    }

    @Test("Removes onload attributes")
    func removesOnloadAttributes() {
        let input = "<p onload=\"steal()\">Content</p>"
        let result = sut.sanitize(input)
        #expect(!result.contains("onload"))
    }

    @Test("Removes onerror attributes")
    func removesOnerrorAttributes() {
        let input = "<img onerror=\"hack()\">"
        let result = sut.sanitize(input)
        #expect(!result.contains("onerror"))
    }

    @Test("Removes onmouseover attributes")
    func removesOnmouseoverAttributes() {
        let input = "<p onmouseover=\"track()\">Hover</p>"
        let result = sut.sanitize(input)
        #expect(!result.contains("onmouseover"))
    }

    @Test("Removes style attributes")
    func removesStyleAttributes() {
        let input = "<p style=\"color: red;\">Styled</p>"
        let result = sut.sanitize(input)
        #expect(!result.contains("style="))
        #expect(!result.contains("color"))
    }

    @Test("Removes class attributes")
    func removesClassAttributes() {
        let input = "<p class=\"highlight\">Classed</p>"
        let result = sut.sanitize(input)
        #expect(!result.contains("class="))
        #expect(!result.contains("highlight"))
    }

    @Test("Removes id attributes")
    func removesIdAttributes() {
        let input = "<p id=\"unique\">Identified</p>"
        let result = sut.sanitize(input)
        #expect(!result.contains("id="))
    }

    @Test("Removes javascript URLs from href")
    func removesJavascriptURLs() {
        let input = "<a href=\"javascript:alert('xss')\">Click</a>"
        let result = sut.sanitize(input)
        #expect(!result.contains("javascript:"))
    }

    // MARK: - Allowed Tag Preservation

    @Test("Preserves paragraph tags")
    func preservesParagraphTags() {
        let input = "<p>Paragraph content</p>"
        let result = sut.sanitize(input)
        #expect(result.contains("<p>"))
        #expect(result.contains("</p>"))
        #expect(result.contains("Paragraph content"))
    }

    @Test("Preserves bold tags")
    func preservesBoldTags() {
        let input = "<b>Bold text</b>"
        let result = sut.sanitize(input)
        #expect(result.contains("<b>Bold text</b>"))
    }

    @Test("Preserves strong tags")
    func preservesStrongTags() {
        let input = "<strong>Strong text</strong>"
        let result = sut.sanitize(input)
        #expect(result.contains("<strong>Strong text</strong>"))
    }

    @Test("Preserves italic tags")
    func preservesItalicTags() {
        let input = "<i>Italic text</i>"
        let result = sut.sanitize(input)
        #expect(result.contains("<i>Italic text</i>"))
    }

    @Test("Preserves em tags")
    func preservesEmTags() {
        let input = "<em>Emphasized text</em>"
        let result = sut.sanitize(input)
        #expect(result.contains("<em>Emphasized text</em>"))
    }

    @Test("Preserves blockquote tags")
    func preservesBlockquoteTags() {
        let input = "<blockquote>Quoted text</blockquote>"
        let result = sut.sanitize(input)
        #expect(result.contains("<blockquote>Quoted text</blockquote>"))
    }

    @Test("Preserves heading tags")
    func preservesHeadingTags() {
        let input = "<h1>Title</h1><h2>Subtitle</h2><h3>Section</h3>"
        let result = sut.sanitize(input)
        #expect(result.contains("<h1>Title</h1>"))
        #expect(result.contains("<h2>Subtitle</h2>"))
        #expect(result.contains("<h3>Section</h3>"))
    }

    @Test("Preserves code and pre tags")
    func preservesCodeTags() {
        let input = "<pre><code>let x = 1</code></pre>"
        let result = sut.sanitize(input)
        #expect(result.contains("<pre>"))
        #expect(result.contains("<code>"))
        #expect(result.contains("let x = 1"))
    }

    @Test("Preserves list tags")
    func preservesListTags() {
        let input = "<ul><li>Item 1</li><li>Item 2</li></ul>"
        let result = sut.sanitize(input)
        #expect(result.contains("<ul>"))
        #expect(result.contains("<li>"))
        #expect(result.contains("</ul>"))
    }

    @Test("Preserves ordered list tags")
    func preservesOrderedListTags() {
        let input = "<ol><li>First</li><li>Second</li></ol>"
        let result = sut.sanitize(input)
        #expect(result.contains("<ol>"))
        #expect(result.contains("<li>"))
        #expect(result.contains("</ol>"))
    }

    @Test("Preserves br tags")
    func preservesBrTags() {
        let input = "Line 1<br>Line 2<br/>Line 3"
        let result = sut.sanitize(input)
        #expect(result.contains("<br>") || result.contains("<br/>"))
    }

    @Test("Preserves anchor tags with safe href")
    func preservesAnchorTags() {
        let input = "<a href=\"https://example.com\">Link</a>"
        let result = sut.sanitize(input)
        #expect(result.contains("<a"))
        #expect(result.contains("href=\"https://example.com\""))
    }

    // MARK: - Disallowed Tag Removal (Content Preserved)

    @Test("Removes div tags but preserves content")
    func removesDivPreservesContent() {
        let input = "<div>Content inside div</div>"
        let result = sut.sanitize(input)
        #expect(!result.contains("<div"))
        #expect(!result.contains("</div>"))
        #expect(result.contains("Content inside div"))
    }

    @Test("Removes span tags but preserves content")
    func removesSpanPreservesContent() {
        let input = "<span>Span content</span>"
        let result = sut.sanitize(input)
        #expect(!result.contains("<span"))
        #expect(!result.contains("</span>"))
        #expect(result.contains("Span content"))
    }

    @Test("Removes img tags")
    func removesImgTags() {
        let input = "<p>Text</p><img src=\"image.jpg\" alt=\"Image\"><p>More</p>"
        let result = sut.sanitize(input)
        #expect(!result.contains("<img"))
    }

    // MARK: - Edge Cases

    @Test("Handles empty input")
    func handlesEmptyInput() {
        let result = sut.sanitize("")
        #expect(result.isEmpty)
    }

    @Test("Handles plain text without HTML")
    func handlesPlainText() {
        let input = "Just some plain text"
        let result = sut.sanitize(input)
        #expect(result == "Just some plain text")
    }

    @Test("Handles nested allowed tags")
    func handlesNestedAllowedTags() {
        let input = "<p><strong>Bold <em>and italic</em></strong></p>"
        let result = sut.sanitize(input)
        #expect(result.contains("<p>"))
        #expect(result.contains("<strong>"))
        #expect(result.contains("<em>"))
    }

    @Test("Handles case-insensitive tags")
    func handlesCaseInsensitiveTags() {
        let input = "<SCRIPT>alert('xss')</SCRIPT><P>Content</P>"
        let result = sut.sanitize(input)
        #expect(!result.lowercased().contains("script"))
        #expect(result.contains("Content"))
    }

    @Test("Handles malformed HTML gracefully")
    func handlesMalformedHTML() {
        let input = "<p>Unclosed paragraph<script>evil()</script>"
        let result = sut.sanitize(input)
        #expect(!result.contains("script"))
        #expect(result.contains("Unclosed paragraph"))
    }

    @Test("Strips dangerous attributes from allowed tags")
    func stripsDangerousFromAllowed() {
        let input = "<p onclick=\"hack()\" style=\"color:red\">Safe content</p>"
        let result = sut.sanitize(input)
        #expect(!result.contains("onclick"))
        #expect(!result.contains("style"))
        #expect(result.contains("<p>Safe content</p>"))
    }

    @Test("Handles multiline script content")
    func handlesMultilineScript() {
        let input = """
        <p>Before</p>
        <script>
        function evil() {
            steal();
        }
        </script>
        <p>After</p>
        """
        let result = sut.sanitize(input)
        #expect(!result.contains("script"))
        #expect(!result.contains("function"))
        #expect(result.contains("<p>Before</p>"))
        #expect(result.contains("<p>After</p>"))
    }
}
