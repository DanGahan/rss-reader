//
//  OPMLDocument.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import Foundation

/// Represents a parsed OPML document containing
/// a title and a tree of outlines (folders and feeds).
struct OPMLDocument: Equatable {
    let title: String
    let outlines: [OPMLOutline]
}

/// A single OPML outline element, which is either a
/// folder (has children, no xmlURL) or a feed
/// (has xmlURL, typically no children).
struct OPMLOutline: Equatable {
    let title: String
    /// The feed URL (present for feed outlines).
    let xmlURL: URL?
    /// The website URL (optional for all outlines).
    let htmlURL: URL?
    /// Nested outlines (folders contain child feeds).
    let children: [OPMLOutline]

    /// `true` when this outline represents a folder
    /// (has no feed URL and has children).
    var isFolder: Bool {
        xmlURL == nil && !children.isEmpty
    }

    /// `true` when this outline represents a feed
    /// subscription.
    var isFeed: Bool {
        xmlURL != nil
    }
}
