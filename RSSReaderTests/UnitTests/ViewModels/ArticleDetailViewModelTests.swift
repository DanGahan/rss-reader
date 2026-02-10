//
//  ArticleDetailViewModelTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-30.
//

import CoreData
import Foundation
import Testing
@testable import RSSReader

@Suite("ArticleDetailViewModel Tests")
struct ArticleDetailViewModelTests {
    // MARK: - Mark as Read

    @Test("markAsRead sets isRead to true")
    @MainActor
    func markAsRead() throws {
        let context = CoreDataTestHelper.makeContext()
        let article = CDArticle.create(
            in: context,
            id: "a1",
            title: "Test",
            link: "https://example.com",
            published: Date()
        )
        try context.save()
        #expect(!article.isRead)

        let vm = ArticleDetailViewModel()
        vm.markAsRead(article, in: context)
        #expect(article.isRead)
    }

    @Test("markAsRead does not save if already read")
    @MainActor
    func markAsReadAlreadyRead() throws {
        let context = CoreDataTestHelper.makeContext()
        let article = CDArticle.create(
            in: context,
            id: "a1",
            title: "Test",
            link: "https://example.com",
            published: Date()
        )
        article.isRead = true
        try context.save()

        let vm = ArticleDetailViewModel()
        vm.markAsRead(article, in: context)
        // Should still be read, no error thrown
        #expect(article.isRead)
    }

    // MARK: - Plain Text Content

    @Test("plainTextContent prefers content over summary")
    @MainActor
    func plainTextPrefersContent() {
        let context = CoreDataTestHelper.makeContext()
        let article = CDArticle.create(
            in: context,
            id: "a1",
            title: "Test",
            link: "https://example.com",
            published: Date()
        )
        article.content = "Full content here"
        article.summary = "Short summary"

        let vm = ArticleDetailViewModel()
        let text = vm.plainTextContent(for: article)
        #expect(text == "Full content here")
    }

    @Test("plainTextContent falls back to summary")
    @MainActor
    func plainTextFallsBackToSummary() {
        let context = CoreDataTestHelper.makeContext()
        let article = CDArticle.create(
            in: context,
            id: "a1",
            title: "Test",
            link: "https://example.com",
            published: Date()
        )
        article.summary = "Just the summary"

        let vm = ArticleDetailViewModel()
        let text = vm.plainTextContent(for: article)
        #expect(text == "Just the summary")
    }

    @Test("plainTextContent returns empty when no content")
    @MainActor
    func plainTextEmpty() {
        let context = CoreDataTestHelper.makeContext()
        let article = CDArticle.create(
            in: context,
            id: "a1",
            title: "Test",
            link: "https://example.com",
            published: Date()
        )

        let vm = ArticleDetailViewModel()
        let text = vm.plainTextContent(for: article)
        #expect(text.isEmpty)
    }

    @Test("plainTextContent strips HTML tags")
    @MainActor
    func plainTextStripsHTML() {
        let context = CoreDataTestHelper.makeContext()
        let article = CDArticle.create(
            in: context,
            id: "a1",
            title: "Test",
            link: "https://example.com",
            published: Date()
        )
        article.content = "<p>Hello <b>world</b></p>"

        let vm = ArticleDetailViewModel()
        let text = vm.plainTextContent(for: article)
        #expect(!text.contains("<"))
        #expect(text.contains("Hello"))
        #expect(text.contains("world"))
    }

    // MARK: - Date Formatting

    @Test("formattedDate returns non-empty string")
    @MainActor
    func formattedDateNotEmpty() {
        let vm = ArticleDetailViewModel()
        let result = vm.formattedDate(Date())
        #expect(!result.isEmpty)
    }

    @Test("formattedDate is deterministic for same date")
    @MainActor
    func formattedDateDeterministic() {
        let vm = ArticleDetailViewModel()
        let date = Date(
            timeIntervalSinceReferenceDate: 0
        )
        let first = vm.formattedDate(date)
        let second = vm.formattedDate(date)
        #expect(first == second)
    }

    // MARK: - Open in Safari

    @Test("openInSafari returns false for empty string")
    @MainActor
    func openInSafariEmptyString() {
        let vm = ArticleDetailViewModel()
        #expect(!vm.openInSafari(urlString: ""))
    }

    @Test("openInSafari returns false for invalid URL")
    @MainActor
    func openInSafariInvalidURL() {
        let vm = ArticleDetailViewModel()
        #expect(!vm.openInSafari(urlString: "not a url"))
    }

    @Test("openInSafari returns false for ftp scheme")
    @MainActor
    func openInSafariFtpScheme() {
        let vm = ArticleDetailViewModel()
        #expect(
            !vm.openInSafari(
                urlString: "ftp://example.com/file"
            )
        )
    }

    @Test("openInSafari returns true for valid https URL")
    @MainActor
    func openInSafariValidHttps() {
        let vm = ArticleDetailViewModel()
        #expect(
            vm.openInSafari(
                urlString: "https://example.com"
            )
        )
    }

    @Test("showOpenedToast is false on init")
    @MainActor
    func toastInitialState() {
        let vm = ArticleDetailViewModel()
        #expect(!vm.showOpenedToast)
    }

    // MARK: - Attributed Content

    @Test("attributedContent returns non-empty for HTML content")
    @MainActor
    func attributedContentNonEmpty() {
        let context = CoreDataTestHelper.makeContext()
        let article = CDArticle.create(
            in: context,
            id: "a1",
            title: "Test",
            link: "https://example.com",
            published: Date()
        )
        article.content = "<p>Hello <strong>world</strong></p>"

        let vm = ArticleDetailViewModel()
        let result = vm.attributedContent(for: article)
        #expect(result.length > 0)
        #expect(result.string.contains("Hello"))
        #expect(result.string.contains("world"))
    }

    @Test("attributedContent sanitizes script tags")
    @MainActor
    func attributedContentSanitizes() {
        let context = CoreDataTestHelper.makeContext()
        let article = CDArticle.create(
            in: context,
            id: "a1",
            title: "Test",
            link: "https://example.com",
            published: Date()
        )
        article.content = "<p>Safe</p><script>alert('xss')</script>"

        let vm = ArticleDetailViewModel()
        let result = vm.attributedContent(for: article)
        #expect(!result.string.contains("alert"))
        #expect(!result.string.contains("xss"))
        #expect(result.string.contains("Safe"))
    }

    @Test("attributedContent returns empty for nil content")
    @MainActor
    func attributedContentEmpty() {
        let context = CoreDataTestHelper.makeContext()
        let article = CDArticle.create(
            in: context,
            id: "a1",
            title: "Test",
            link: "https://example.com",
            published: Date()
        )

        let vm = ArticleDetailViewModel()
        let result = vm.attributedContent(for: article)
        #expect(result.length == 0)
    }

    @Test("attributedContent prefers content over summary")
    @MainActor
    func attributedContentPrefersContent() {
        let context = CoreDataTestHelper.makeContext()
        let article = CDArticle.create(
            in: context,
            id: "a1",
            title: "Test",
            link: "https://example.com",
            published: Date()
        )
        article.content = "Full content"
        article.summary = "Summary only"

        let vm = ArticleDetailViewModel()
        let result = vm.attributedContent(for: article)
        #expect(result.string.contains("Full content"))
        #expect(!result.string.contains("Summary only"))
    }

    @Test("attributedContent falls back to summary")
    @MainActor
    func attributedContentFallsBackToSummary() {
        let context = CoreDataTestHelper.makeContext()
        let article = CDArticle.create(
            in: context,
            id: "a1",
            title: "Test",
            link: "https://example.com",
            published: Date()
        )
        article.summary = "Summary text here"

        let vm = ArticleDetailViewModel()
        let result = vm.attributedContent(for: article)
        #expect(result.string.contains("Summary text here"))
    }
}
