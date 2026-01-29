//
//  KeychainService.swift
//  RSSReader
//
//  Created on 2026-01-28.
//

import Foundation
import Security

/// Manages secure storage of authentication tokens in the macOS Keychain.
final class KeychainService: KeychainServiceProtocol {
    // MARK: - Constants

    private let service = "com.rssreader.feedlyreader"
    private let account = "feedlyToken"

    // MARK: - KeychainServiceProtocol

    /// Saves an authentication token to the Keychain.
    /// If a token already exists, it is updated.
    /// - Parameter token: The authentication token to save.
    /// - Throws: `KeychainError` if the operation fails.
    func save(token: AuthenticationToken) throws {
        let data = try JSONEncoder().encode(token)

        // Check if token already exists
        if try retrieveToken() != nil {
            try update(data: data)
        } else {
            try add(data: data)
        }
    }

    /// Retrieves the stored authentication token from the Keychain.
    /// - Returns: The stored token, or `nil` if no token exists.
    /// - Throws: `KeychainError` if the operation fails.
    func retrieveToken() throws -> AuthenticationToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(
            query as CFDictionary,
            &result
        )

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.unexpectedData
            }
            return try JSONDecoder().decode(
                AuthenticationToken.self,
                from: data
            )
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }

    /// Deletes the stored authentication token from the Keychain.
    /// - Throws: `KeychainError` if the operation fails
    ///   (does not throw if no token exists).
    func deleteToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess
            || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    // MARK: - Private Helpers

    private func add(data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String:
                kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    private func update(data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}

// MARK: - KeychainError

/// Errors that can occur during Keychain operations.
enum KeychainError: LocalizedError, Equatable {
    case unexpectedData
    case unhandledError(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedData:
            return "Unexpected data format in Keychain"
        case .unhandledError(let status):
            let message = SecCopyErrorMessageString(
                status,
                nil
            ) as String? ?? "Unknown error"
            return "Keychain error: \(message) (\(status))"
        }
    }
}
