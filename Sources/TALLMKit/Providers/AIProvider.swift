// Sources/TALLMKit/Providers/AIProvider.swift
import Foundation

protocol AIProvider: Sendable {
    func chat(
        model: String,
        messages: [Message],
        parameters: RequestParameters
    ) async throws -> AIResponse
}

extension AIProvider {
    /// Maps common HTTP status codes to typed AIError values.
    func handleHTTPError(_ response: HTTPURLResponse, data: Data) throws -> Never {
        let body = String(data: data, encoding: .utf8) ?? ""
        switch response.statusCode {
        case 401:
            throw AIError.invalidAPIKey
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                .flatMap(TimeInterval.init)
            throw AIError.rateLimited(retryAfter: retryAfter)
        default:
            throw AIError.httpError(status: response.statusCode, body: body)
        }
    }
}
