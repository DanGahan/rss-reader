//
//  OPMLParser.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import Foundation

/// Parses OPML (XML) data into an `OPMLDocument` model.
///
/// Uses Foundation's `XMLParser` — no external
/// dependencies required.
///
/// Supports the standard OPML 1.0/2.0 format used by
/// Feedly, Inoreader, NetNewsWire, and other readers.
final class OPMLParser: NSObject {
    private let data: Data

    // Parsing state
    private var documentTitle = ""
    private var isInHead = false
    private var isInTitle = false
    private var titleBuffer = ""
    private var parseError: Error?

    /// Stack of (title, htmlURL, children) for folder
    /// outlines being built. Feed outlines are added
    /// directly without pushing onto the stack.
    private var folderStack: [FolderContext] = []

    /// Collects top-level outlines (folders and
    /// unfiled feeds).
    private var rootOutlines: [OPMLOutline] = []

    /// Tracks whether the current `<outline>` start
    /// was a feed (so we skip its matching end tag).
    private var feedOutlineDepth = 0

    init(data: Data) {
        self.data = data
    }

    /// Parses the OPML data and returns a document.
    ///
    /// - Throws: `RSSReaderError.parsingFailed` if
    ///   the XML is malformed or not valid OPML.
    func parse() throws -> OPMLDocument {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.shouldProcessNamespaces = false

        guard xmlParser.parse() else {
            let message = parseError?
                .localizedDescription
                ?? xmlParser.parserError?
                    .localizedDescription
                ?? "Unknown OPML parse error"
            throw RSSReaderError.parsingFailed(message)
        }

        return OPMLDocument(
            title: documentTitle.isEmpty
                ? "Imported Feeds"
                : documentTitle,
            outlines: rootOutlines
        )
    }
}

// MARK: - Private Types

private extension OPMLParser {
    struct FolderContext {
        let title: String
        let htmlURL: URL?
        var children: [OPMLOutline]
    }
}

// MARK: - XMLParserDelegate

extension OPMLParser: XMLParserDelegate {
    func parser(
        _ parser: XMLParser,
        didStartElement element: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        switch element.lowercased() {
        case "head":
            isInHead = true
        case "title" where isInHead:
            isInTitle = true
            titleBuffer = ""
        case "outline":
            handleOutlineStart(attributes)
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement element: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        switch element.lowercased() {
        case "head":
            isInHead = false
        case "title" where isInTitle:
            isInTitle = false
            documentTitle = titleBuffer
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
        case "outline":
            handleOutlineEnd()
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        if isInTitle {
            titleBuffer += string
        }
    }

    func parser(
        _ parser: XMLParser,
        parseErrorOccurred error: Error
    ) {
        parseError = error
    }
}

// MARK: - Outline Processing

private extension OPMLParser {
    func handleOutlineStart(
        _ attributes: [String: String]
    ) {
        let title = attributes["title"]
            ?? attributes["text"]
            ?? "Untitled"

        let xmlURL = attributes["xmlUrl"]
            .flatMap { URL(string: $0) }
        let htmlURL = attributes["htmlUrl"]
            .flatMap { URL(string: $0) }

        if let xmlURL {
            // Feed outline — create and add now
            let feed = OPMLOutline(
                title: title,
                xmlURL: xmlURL,
                htmlURL: htmlURL,
                children: []
            )
            appendOutline(feed)
            feedOutlineDepth += 1
        } else {
            // Folder outline — push context, collect
            // children until matching </outline>
            folderStack.append(
                FolderContext(
                    title: title,
                    htmlURL: htmlURL,
                    children: []
                )
            )
        }
    }

    func handleOutlineEnd() {
        if feedOutlineDepth > 0 {
            // Closing a feed outline — already added
            feedOutlineDepth -= 1
            return
        }

        // Closing a folder outline — pop context
        guard let folder = folderStack.popLast() else {
            return
        }

        let outline = OPMLOutline(
            title: folder.title,
            xmlURL: nil,
            htmlURL: folder.htmlURL,
            children: folder.children
        )
        appendOutline(outline)
    }

    func appendOutline(_ outline: OPMLOutline) {
        if folderStack.isEmpty {
            rootOutlines.append(outline)
        } else {
            folderStack[
                folderStack.count - 1
            ].children.append(outline)
        }
    }
}
