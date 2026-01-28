//
//  FeedlyUserTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-28.
//

import Foundation
import Testing
@testable import RSSReader

@Suite("FeedlyUser Tests")
struct FeedlyUserTests {

    // MARK: - Display Name Tests

    @Test("Display name returns fullName when available")
    func displayNameReturnsFullNameWhenAvailable() {
        let user = FeedlyUser(
            id: "user123",
            email: "test@example.com",
            fullName: "John Doe",
            picture: nil,
            givenName: "John",
            familyName: "Doe",
            locale: "en_US"
        )
        #expect(user.displayName == "John Doe")
    }

    @Test("Display name falls back to email when fullName is nil")
    func displayNameFallsBackToEmail() {
        let user = FeedlyUser(
            id: "user123",
            email: "test@example.com",
            fullName: nil,
            picture: nil,
            givenName: nil,
            familyName: nil,
            locale: nil
        )
        #expect(user.displayName == "test@example.com")
    }

    // MARK: - Codable Tests

    @Test("User decodes from full JSON")
    func userDecodingFromJSON() throws {
        let json = """
        {
            "id": "user123",
            "email": "test@example.com",
            "fullName": "John Doe",
            "picture": "https://example.com/avatar.png",
            "givenName": "John",
            "familyName": "Doe",
            "locale": "en_US"
        }
        """

        let data = json.data(using: .utf8)!
        let user = try JSONDecoder().decode(FeedlyUser.self, from: data)

        #expect(user.id == "user123")
        #expect(user.email == "test@example.com")
        #expect(user.fullName == "John Doe")
        #expect(
            user.picture == URL(string: "https://example.com/avatar.png")
        )
        #expect(user.givenName == "John")
        #expect(user.familyName == "Doe")
        #expect(user.locale == "en_US")
    }

    @Test("User decodes from minimal JSON")
    func userDecodingWithMinimalJSON() throws {
        let json = """
        {
            "id": "user123",
            "email": "test@example.com"
        }
        """

        let data = json.data(using: .utf8)!
        let user = try JSONDecoder().decode(FeedlyUser.self, from: data)

        #expect(user.id == "user123")
        #expect(user.email == "test@example.com")
        #expect(user.fullName == nil)
        #expect(user.picture == nil)
    }

    @Test("User roundtrip encode/decode")
    func userEncoding() throws {
        let user = FeedlyUser(
            id: "user123",
            email: "test@example.com",
            fullName: "John Doe",
            picture: URL(string: "https://example.com/avatar.png"),
            givenName: "John",
            familyName: "Doe",
            locale: "en_US"
        )

        let data = try JSONEncoder().encode(user)
        let decoded = try JSONDecoder().decode(
            FeedlyUser.self,
            from: data
        )

        #expect(user == decoded)
    }

    // MARK: - Equatable Tests

    @Test("Equal users are equal")
    func userEquality() {
        let user1 = FeedlyUser(
            id: "user123",
            email: "test@example.com",
            fullName: "John Doe",
            picture: nil,
            givenName: nil,
            familyName: nil,
            locale: nil
        )
        let user2 = FeedlyUser(
            id: "user123",
            email: "test@example.com",
            fullName: "John Doe",
            picture: nil,
            givenName: nil,
            familyName: nil,
            locale: nil
        )
        #expect(user1 == user2)
    }

    @Test("Different users are not equal")
    func userInequality() {
        let user1 = FeedlyUser(
            id: "user123",
            email: "test@example.com",
            fullName: nil,
            picture: nil,
            givenName: nil,
            familyName: nil,
            locale: nil
        )
        let user2 = FeedlyUser(
            id: "user456",
            email: "other@example.com",
            fullName: nil,
            picture: nil,
            givenName: nil,
            familyName: nil,
            locale: nil
        )
        #expect(user1 != user2)
    }
}
