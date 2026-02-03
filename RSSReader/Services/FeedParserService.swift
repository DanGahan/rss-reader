//
//  FeedParserService.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import FeedKit
import Foundation

/// Parses raw feed data (RSS 2.0, Atom, JSON Feed) into
/// intermediate `ParsedFeed` / `ParsedArticle` models using
/// the FeedKit library.
///
/// Invalid articles (missing title AND link) are silently
/// skipped so one bad entry does not break the whole feed.
struct FeedParserService {
    /// Parses raw feed `Data` and returns a `ParsedFeed`.
    ///
    /// - Throws: `RSSReaderError.parsingFailed` if the feed
    ///   cannot be parsed at all.
    func parse(data: Data) throws -> ParsedFeed {
        let parser = FeedParser(data: data)
        let result = parser.parse()

        switch result {
        case .success(let feed):
            return convert(feed)
        case .failure(let error):
            throw RSSReaderError.parsingFailed(
                error.localizedDescription
            )
        }
    }

    // MARK: - Feed Conversion

    private func convert(
        _ feed: FeedKit.Feed
    ) -> ParsedFeed {
        switch feed {
        case .rss(let rss):
            return convertRSS(rss)
        case .atom(let atom):
            return convertAtom(atom)
        case .json(let json):
            return convertJSON(json)
        }
    }

    // MARK: - RSS

    private func convertRSS(
        _ rss: RSSFeed
    ) -> ParsedFeed {
        let articles = (rss.items ?? []).compactMap {
            convertRSSItem($0)
        }
        return ParsedFeed(
            title: rss.title ?? "Untitled Feed",
            siteURL: URL(string: rss.link ?? ""),
            feedDescription: rss.description,
            articles: articles
        )
    }

    private func convertRSSItem(
        _ item: RSSFeedItem
    ) -> ParsedArticle? {
        let link = item.link.flatMap { URL(string: $0) }
        let title = item.title?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip articles without both title and link
        guard title != nil || link != nil else {
            return nil
        }

        let articleId = item.guid?.value
            ?? item.link
            ?? UUID().uuidString

        let thumbnailURL = item.enclosure?.attributes?
            .url.flatMap { URL(string: $0) }
            ?? mediaURL(from: item)

        return ParsedArticle(
            id: articleId,
            title: title ?? "Untitled",
            author: item.author
                ?? item.dublinCore?.dcCreator,
            published: item.pubDate ?? Date(),
            summary: item.description,
            content: item.content?.contentEncoded,
            link: link ?? URL(
                string: "about:blank"
            )!, // swiftlint:disable:this force_unwrapping
            thumbnailURL: thumbnailURL
        )
    }

    private func mediaURL(
        from item: RSSFeedItem
    ) -> URL? {
        guard let urlString = item.media?
            .mediaThumbnails?.first?.attributes?.url
        else { return nil }
        return URL(string: urlString)
    }

    // MARK: - Atom

    private func convertAtom(
        _ atom: AtomFeed
    ) -> ParsedFeed {
        let siteLink = atom.links?
            .first { $0.attributes?.rel == "alternate" }?
            .attributes?.href
            ?? atom.links?.first?.attributes?.href

        let articles = (atom.entries ?? []).compactMap {
            convertAtomEntry($0)
        }

        return ParsedFeed(
            title: atom.title ?? "Untitled Feed",
            siteURL: siteLink.flatMap { URL(string: $0) },
            feedDescription: atom.subtitle?.value,
            articles: articles
        )
    }

    private func convertAtomEntry(
        _ entry: AtomFeedEntry
    ) -> ParsedArticle? {
        let linkHref = entry.links?
            .first { $0.attributes?.rel == "alternate" }?
            .attributes?.href
            ?? entry.links?.first?.attributes?.href
        let link = linkHref.flatMap { URL(string: $0) }

        let title = entry.title?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard title != nil || link != nil else {
            return nil
        }

        let articleId = entry.id
            ?? linkHref
            ?? UUID().uuidString

        return ParsedArticle(
            id: articleId,
            title: title ?? "Untitled",
            author: entry.authors?.first?.name,
            published: entry.published
                ?? entry.updated
                ?? Date(),
            summary: entry.summary?.value,
            content: entry.content?.value,
            link: link ?? URL(
                string: "about:blank"
            )!, // swiftlint:disable:this force_unwrapping
            thumbnailURL: nil
        )
    }

    // MARK: - JSON Feed

    private func convertJSON(
        _ json: JSONFeed
    ) -> ParsedFeed {
        let articles = (json.items ?? []).compactMap {
            convertJSONItem($0)
        }
        return ParsedFeed(
            title: json.title ?? "Untitled Feed",
            siteURL: json.homePageURL.flatMap {
                URL(string: $0)
            },
            feedDescription: json.description,
            articles: articles
        )
    }

    private func convertJSONItem(
        _ item: JSONFeedItem
    ) -> ParsedArticle? {
        let link = item.url.flatMap { URL(string: $0) }
        let title = item.title?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard title != nil || link != nil else {
            return nil
        }

        let articleId = item.id
            ?? item.url
            ?? UUID().uuidString

        return ParsedArticle(
            id: articleId,
            title: title ?? "Untitled",
            author: item.author?.name,
            published: item.datePublished ?? Date(),
            summary: item.summary,
            content: item.contentHtml
                ?? item.contentText,
            link: link ?? URL(
                string: "about:blank"
            )!, // swiftlint:disable:this force_unwrapping
            thumbnailURL: item.image.flatMap {
                URL(string: $0)
            }
        )
    }
}
