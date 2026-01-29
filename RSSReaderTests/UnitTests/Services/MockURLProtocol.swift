//
//  MockURLProtocol.swift
//  RSSReaderTests
//
//  Created on 2026-01-28.
//

import Foundation

/// A mock URL protocol for intercepting and stubbing network requests.
class MockURLProtocol: URLProtocol {
    /// Handler to provide mock responses for requests.
    nonisolated(unsafe) static var requestHandler: (
        (URLRequest) throws -> (HTTPURLResponse, Data?)
    )?

    /// Records all requests made through this protocol.
    nonisolated(unsafe) static var capturedRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.capturedRequests.append(request)

        guard let handler = Self.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    /// Resets all captured data and handlers.
    static func reset() {
        requestHandler = nil
        capturedRequests = []
    }
}
