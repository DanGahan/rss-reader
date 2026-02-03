//
//  ContentViewLayoutTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-30.
//

import Foundation
import Testing
@testable import RSSReader

@Suite("ContentView Layout Tests")
struct ContentViewLayoutTests {
    // MARK: - Notification Names

    @Test(".addFeed notification name has correct raw value")
    func addFeedNotificationName() {
        #expect(
            Notification.Name.addFeed.rawValue == "addFeed"
        )
    }

    @Test(".refresh notification name has correct raw value")
    func refreshNotificationName() {
        #expect(
            Notification.Name.refresh.rawValue == "refresh"
        )
    }

    @Test(".addFeed is distinct from other notification names")
    func addFeedIsDistinct() {
        #expect(
            Notification.Name.addFeed
                != Notification.Name.refresh
        )
        #expect(
            Notification.Name.addFeed
                != Notification.Name.nextUnread
        )
    }

    // MARK: - ViewModel Defaults

    @Test("SidebarViewModel initializes with nil selection")
    @MainActor
    func sidebarViewModelDefaults() {
        let viewModel = SidebarViewModel()
        #expect(viewModel.selection == nil)
        #expect(viewModel.collapsedFolders.isEmpty)
    }

    @Test(
        "ArticleListViewModel initializes with expected defaults"
    )
    @MainActor
    func articleListViewModelDefaults() {
        let viewModel = ArticleListViewModel()
        #expect(viewModel.selectedArticleId == nil)
        #expect(!viewModel.showUnreadOnly)
        #expect(!viewModel.isLoading)
    }

    // MARK: - Notification Posting

    @Test("addFeed notification posts via NotificationCenter")
    func addFeedNotificationPosts() async {
        await confirmation { received in
            let center = NotificationCenter.default
            let observer = center.addObserver(
                forName: .addFeed,
                object: nil,
                queue: .main
            ) { _ in
                received()
            }

            center.post(
                name: .addFeed,
                object: nil
            )

            // Allow the notification to be delivered
            try? await Task.sleep(
                nanoseconds: 100_000_000
            )

            center.removeObserver(observer)
        }
    }

    @Test("refresh notification posts via NotificationCenter")
    func refreshNotificationPosts() async {
        await confirmation { received in
            let center = NotificationCenter.default
            let observer = center.addObserver(
                forName: .refresh,
                object: nil,
                queue: .main
            ) { _ in
                received()
            }

            center.post(
                name: .refresh,
                object: nil
            )

            try? await Task.sleep(
                nanoseconds: 100_000_000
            )

            center.removeObserver(observer)
        }
    }
}
