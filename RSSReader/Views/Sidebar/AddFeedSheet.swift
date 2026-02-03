//
//  AddFeedSheet.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import CoreData
import SwiftUI

/// Sheet view for adding a new RSS/Atom/JSON feed.
///
/// Validates the URL, fetches and parses the feed to show a
/// title confirmation, allows folder selection, and creates
/// the `CDFeed` + initial `CDArticle` records on save.
struct AddFeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext)
    private var viewContext

    @FetchRequest(
        sortDescriptors: [
            SortDescriptor(\CDFolder.sortOrder),
            SortDescriptor(\CDFolder.name)
        ]
    ) private var folders: FetchedResults<CDFolder>

    @State private var urlString = ""
    @State private var feedTitle: String?
    @State private var parsedFeed: ParsedFeed?
    @State private var selectedFolderID: UUID?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let parser = FeedParserService()

    var body: some View {
        VStack(spacing: 16) {
            header
            urlField
            feedPreview
            folderPicker
            Spacer()
            errorView
            buttonBar
        }
        .padding(20)
        .frame(width: 420, height: 320)
    }

    // MARK: - Subviews

    private var header: some View {
        Text("Add Feed")
            .font(.headline)
    }

    private var urlField: some View {
        TextField(
            "Feed URL (https://...)",
            text: $urlString
        )
        .textFieldStyle(.roundedBorder)
        .onSubmit { validateAndFetch() }
        .disabled(isLoading)
    }

    @ViewBuilder
    private var feedPreview: some View {
        if isLoading {
            ProgressView()
                .controlSize(.small)
        } else if let title = feedTitle {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(title)
                    .fontWeight(.medium)
            }
        }
    }

    private var folderPicker: some View {
        Picker(
            "Folder",
            selection: $selectedFolderID
        ) {
            Text("None").tag(nil as UUID?)
            ForEach(folders, id: \.id) { folder in
                Text(folder.name).tag(
                    folder.id as UUID?
                )
            }
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var errorView: some View {
        if let errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
        }
    }

    private var buttonBar: some View {
        HStack {
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Button("Add") {
                addFeed()
            }
            .keyboardShortcut(.return, modifiers: [])
            .disabled(parsedFeed == nil || isLoading)
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Actions

    private func validateAndFetch() {
        errorMessage = nil
        feedTitle = nil
        parsedFeed = nil

        let trimmed = urlString
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // URL validation
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            errorMessage =
                RSSReaderError.invalidFeedURL
                    .errorDescription
            return
        }

        // Duplicate check
        if isDuplicate(url: trimmed) {
            errorMessage =
                RSSReaderError.duplicateFeed
                    .errorDescription
            return
        }

        isLoading = true

        Task {
            do {
                let (data, _) = try await URLSession
                    .shared.data(from: url)
                let parsed = try parser.parse(data: data)
                feedTitle = parsed.title
                parsedFeed = parsed
            } catch {
                errorMessage =
                    error.localizedDescription
            }
            isLoading = false
        }
    }

    private func addFeed() {
        guard let parsedFeed else { return }

        let trimmed = urlString
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let feed = CDFeed.create(
            in: viewContext,
            title: parsedFeed.title,
            feedURL: trimmed
        )
        feed.siteURL = parsedFeed.siteURL?
            .absoluteString

        // Assign folder if selected
        if let folderID = selectedFolderID {
            let request = CDFolder.fetchRequest()
            request.predicate = NSPredicate(
                format: "id == %@",
                folderID as CVarArg
            )
            feed.folder = try? viewContext.fetch(
                request
            ).first
        }

        // Save initial parsed articles
        for parsed in parsedFeed.articles {
            let article = CDArticle(
                context: viewContext
            )
            article.id = parsed.id
            article.title = parsed.title
            article.author = parsed.author
            article.published = parsed.published
            article.summary = parsed.summary
            article.content = parsed.content
            article.link = parsed.link.absoluteString
            article.thumbnailURL = parsed.thumbnailURL?
                .absoluteString
            article.isRead = false
            article.dateAdded = Date()
            article.feed = feed
        }

        try? viewContext.save()
        dismiss()
    }

    // MARK: - Validation Helpers

    /// Checks if a feed with the same URL already exists.
    func isDuplicate(url: String) -> Bool {
        let request = CDFeed.fetchRequest()
        request.predicate = NSPredicate(
            format: "feedURL == %@", url
        )
        let count = (
            try? viewContext.count(for: request)
        ) ?? 0
        return count > 0
    }
}
