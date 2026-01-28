//
//  Article.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Foundation

/// Represents an article/entry from a Feedly stream.
struct Article: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String?
    let published: Date
    let updated: Date?
    let summary: ArticleContent?
    let content: ArticleContent?
    let origin: Origin
    let canonical: [Link]?
    let alternate: [Link]?
    let visual: Visual?
    var isRead: Bool
    let engagement: Int?
    let keywords: [String]?

    /// Formatted date string for display.
    var displayDate: String {
        published.formatted(date: .abbreviated, time: .shortened)
    }

    /// The primary URL for this article.
    var primaryLink: URL? {
        alternate?.first?.href ?? canonical?.first?.href
    }

    /// Thumbnail image URL if available.
    var thumbnailUrl: URL? {
        visual?.url
    }

    /// Plain text content with HTML tags stripped.
    var plainTextContent: String {
        let rawContent = content?.content ?? summary?.content ?? ""
        return rawContent.stripHTML()
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Article, rhs: Article) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Nested Types

    /// Article HTML content with optional text direction.
    struct ArticleContent: Codable, Hashable {
        let content: String
        let direction: String?
    }

    /// The source feed for this article.
    struct Origin: Codable, Hashable {
        let streamId: String
        let title: String
        let htmlUrl: URL?
    }

    /// A link associated with the article.
    struct Link: Codable, Hashable {
        let href: URL
        let type: String?
    }

    /// Visual/thumbnail image for the article.
    struct Visual: Codable, Hashable {
        let url: URL
        let width: Int?
        let height: Int?
        let contentType: String?
    }
}
