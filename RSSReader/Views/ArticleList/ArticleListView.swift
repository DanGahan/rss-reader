//
//  ArticleListView.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import CoreData
import SwiftUI

/// Displays a scrollable, filterable list of articles for
/// the currently selected sidebar item.
///
/// Uses `@FetchRequest` with a dynamic predicate built from
/// the sidebar selection and the unread-only filter toggle.
struct ArticleListView: View {
    let sidebarSelection: SidebarSelection?

    @ObservedObject var viewModel: ArticleListViewModel

    @Environment(\.managedObjectContext)
    private var context

    @FetchRequest(
        sortDescriptors: [
            SortDescriptor(
                \CDArticle.published,
                order: .reverse
            )
        ],
        animation: .default
    ) private var articles: FetchedResults<CDArticle>

    var body: some View {
        Group {
            if sidebarSelection == nil {
                noSelectionView
            } else if articles.isEmpty {
                emptyStateView
            } else {
                articleList
            }
        }
        .frame(minWidth: 300)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: $viewModel.showUnreadOnly) {
                    Label(
                        "Unread Only",
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                }
                .help("Show unread articles only")
            }
        }
        .onAppear {
            updatePredicate()
        }
        .onChange(of: sidebarSelection) { _, _ in
            viewModel.clearSelection()
            updatePredicate()
        }
        .onChange(of: viewModel.showUnreadOnly) { _, _ in
            updatePredicate()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .markAllAsRead
            )
        ) { _ in
            viewModel.markAllAsRead(
                Array(articles),
                in: context
            )
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .nextArticle
            )
        ) { _ in
            let ids = articles.map(\.id)
            viewModel.selectNext(from: ids)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .previousArticle
            )
        ) { _ in
            let ids = articles.map(\.id)
            viewModel.selectPrevious(from: ids)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .nextUnread
            )
        ) { _ in
            let ids = articles.map(\.id)
            let unreadIds = Set(
                articles
                    .filter { !$0.isRead }
                    .map(\.id)
            )
            viewModel.selectNextUnread(
                from: ids,
                unreadIds: unreadIds
            )
        }
    }

    // MARK: - Subviews

    private var articleList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: 0
                ) {
                    ForEach(
                        articles,
                        id: \.id
                    ) { article in
                        ArticleRowView(
                            article: article,
                            isSelected: viewModel
                                .selectedArticleId
                                == article.id
                        )
                        .id(article.id)
                        .onTapGesture {
                            viewModel.selectArticle(
                                article.id
                            )
                        }
                        Divider()
                    }
                }
            }
            .onChange(
                of: viewModel.selectedArticleId
            ) { _, newId in
                guard let newId else { return }
                withAnimation {
                    proxy.scrollTo(
                        newId,
                        anchor: .center
                    )
                }
            }
        }
    }

    private var noSelectionView: some View {
        VStack(spacing: 8) {
            Image(systemName: "sidebar.left")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Select a feed or folder")
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(
                viewModel.showUnreadOnly
                    ? "No unread articles"
                    : "No articles"
            )
            .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }

    // MARK: - Predicate

    private func updatePredicate() {
        articles.nsPredicate = buildPredicate()
    }

    private func buildPredicate() -> NSPredicate? {
        guard let selection = sidebarSelection else {
            return NSPredicate(value: false)
        }

        var predicates: [NSPredicate] = []

        switch selection {
        case .all:
            // No filter for "All Articles" - show everything
            break
        case .feed(let id):
            predicates.append(
                NSPredicate(
                    format: "feed.id == %@",
                    id as CVarArg
                )
            )
        case .folder(let id):
            predicates.append(
                NSPredicate(
                    format: "feed.folder.id == %@",
                    id as CVarArg
                )
            )
        }

        if viewModel.showUnreadOnly {
            predicates.append(
                NSPredicate(format: "isRead == NO")
            )
        }

        // Return nil for "all with no unread filter" to fetch
        // everything, otherwise combine predicates
        if predicates.isEmpty {
            return nil
        }

        return NSCompoundPredicate(
            andPredicateWithSubpredicates: predicates
        )
    }
}
