//
//  ImportOPMLViewModel.swift
//  RSSReader
//
//  Created on 2026-02-05.
//

import CoreData
import Foundation

/// Represents a feed item for selection in the import wizard.
struct ImportFeedItem: Identifiable {
    let id = UUID()
    let title: String
    let feedURL: String
    let siteURL: String?
    let originalFolderName: String?
    var isSelected: Bool = true
    var targetFolderID: UUID?
    var isDuplicate: Bool = false
}

/// Result of importing a single feed.
struct ImportedFeedResult: Identifiable {
    let id = UUID()
    let title: String
    let feedURL: String
    let folderName: String?
    let wasDuplicate: Bool
}

/// Wizard steps for OPML import.
enum ImportWizardStep {
    case selectFile
    case selectFeeds
    case complete
}

/// ViewModel for the OPML import wizard.
@MainActor
final class ImportOPMLViewModel: ObservableObject {
    @Published var currentStep: ImportWizardStep = .selectFile
    @Published var feedItems: [ImportFeedItem] = []
    @Published var importedResults: [ImportedFeedResult] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let opmlService = OPMLService()
    private var parsedDocument: OPMLDocument?

    // MARK: - Step 1: File Selection

    /// Parses an OPML file and extracts feeds for selection.
    func loadOPMLFile(
        from url: URL,
        existingURLs: Set<String>
    ) {
        isLoading = true
        errorMessage = nil

        do {
            let document = try opmlService.parseOPML(from: url)
            parsedDocument = document
            feedItems = extractFeedItems(
                from: document,
                existingURLs: existingURLs
            )
            currentStep = .selectFeeds
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Step 2: Feed Selection

    /// Toggles selection for a feed item.
    func toggleSelection(for itemID: UUID) {
        guard let index = feedItems.firstIndex(
            where: { $0.id == itemID }
        ) else { return }
        feedItems[index].isSelected.toggle()
    }

    /// Sets the target folder for a feed item.
    func setTargetFolder(
        for itemID: UUID,
        folderID: UUID?
    ) {
        guard let index = feedItems.firstIndex(
            where: { $0.id == itemID }
        ) else { return }
        feedItems[index].targetFolderID = folderID
    }

    /// Selects all feed items.
    func selectAll() {
        for index in feedItems.indices {
            feedItems[index].isSelected = true
        }
    }

    /// Deselects all feed items.
    func deselectAll() {
        for index in feedItems.indices {
            feedItems[index].isSelected = false
        }
    }

    /// Number of selected feeds.
    var selectedCount: Int {
        feedItems.filter(\.isSelected).count
    }

    // MARK: - Step 3: Import

    /// Performs the import of selected feeds.
    func performImport(
        in context: NSManagedObjectContext
    ) {
        isLoading = true
        importedResults = []

        let selectedFeeds = feedItems.filter(\.isSelected)

        for item in selectedFeeds {
            let title = item.isDuplicate
                ? "\(item.title)-DUPLICATE"
                : item.title

            let feed = CDFeed.create(
                in: context,
                title: title,
                feedURL: item.feedURL
            )

            if let siteURL = item.siteURL {
                feed.siteURL = siteURL
            }

            // Assign folder if selected
            if let folderID = item.targetFolderID {
                feed.folder = fetchFolder(
                    id: folderID,
                    in: context
                )
            }

            importedResults.append(ImportedFeedResult(
                title: title,
                feedURL: item.feedURL,
                folderName: feed.folder?.name,
                wasDuplicate: item.isDuplicate
            ))
        }

        do {
            try context.save()
            currentStep = .complete
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Private Helpers

    private func extractFeedItems(
        from document: OPMLDocument,
        existingURLs: Set<String>
    ) -> [ImportFeedItem] {
        var items: [ImportFeedItem] = []

        for outline in document.outlines {
            if outline.isFolder {
                // Extract feeds from folder
                for child in outline.children where child.isFeed {
                    if let item = createFeedItem(
                        from: child,
                        folderName: outline.title,
                        existingURLs: existingURLs
                    ) {
                        items.append(item)
                    }
                }
            } else if outline.isFeed {
                // Top-level feed
                if let item = createFeedItem(
                    from: outline,
                    folderName: nil,
                    existingURLs: existingURLs
                ) {
                    items.append(item)
                }
            }
        }

        return items
    }

    private func createFeedItem(
        from outline: OPMLOutline,
        folderName: String?,
        existingURLs: Set<String>
    ) -> ImportFeedItem? {
        guard let xmlURL = outline.xmlURL else {
            return nil
        }

        let feedURLString = xmlURL.absoluteString
        let isDuplicate = existingURLs.contains(feedURLString)

        return ImportFeedItem(
            title: outline.title,
            feedURL: feedURLString,
            siteURL: outline.htmlURL?.absoluteString,
            originalFolderName: folderName,
            isSelected: true,
            targetFolderID: nil,
            isDuplicate: isDuplicate
        )
    }

    private func fetchFolder(
        id: UUID,
        in context: NSManagedObjectContext
    ) -> CDFolder? {
        let request = CDFolder.fetchRequest()
        request.predicate = NSPredicate(
            format: "id == %@", id as CVarArg
        )
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}
