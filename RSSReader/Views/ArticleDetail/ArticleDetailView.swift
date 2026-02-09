//
//  ArticleDetailView.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import AppKit
import CoreData
import SwiftUI

/// Reading pane displaying the selected article's title,
/// metadata, and plain-text content.
///
/// Clicking the article title opens it in Safari.
/// Automatically marks the article as read when displayed.
struct ArticleDetailView: View {
    let articleId: String?

    @StateObject private var viewModel =
        ArticleDetailViewModel()

    @Environment(\.managedObjectContext)
    private var context

    @FetchRequest private var articles:
        FetchedResults<CDArticle>

    @State private var isHoveringTitle = false

    // MARK: - Init

    init(articleId: String?) {
        self.articleId = articleId

        let predicate: NSPredicate
        if let articleId {
            predicate = NSPredicate(
                format: "id == %@", articleId
            )
        } else {
            predicate = NSPredicate(value: false)
        }

        _articles = FetchRequest(
            sortDescriptors: [],
            predicate: predicate
        )
    }

    private var article: CDArticle? {
        articles.first
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let article {
                articleContent(article)
            } else {
                emptyState
            }
        }
        .frame(
            minWidth: 500,
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .ignoresSafeArea(.all, edges: .top)
        .onChange(of: articleId) { oldId, _ in
            if let oldId {
                let fetchRequest: NSFetchRequest<CDArticle> = CDArticle.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", oldId as CVarArg)
                fetchRequest.fetchLimit = 1

                if let articleToMarkAsRead = try? context.fetch(fetchRequest).first {
                    viewModel.markAsRead(articleToMarkAsRead, in: context)
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .openInSafari
            )
        ) { _ in
            guard let article else { return }
            viewModel.openInSafariWithFeedback(
                urlString: article.link
            )
        }
        .overlay(alignment: .bottom) {
            if viewModel.showOpenedToast {
                Text("Opened in Safari")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(
                            cornerRadius: 8
                        )
                    )
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom))
                    .animation(
                        .easeInOut,
                        value: viewModel.showOpenedToast
                    )
            }
        }
    }

    // MARK: - Article Content

    private func articleContent(
        _ article: CDArticle
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                metadataHeader(article)
                    .padding(.bottom, 16)
                Divider()
                bodyText(article)
            }
            .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Metadata Header

    private func metadataHeader(
        _ article: CDArticle
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            clickableTitle(article)
            metadataLabels(article)
        }
    }

    private func clickableTitle(
        _ article: CDArticle
    ) -> some View {
        Text(article.title.decodingHTMLEntities())
            .font(.title)
            .fontWeight(.bold)
            .foregroundStyle(
                isHoveringTitle ? Color.accentColor : .primary
            )
            .underline(isHoveringTitle)
            .onHover { hovering in
                isHoveringTitle = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onTapGesture {
                viewModel.openInSafariWithFeedback(
                    urlString: article.link
                )
            }
            .accessibilityAddTraits(.isLink)
            .accessibilityHint("Opens article in Safari")
    }

    private func metadataLabels(
        _ article: CDArticle
    ) -> some View {
        HStack(spacing: 12) {
            if let author = article.author?.normalizingWhitespace(),
               !author.isEmpty {
                Label(author, systemImage: "person")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Label(
                viewModel.formattedDate(
                    article.published
                ),
                systemImage: "calendar"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let feedTitle = article.feed?.title {
                Label(
                    feedTitle,
                    systemImage:
                        "dot.radiowaves.up.forward"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Body Text

    /// Reader-mode style body font (slightly larger than system body)
    private static let readerFont = Font.system(size: 16)

    private func bodyText(
        _ article: CDArticle
    ) -> some View {
        let text = viewModel.formattedContent(
            for: article
        )

        return Group {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("No content available.")
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(text)
                    .font(Self.readerFont)
                    .lineSpacing(8)
                    .textSelection(.enabled)
                    .frame(maxWidth: 700, alignment: .leading)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Select an article to read")
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }
}
