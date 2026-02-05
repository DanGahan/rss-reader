//
//  ImportOPMLWizard.swift
//  RSSReader
//
//  Created on 2026-02-05.
//

import AppKit
import CoreData
import SwiftUI
import UniformTypeIdentifiers

/// A wizard-style sheet for importing feeds from an OPML file.
struct ImportOPMLWizard: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext)
    private var viewContext

    @StateObject private var viewModel = ImportOPMLViewModel()

    @FetchRequest(
        sortDescriptors: [
            SortDescriptor(\CDFolder.sortOrder),
            SortDescriptor(\CDFolder.name)
        ]
    ) private var folders: FetchedResults<CDFolder>

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 520, height: 480)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(headerTitle)
                .font(.headline)
            Spacer()
            stepIndicator
        }
        .padding()
    }

    private var headerTitle: String {
        switch viewModel.currentStep {
        case .selectFile:
            return "Import Subscriptions"
        case .selectFeeds:
            return "Select Feeds to Import"
        case .complete:
            return "Import Complete"
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(stepColor(for: index))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func stepColor(for index: Int) -> Color {
        let currentIndex: Int
        switch viewModel.currentStep {
        case .selectFile: currentIndex = 0
        case .selectFeeds: currentIndex = 1
        case .complete: currentIndex = 2
        }
        return index <= currentIndex ? .accentColor : .secondary.opacity(0.3)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.currentStep {
        case .selectFile:
            fileSelectionView
        case .selectFeeds:
            feedSelectionView
        case .complete:
            completionView
        }
    }

    // MARK: - Step 1: File Selection

    private var fileSelectionView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Select an OPML file to import your subscriptions")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Choose File...") {
                showOpenPanel()
            }
            .buttonStyle(.borderedProminent)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .padding()
    }

    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Select OPML File"
        panel.allowedContentTypes = [
            UTType(filenameExtension: "opml") ?? .xml,
            .xml
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { response in
            guard response == .OK,
                  let url = panel.url
            else { return }

            DispatchQueue.main.async {
                let existingURLs = fetchExistingFeedURLs()
                viewModel.loadOPMLFile(
                    from: url,
                    existingURLs: existingURLs
                )
            }
        }
    }

    private func fetchExistingFeedURLs() -> Set<String> {
        let request = CDFeed.fetchRequest()
        request.propertiesToFetch = ["feedURL"]
        let feeds = (try? viewContext.fetch(request)) ?? []
        return Set(feeds.compactMap { $0.feedURL })
    }

    // MARK: - Step 2: Feed Selection

    private var feedSelectionView: some View {
        VStack(spacing: 0) {
            selectionToolbar
            Divider()
            feedList
        }
    }

    private var selectionToolbar: some View {
        HStack {
            Text("\(viewModel.selectedCount) of \(viewModel.feedItems.count) selected")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button("Select All") {
                viewModel.selectAll()
            }
            .buttonStyle(.borderless)

            Button("Deselect All") {
                viewModel.deselectAll()
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var feedList: some View {
        List {
            ForEach(viewModel.feedItems) { item in
                FeedSelectionRow(
                    item: item,
                    folders: Array(folders),
                    onToggle: {
                        viewModel.toggleSelection(for: item.id)
                    },
                    onFolderChange: { folderID in
                        viewModel.setTargetFolder(
                            for: item.id,
                            folderID: folderID
                        )
                    }
                )
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Step 3: Completion

    private var completionView: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                Text(
                    "\(viewModel.importedResults.count) feeds imported successfully"
                )
                .font(.headline)
            }
            .padding()

            Divider()

            List {
                ForEach(viewModel.importedResults) { result in
                    ImportedFeedRow(result: result)
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if viewModel.currentStep == .selectFeeds {
                Button("Back") {
                    viewModel.currentStep = .selectFile
                }
            }

            Spacer()

            if viewModel.currentStep != .complete {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }

            if viewModel.currentStep == .selectFeeds {
                Button("Import") {
                    viewModel.performImport(in: viewContext)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedCount == 0)
                .keyboardShortcut(.return, modifiers: [])
            }

            if viewModel.currentStep == .complete {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding()
    }
}

// MARK: - Feed Selection Row

private struct FeedSelectionRow: View {
    let item: ImportFeedItem
    let folders: [CDFolder]
    let onToggle: () -> Void
    let onFolderChange: (UUID?) -> Void

    var body: some View {
        HStack {
            Button {
                onToggle()
            } label: {
                Image(
                    systemName: item.isSelected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundColor(
                    item.isSelected ? .accentColor : .secondary
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title)
                        .lineLimit(1)
                    if item.isDuplicate {
                        Text("DUPLICATE")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(3)
                    }
                }
                Text(item.feedURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Picker("", selection: Binding(
                get: { item.targetFolderID },
                set: { onFolderChange($0) }
            )) {
                Text("No Folder").tag(nil as UUID?)
                ForEach(folders, id: \.id) { folder in
                    Text(folder.name).tag(folder.id as UUID?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Imported Feed Row

private struct ImportedFeedRow: View {
    let result: ImportedFeedResult

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(result.title)
                        .lineLimit(1)
                    if result.wasDuplicate {
                        Text("DUPLICATE")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(3)
                    }
                }
                if let folderName = result.folderName {
                    Text("in \(folderName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
