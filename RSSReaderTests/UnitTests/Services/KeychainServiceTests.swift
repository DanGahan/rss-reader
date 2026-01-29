//
//  KeychainServiceTests.swift
//  RSSReaderTests
//
//  Created on 2026-01-28.
//

import Foundation
import Testing
@testable import RSSReader

@Suite("KeychainService Tests", .serialized)
struct KeychainServiceTests {
    // MARK: - Test Helpers

    private func makeToken(
        accessToken: String = "test-access-token",
        refreshToken: String? = "test-refresh-token"
    ) -> AuthenticationToken {
        AuthenticationToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: "Bearer",
            expiresIn: 3600,
            scope: "subscriptions",
            createdAt: Date(timeIntervalSince1970: 1706400000)
        )
    }

    // MARK: - MockKeychainService Tests

    @Test("Save and retrieve token round-trip")
    func saveAndRetrieve() throws {
        let service = MockKeychainService()
        let token = makeToken()

        try service.save(token: token)
        let retrieved = try service.retrieveToken()

        #expect(retrieved != nil)
        #expect(retrieved?.accessToken == "test-access-token")
        #expect(retrieved?.refreshToken == "test-refresh-token")
        #expect(retrieved?.tokenType == "Bearer")
        #expect(retrieved?.expiresIn == 3600)
        #expect(retrieved?.scope == "subscriptions")
    }

    @Test("Retrieve returns nil when no token stored")
    func retrieveReturnsNilWhenEmpty() throws {
        let service = MockKeychainService()
        let token = try service.retrieveToken()
        #expect(token == nil)
    }

    @Test("Delete removes stored token")
    func deleteRemovesToken() throws {
        let service = MockKeychainService()
        let token = makeToken()

        try service.save(token: token)
        #expect(try service.retrieveToken() != nil)

        try service.deleteToken()
        #expect(try service.retrieveToken() == nil)
    }

    @Test("Delete succeeds when no token exists")
    func deleteSucceedsWhenEmpty() throws {
        let service = MockKeychainService()
        // Should not throw
        try service.deleteToken()
    }

    @Test("Save overwrites existing token")
    func saveOverwritesExistingToken() throws {
        let service = MockKeychainService()
        let token1 = makeToken(accessToken: "token-1")
        let token2 = makeToken(accessToken: "token-2")

        try service.save(token: token1)
        try service.save(token: token2)

        let retrieved = try service.retrieveToken()
        #expect(retrieved?.accessToken == "token-2")
    }

    @Test("Token encodes and decodes correctly via JSON")
    func tokenCodableRoundTrip() throws {
        let token = makeToken()
        let data = try JSONEncoder().encode(token)
        let decoded = try JSONDecoder().decode(
            AuthenticationToken.self,
            from: data
        )

        #expect(decoded.accessToken == token.accessToken)
        #expect(decoded.refreshToken == token.refreshToken)
        #expect(decoded.tokenType == token.tokenType)
        #expect(decoded.expiresIn == token.expiresIn)
        #expect(decoded.scope == token.scope)
        #expect(decoded.createdAt == token.createdAt)
    }

    @Test("Token with nil refresh token saves and retrieves")
    func tokenWithNilRefreshToken() throws {
        let service = MockKeychainService()
        let token = makeToken(refreshToken: nil)

        try service.save(token: token)
        let retrieved = try service.retrieveToken()

        #expect(retrieved?.accessToken == "test-access-token")
        #expect(retrieved?.refreshToken == nil)
    }

    @Test("Token expiration is calculated correctly")
    func tokenExpiration() {
        let token = AuthenticationToken(
            accessToken: "test",
            expiresIn: 3600,
            createdAt: Date(timeIntervalSince1970: 0)
        )

        #expect(
            token.expirationDate ==
            Date(timeIntervalSince1970: 3600)
        )
        #expect(token.isExpired == true)
    }

    @Test("Non-expired token reports correctly")
    func nonExpiredToken() {
        let token = AuthenticationToken(
            accessToken: "test",
            expiresIn: 999_999,
            createdAt: Date()
        )
        #expect(token.isExpired == false)
    }
}

// MARK: - KeychainError Tests

@Suite("KeychainError Tests")
struct KeychainErrorTests {
    @Test("Unexpected data error description")
    func unexpectedDataDescription() {
        let error = KeychainError.unexpectedData
        #expect(
            error.errorDescription ==
            "Unexpected data format in Keychain"
        )
    }

    @Test("Unhandled error includes status code")
    func unhandledErrorDescription() {
        let error = KeychainError.unhandledError(status: -25300)
        let description = error.errorDescription ?? ""
        #expect(description.contains("-25300"))
    }

    @Test("Errors are equatable")
    func errorsAreEquatable() {
        let error1 = KeychainError.unexpectedData
        let error2 = KeychainError.unexpectedData
        #expect(error1 == error2)

        let error3 = KeychainError.unhandledError(status: -1)
        let error4 = KeychainError.unhandledError(status: -1)
        #expect(error3 == error4)

        #expect(error1 != error3)
    }
}

// MARK: - Mock Keychain Service

/// In-memory mock of KeychainService for testing without
/// requiring actual Keychain access.
final class MockKeychainService: KeychainServiceProtocol {
    private var storedData: Data?
    var shouldThrowOnSave = false
    var shouldThrowOnRetrieve = false
    var shouldThrowOnDelete = false

    func save(token: AuthenticationToken) throws {
        if shouldThrowOnSave {
            throw KeychainError.unhandledError(status: -1)
        }
        storedData = try JSONEncoder().encode(token)
    }

    func retrieveToken() throws -> AuthenticationToken? {
        if shouldThrowOnRetrieve {
            throw KeychainError.unhandledError(status: -1)
        }
        guard let data = storedData else { return nil }
        return try JSONDecoder().decode(
            AuthenticationToken.self,
            from: data
        )
    }

    func deleteToken() throws {
        if shouldThrowOnDelete {
            throw KeychainError.unhandledError(status: -1)
        }
        storedData = nil
    }
}
