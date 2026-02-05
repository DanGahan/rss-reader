//
//  ArticleListView.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import CoreData
import SwiftUI

/// Displays a scrollable, filterable list of articles for the currently
/// selected sidebar item. Uses `@FetchRequest` with a dynamic predicate
/// built from the sidebar selection and the unread-only filter toggle.
struct ArticleListView: View {
    let sidebarSelection: SidebarSelection?
    @ObservedObject var viewModel: ArticleListViewModel
    @ObservedObject var refreshService: RefreshService
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\CDArticle.published, order: .reverse)],
        animation: .default
    ) private var articles: FetchedResults<CDArticle>

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\CDFolder.name)],
        animation: .default
    ) private var folders: FetchedResults<CDFolder>

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\CDFeed.title)],
        animation: .default
    ) private var feeds: FetchedResults<CDFeed>

    var body: some View {
        Group {
            if sidebarSelection == nil {
                noSelectionView
            } else if articles.isEmpty {
                VStack(spacing: 0) { headerView; emptyStateView }
            } else {
                VStack(spacing: 0) { headerView; articleList }
            }
        }
        .frame(minWidth: 300)
        .contentMargins(.top, 0, for: .scrollContent)
        .onAppear { updatePredicate() }
        .onChange(of: sidebarSelection) { _, _ in
            viewModel.clearSelection()
            updatePredicate()
        }
        .onChange(of: viewModel.showUnreadOnly) { _, _ in updatePredicate() }
        .onReceive(NotificationCenter.default.publisher(for: .markAllAsRead)) { _ in
            viewModel.markAllAsRead(Array(articles), in: context)
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextArticle)) { _ in
            viewModel.selectNext(from: articles.map(\.id))
        }
        .onReceive(NotificationCenter.default.publisher(for: .previousArticle)) { _ in
            viewModel.selectPrevious(from: articles.map(\.id))
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextUnread)) { _ in
            let ids = articles.map(\.id)
            let unreadIds = Set(articles.filter { !$0.isRead }.map(\.id))
            viewModel.selectNextUnread(from: ids, unreadIds: unreadIds)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(unreadCountText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let lastRefresh = refreshService.lastRefreshDate {
                        Text("Last Update: \(lastUpdateText(for: lastRefresh))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never refreshed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            capsuleControls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func lastUpdateText(for date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins) minute\(mins == 1 ? "" : "s") ago"
        }
        if interval < 86400 {
            let hrs = Int(interval / 3600)
            return "\(hrs) hour\(hrs == 1 ? "" : "s") ago"
        }
        let days = Int(interval / 86400)
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }

    private var headerTitle: String {
        guard let selection = sidebarSelection else { return "Articles" }
        switch selection {
        case .all: return "All Articles"
        case .folder(let id):
            return folders.first { $0.id == id }?.name ?? "Folder"
        case .feed(let id):
            guard let feed = feeds.first(where: { $0.id == id }) else { return "Feed" }
            if let folderName = feed.folder?.name { return "\(folderName) - \(feed.title)" }
            return feed.title
        }
    }

    private var unreadCountText: String {
        let count = articles.filter { !$0.isRead }.count
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: count)) ?? "\(count)"
        return "\(formatted) unread article\(count == 1 ? "" : "s")"
    }

    /// Light gray background RGB(247,247,247)
    private static let capsuleBackground = Color(
        red: 247 / 255, green: 247 / 255, blue: 247 / 255
    )

    /// Capsule control grouping unread filter and refresh buttons.
    private var capsuleControls: some View {
        HStack(spacing: 2) {
            MailStyleButton(
                isOn: $viewModel.showUnreadOnly,
                systemImage: "line.3.horizontal.decrease"
            )
            .help("Show unread articles only")

            MailStyleButton(
                action: { NotificationCenter.default.post(name: .refresh, object: nil) },
                systemImage: "arrow.clockwise"
            )
            .help("Refresh all feeds")
            .disabled(refreshService.isRefreshing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Self.capsuleBackground, in: Capsule())
    }

    // MARK: - Subviews

    private var articleList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(articles, id: \.id) { article in
                        ArticleRowView(
                            article: article,
                            isSelected: viewModel.selectedArticleId == article.id
                        )
                        .id(article.id)
                        .onTapGesture { viewModel.selectArticle(article.id) }
                        Divider()
                    }
                }
            }
            .onChange(of: viewModel.selectedArticleId) { _, newId in
                guard let newId else { return }
                withAnimation { proxy.scrollTo(newId, anchor: .center) }
            }
        }
    }

    private var noSelectionView: some View {
        VStack(spacing: 8) {
            Image(systemName: "sidebar.left").font(.largeTitle).foregroundStyle(.secondary)
            Text("Select a feed or folder").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
            Text(viewModel.showUnreadOnly ? "No unread articles" : "No articles")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Predicate

    private func updatePredicate() { articles.nsPredicate = buildPredicate() }

    private func buildPredicate() -> NSPredicate? {
        guard let selection = sidebarSelection else { return NSPredicate(value: false) }
        var predicates: [NSPredicate] = []
        switch selection {
        case .all: break
        case .feed(let id):
            predicates.append(NSPredicate(format: "feed.id == %@", id as CVarArg))
        case .folder(let id):
            predicates.append(NSPredicate(format: "feed.folder.id == %@", id as CVarArg))
        }
        if viewModel.showUnreadOnly {
            predicates.append(NSPredicate(format: "isRead == NO"))
        }
        if predicates.isEmpty { return nil }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}

// MARK: - Mail Style Button

/// A button styled like Apple Mail toolbar buttons with hover highlight.
struct MailStyleButton: View {
    /// Highlight circle color RGB(234,234,234)
    private static let highlightColor = Color(
        red: 234 / 255, green: 234 / 255, blue: 234 / 255
    )

    @State private var isHovering = false

    // For toggle-style usage
    @Binding var isOn: Bool
    let systemImage: String
    private let isToggle: Bool
    private let action: (() -> Void)?

    /// Creates a toggle-style button.
    init(isOn: Binding<Bool>, systemImage: String) {
        _isOn = isOn
        self.systemImage = systemImage
        self.isToggle = true
        self.action = nil
    }

    /// Creates an action button.
    init(action: @escaping () -> Void, systemImage: String) {
        _isOn = .constant(false)
        self.systemImage = systemImage
        self.isToggle = false
        self.action = action
    }

    var body: some View {
        Button {
            if isToggle {
                isOn.toggle()
            } else {
                action?()
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isHovering ? Self.highlightColor : .clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
