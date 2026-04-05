// Sources/TALLMKit/Providers/AIProvider.swift
import Foundation

/// Internal contract every LLM provider must satisfy.
///
/// Each provider (OpenAI, Anthropic, Grok, Gemini) implements this protocol.
/// `TALLMKit` stores providers in a dictionary keyed by `ProviderType` and
/// dispatches requests to the correct implementation at call time.
///
/// The protocol is intentionally kept non-generic so the dictionary can hold
/// heterogeneous provider instances as `any AIProvider`.
protocol AIProvider: Sendable {
    /// Sends a chat request to the provider and returns the model's response.
    ///
    /// - Parameters:
    ///   - model: The provider-specific model identifier string, e.g. `"gpt-4o-mini"`.
    ///   - messages: The full conversation history in chronological order.
    ///   - parameters: Sampling parameters, tool definitions, and output constraints.
    /// - Returns: An `AIResponse` containing the model's reply, token usage, and
    ///   any tool calls the model wants to invoke.
    /// - Throws: `AIError` on network failures, authentication errors, HTTP errors,
    ///   or response decoding failures.
    func chat(
        model: String,
        messages: [Message],
        parameters: RequestParameters
    ) async throws -> AIResponse
}

extension AIProvider {
    /// Translates a non-2xx `HTTPURLResponse` into a typed `AIError` and throws it.
    ///
    /// - `401` → `AIError.invalidAPIKey`
    /// - `429` → `AIError.rateLimited(retryAfter:)`, parsing the `Retry-After` header when present
    /// - Any other code → `AIError.httpError(status:body:)`
    ///
    /// - Parameters:
    ///   - response: The HTTP response with a non-2xx status code.
    ///   - data: The response body, decoded as UTF-8 and included in the error message.
    /// - Returns: Never — always throws.
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
