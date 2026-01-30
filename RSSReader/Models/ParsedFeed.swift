//
//  ParsedFeed.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import Foundation

/// Intermediate model representing a parsed feed,
/// decoupled from FeedKit types. Used as a transfer object
/// between the parser and Core Data persistence layer.
struct ParsedFeed: Equatable {
    let title: String
    let siteURL: URL?
    let feedDescription: String?
    let articles: [ParsedArticle]
}

/// Intermediate model for a single parsed article.
struct ParsedArticle: Equatable, Identifiable {
    /// Unique ID derived from guid (RSS), id (Atom/JSON),
    /// or the article link as a fallback.
    let id: String
    let title: String
    let author: String?
    let published: Date
    let summary: String?
    let content: String?
    let link: URL
    let thumbnailURL: URL?
}
