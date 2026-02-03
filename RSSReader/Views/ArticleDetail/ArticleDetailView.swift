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
/// metadata, plain-text content, and a Safari action button.
///
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
        .onChange(of: articleId) { _, newId in
            if let newId, let art = articles.first,
               art.id == newId {
                viewModel.markAsRead(art, in: context)
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
            VStack(alignment: .leading, spacing: 16) {
                metadataHeader(article)
                Divider()
                bodyText(article)
                Spacer(minLength: 24)
                actionsBar(article)
            }
            .padding(24)
        }
        .onAppear {
            viewModel.markAsRead(article, in: context)
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
        Text(article.title)
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
            if let author = article.author,
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

    private func bodyText(
        _ article: CDArticle
    ) -> some View {
        let text = viewModel.plainTextContent(
            for: article
        )

        return Group {
            if text.isEmpty {
                Text("No content available.")
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(text)
                    .font(.body)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Actions Bar

    private func actionsBar(
        _ article: CDArticle
    ) -> some View {
        HStack {
            Button {
                viewModel.openInSafariWithFeedback(
                    urlString: article.link
                )
            } label: {
                Label(
                    "Open in Safari",
                    systemImage: "safari"
                )
            }
            .buttonStyle(.borderedProminent)
            Spacer()
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
