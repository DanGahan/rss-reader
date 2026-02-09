//
//  SidebarUnfiledFeedsView.swift
//  RSSReader
//
//  Created on 2026-02-06.
//

import SwiftUI
import UniformTypeIdentifiers

struct SidebarUnfiledFeedsView: View {
    @ObservedObject var viewModel: SidebarViewModel
    let unfiledFeeds: FetchedResults<CDFeed>
    let folders: FetchedResults<CDFolder>

    @Environment(\.managedObjectContext)
    private var context

    var body: some View {
        if !unfiledFeeds.isEmpty {
            Section("Unfiled") {
                ForEach(
                    unfiledFeeds, id: \.id
                ) { feed in
                    FeedRowView(feed: feed)
                        .tag(
                            SidebarSelection.feed(
                                feed.id
                            )
                        )
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                viewModel.selection = .feed(
                                    feed.id
                                )
                            }
                        )
                        .onDrag {
                            NSItemProvider(
                                object: feed.id.uuidString as NSString
                            )
                        }
                        .contextMenu {
                            feedContextMenu(feed: feed)
                        }
                }
            }
            .onDrop(of: [UTType.feedDrag], isTargeted: nil) { providers in
                handleDrop(providers: providers, toFolderId: nil)
            }
        }
    }

    // MARK: - Drop Handling

    private func handleDrop(providers: [NSItemProvider], toFolderId folderId: UUID?) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { string, error in
            if let error = error {
                print("Error loading dragged object: \(error.localizedDescription)")
                return
            }
            guard let uuidString = string as? String,
                  let feedId = UUID(uuidString: uuidString) else { return }
            DispatchQueue.main.async {
                viewModel.moveFeed(feedId: feedId, toFolderId: folderId, in: context)
            }
        }
        return true
    }

    // MARK: - Context Menus

    @ViewBuilder
    private func feedContextMenu(
        feed: CDFeed
    ) -> some View {
        Menu("Move to Folder") {
            ForEach(folders, id: \.id) { folder in
                Button(folder.name) {
                    viewModel.moveFeed(
                        feedId: feed.id,
                        toFolderId: folder.id,
                        in: context
                    )
                }
                .disabled(feed.folder?.id == folder.id)
            }
            Divider()
            Button("Unfiled") {
                viewModel.moveFeed(
                    feedId: feed.id,
                    toFolderId: nil,
                    in: context
                )
            }
            .disabled(feed.folder == nil)
        }
        Divider()
        Button(role: .destructive) {
            deleteFeed(feed)
        } label: {
            Label(
                "Remove Feed",
                systemImage: "trash"
            )
        }
    }

    // MARK: - Actions

    private func deleteFeed(_ feed: CDFeed) {
        context.delete(feed)
        try? context.save()
    }
}
