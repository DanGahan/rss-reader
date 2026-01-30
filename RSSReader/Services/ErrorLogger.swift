//
//  ErrorLogger.swift
//  RSSReader
//
//  Created on 2026-01-30.
//

import Foundation
import os.log

/// Lightweight logging facade using OSLog for debug-time
/// error diagnostics.
enum ErrorLogger {
    private static let logger = Logger(
        subsystem: "com.rssreader.app",
        category: "errors"
    )

    /// Logs an `RSSReaderError` with optional context.
    static func log(
        _ error: RSSReaderError,
        context: String? = nil
    ) {
        let message = buildMessage(
            error: error, context: context
        )
        logger.error("\(message, privacy: .public)")
    }

    /// Logs a generic `Error` with optional context.
    static func log(
        _ error: Error,
        context: String? = nil
    ) {
        let message = buildMessage(
            error: error, context: context
        )
        logger.error("\(message, privacy: .public)")
    }

    /// Logs an informational message.
    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    // MARK: - Private

    private static func buildMessage(
        error: Error,
        context: String?
    ) -> String {
        var parts = [
            error.localizedDescription
        ]
        if let context {
            parts.insert("[\(context)]", at: 0)
        }
        return parts.joined(separator: " ")
    }
}
