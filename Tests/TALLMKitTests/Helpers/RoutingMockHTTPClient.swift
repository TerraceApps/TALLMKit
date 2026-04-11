// Tests/TALLMKitTests/Helpers/RoutingMockHTTPClient.swift
import Foundation
@testable import TALLMKit

/// A test double that routes each request through a caller-supplied handler.
/// Use this when a single test needs different responses per provider URL.
final class RoutingMockHTTPClient: HTTPClient, @unchecked Sendable {
    let handler: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    init(handler: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)) {
        self.handler = handler
    }

    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await handler(request)
    }
}
