//
//  ArticleListViewModelTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-30.
//

import CoreData
import Foundation
import Testing
@testable import RSSReader

@Suite("ArticleListViewModel Tests")
struct ArticleListViewModelTests {
    private let sampleIds = ["a1", "a2", "a3", "a4", "a5"]

    // MARK: - Initial State

    @Test("Selection is nil on init")
    @MainActor
    func initialState() {
        let vm = ArticleListViewModel()
        #expect(vm.selectedArticleId == nil)
        #expect(!vm.showUnreadOnly)
        #expect(!vm.isLoading)
    }

    // MARK: - Selection

    @Test("selectArticle sets selectedArticleId")
    @MainActor
    func selectArticle() {
        let vm = ArticleListViewModel()
        vm.selectArticle("a1")
        #expect(vm.selectedArticleId == "a1")
    }

    @Test("clearSelection resets to nil")
    @MainActor
    func clearSelection() {
        let vm = ArticleListViewModel()
        vm.selectArticle("a1")
        vm.clearSelection()
        #expect(vm.selectedArticleId == nil)
    }

    @Test("Selecting a new article replaces previous")
    @MainActor
    func selectionReplaces() {
        let vm = ArticleListViewModel()
        vm.selectArticle("a1")
        vm.selectArticle("a2")
        #expect(vm.selectedArticleId == "a2")
    }

    // MARK: - Select Next

    @Test("selectNext moves to next article")
    @MainActor
    func selectNext() {
        let vm = ArticleListViewModel()
        vm.selectArticle("a2")
        vm.selectNext(from: sampleIds)
        #expect(vm.selectedArticleId == "a3")
    }

    @Test("selectNext selects first when nothing selected")
    @MainActor
    func selectNextFromNone() {
        let vm = ArticleListViewModel()
        vm.selectNext(from: sampleIds)
        #expect(vm.selectedArticleId == "a1")
    }

    @Test("selectNext stays at end of list")
    @MainActor
    func selectNextAtEnd() {
        let vm = ArticleListViewModel()
        vm.selectArticle("a5")
        vm.selectNext(from: sampleIds)
        #expect(vm.selectedArticleId == "a1")
    }

    @Test("selectNext does nothing on empty list")
    @MainActor
    func selectNextEmpty() {
        let vm = ArticleListViewModel()
        vm.selectNext(from: [])
        #expect(vm.selectedArticleId == nil)
    }

    @Test("selectNext selects first if current not found")
    @MainActor
    func selectNextCurrentNotFound() {
        let vm = ArticleListViewModel()
        vm.selectArticle("unknown")
        vm.selectNext(from: sampleIds)
        #expect(vm.selectedArticleId == "a1")
    }

    // MARK: - Select Previous

    @Test("selectPrevious moves to previous article")
    @MainActor
    func selectPrevious() {
        let vm = ArticleListViewModel()
        vm.selectArticle("a3")
        vm.selectPrevious(from: sampleIds)
        #expect(vm.selectedArticleId == "a2")
    }

    @Test("selectPrevious does nothing at start of list")
    @MainActor
    func selectPreviousAtStart() {
        let vm = ArticleListViewModel()
        vm.selectArticle("a1")
        vm.selectPrevious(from: sampleIds)
        #expect(vm.selectedArticleId == "a1")
    }

    @Test("selectPrevious does nothing with no selection")
    @MainActor
    func selectPreviousNoSelection() {
        let vm = ArticleListViewModel()
        vm.selectPrevious(from: sampleIds)
        #expect(vm.selectedArticleId == nil)
    }

    @Test("selectPrevious does nothing on empty list")
    @MainActor
    func selectPreviousEmpty() {
        let vm = ArticleListViewModel()
        vm.selectArticle("a1")
        vm.selectPrevious(from: [])
        #expect(vm.selectedArticleId == "a1")
    }

    @Test("selectPrevious does nothing if current not found")
    @MainActor
    func selectPreviousNotFound() {
        let vm = ArticleListViewModel()
        vm.selectArticle("unknown")
        vm.selectPrevious(from: sampleIds)
        #expect(vm.selectedArticleId == "unknown")
    }

    // MARK: - Select Next Unread

    @Test("selectNextUnread finds next unread article")
    @MainActor
    func selectNextUnread() {
        let vm = ArticleListViewModel()
        let unread: Set<String> = ["a3", "a5"]
        vm.selectArticle("a1")
        vm.selectNextUnread(
            from: sampleIds, unreadIds: unread
        )
        #expect(vm.selectedArticleId == "a3")
    }

    @Test("selectNextUnread skips read articles")
    @MainActor
    func selectNextUnreadSkipsRead() {
        let vm = ArticleListViewModel()
        let unread: Set<String> = ["a4"]
        vm.selectArticle("a2")
        vm.selectNextUnread(
            from: sampleIds, unreadIds: unread
        )
        #expect(vm.selectedArticleId == "a4")
    }

    @Test("selectNextUnread wraps around to beginning")
    @MainActor
    func selectNextUnreadWraps() {
        let vm = ArticleListViewModel()
        let unread: Set<String> = ["a1"]
        vm.selectArticle("a3")
        vm.selectNextUnread(
            from: sampleIds, unreadIds: unread
        )
        #expect(vm.selectedArticleId == "a1")
    }

    @Test("selectNextUnread selects first unread with no selection")
    @MainActor
    func selectNextUnreadFromNone() {
        let vm = ArticleListViewModel()
        let unread: Set<String> = ["a2", "a4"]
        vm.selectNextUnread(
            from: sampleIds, unreadIds: unread
        )
        #expect(vm.selectedArticleId == "a2")
    }

    @Test("selectNextUnread does nothing when all read")
    @MainActor
    func selectNextUnreadAllRead() {
        let vm = ArticleListViewModel()
        vm.selectArticle("a1")
        vm.selectNextUnread(
            from: sampleIds, unreadIds: []
        )
        #expect(vm.selectedArticleId == "a1")
    }

    @Test("selectNextUnread does nothing on empty list")
    @MainActor
    func selectNextUnreadEmpty() {
        let vm = ArticleListViewModel()
        vm.selectNextUnread(
            from: [], unreadIds: ["a1"]
        )
        #expect(vm.selectedArticleId == nil)
    }

    // MARK: - Filter Toggle

    @Test("showUnreadOnly toggles correctly")
    @MainActor
    func toggleUnreadOnly() {
        let vm = ArticleListViewModel()
        #expect(!vm.showUnreadOnly)
        vm.showUnreadOnly = true
        #expect(vm.showUnreadOnly)
        vm.showUnreadOnly = false
        #expect(!vm.showUnreadOnly)
    }

    // MARK: - Loading State

    @Test("isLoading can be toggled")
    @MainActor
    func loadingState() {
        let vm = ArticleListViewModel()
        vm.isLoading = true
        #expect(vm.isLoading)
        vm.isLoading = false
        #expect(!vm.isLoading)
    }

    // MARK: - Mark All as Read

    @Test("markAllAsRead marks unread articles as read")
    @MainActor
    func markAllAsRead() throws {
        let context = CoreDataTestHelper.makeContext()
        let a1 = CDArticle.create(
            in: context,
            id: "a1",
            title: "One",
            link: "https://example.com/1",
            published: Date()
        )
        let a2 = CDArticle.create(
            in: context,
            id: "a2",
            title: "Two",
            link: "https://example.com/2",
            published: Date()
        )
        let a3 = CDArticle.create(
            in: context,
            id: "a3",
            title: "Three",
            link: "https://example.com/3",
            published: Date()
        )
        a2.isRead = true
        try context.save()

        let vm = ArticleListViewModel()
        vm.markAllAsRead([a1, a2, a3], in: context)

        #expect(a1.isRead)
        #expect(a2.isRead)
        #expect(a3.isRead)
    }

    @Test("markAllAsRead with empty array is no-op")
    @MainActor
    func markAllAsReadEmpty() throws {
        let context = CoreDataTestHelper.makeContext()
        let vm = ArticleListViewModel()
        vm.markAllAsRead([], in: context)
        // No crash, no error — just a no-op
    }

    @Test("markAllAsRead with all-already-read is no-op")
    @MainActor
    func markAllAsReadAlreadyRead() throws {
        let context = CoreDataTestHelper.makeContext()
        let a1 = CDArticle.create(
            in: context,
            id: "a1",
            title: "One",
            link: "https://example.com/1",
            published: Date()
        )
        a1.isRead = true
        try context.save()

        let vm = ArticleListViewModel()
        vm.markAllAsRead([a1], in: context)
        #expect(a1.isRead)
    }
}
