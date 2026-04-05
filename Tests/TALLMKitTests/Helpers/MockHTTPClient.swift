// Tests/TALLMKitTests/Helpers/MockHTTPClient.swift
import Foundation
@testable import TALLMKit

/// A test double that captures the outgoing URLRequest and returns configurable data.
final class MockHTTPClient: HTTPClientProtocol, @unchecked Sendable {
    private(set) var capturedRequest: URLRequest?
    var responseData: Data
    var statusCode: Int
    var stubbedError: (any Error)?

    init(data: Data = Data(), statusCode: Int = 200) {
        self.responseData = data
        self.statusCode = statusCode
    }

    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequest = request
        if let error = stubbedError {
            throw error
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseData, response)
    }
}
