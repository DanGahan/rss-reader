//
//  ArticleRowView.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import SwiftUI

/// A single article row displaying title, author, date,
/// and a read/unread indicator.
struct ArticleRowView: View {
    @ObservedObject var article: CDArticle
    let isSelected: Bool

    /// Formatter for displaying published date/time.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 8) {
            unreadIndicator
            articleContent
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(selectionBackground)
        .contentShape(Rectangle())
    }

    // MARK: - Subviews

    private var unreadIndicator: some View {
        Circle()
            .fill(article.isRead ? Color.clear : .accentColor)
            .frame(width: 8, height: 8)
    }

    private var articleContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(article.title)
                .fontWeight(
                    article.isRead ? .regular : .semibold
                )
                .lineLimit(2)
                .foregroundStyle(
                    isSelected ? .white : .primary
                )

            HStack {
                if let author = article.author,
                   !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(
                            isSelected
                                ? .white.opacity(0.8)
                                : .secondary
                        )
                        .lineLimit(1)
                }
                Spacer()
                Text(
                    Self.dateFormatter.string(
                        from: article.published
                    )
                )
                .font(.caption)
                .foregroundStyle(
                    isSelected
                        ? .white.opacity(0.8)
                        : .secondary
                )
            }
        }
    }

    private var selectionBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(
                isSelected
                    ? Color.accentColor
                    : .clear
            )
    }
}
