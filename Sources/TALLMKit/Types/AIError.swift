// Sources/TALLMKit/Types/AIError.swift
import Foundation

/// All errors that TALLMKit can throw during a `send` or `chat` call.
///
/// Catch this type to handle failures gracefully:
///
/// ```swift
/// do {
///     let response = try await sdk.send("Hello", model: .openAI(.gpt4oMini))
/// } catch AIError.invalidAPIKey {
///     print("Check your API key.")
/// } catch AIError.rateLimited(let retryAfter) {
///     print("Rate limited. Retry after \(retryAfter ?? 0)s")
/// } catch AIError.httpError(let status, let body) {
///     print("HTTP \(status): \(body)")
/// } catch {
///     print("Unexpected error: \(error)")
/// }
/// ```
public enum AIError: Error, Sendable {
    /// No provider has been configured for the model's provider type.
    ///
    /// Call `sdk.configure(.<provider>(key:))` before making a request for that provider.
    case providerNotConfigured

    /// The API key was rejected by the provider (HTTP 401).
    ///
    /// Verify the key is valid and has the required permissions.
    case invalidAPIKey

    /// A transport-level failure occurred before a response was received.
    ///
    /// The associated value is the underlying `URLError` or another `Sendable` error
    /// thrown by `URLSession`.
    case networkError(any Error & Sendable)

    /// The provider returned a non-2xx HTTP response that is not specifically
    /// handled by another case.
    ///
    /// - Parameters:
    ///   - status: The HTTP status code (e.g. `500`).
    ///   - body: The raw UTF-8 response body, useful for debugging provider error messages.
    case httpError(status: Int, body: String)

    /// The provider returned HTTP 429 (Too Many Requests).
    ///
    /// - Parameter retryAfter: The number of seconds to wait before retrying,
    ///   parsed from the `Retry-After` response header. `nil` if the header was absent.
    case rateLimited(retryAfter: TimeInterval?)

    /// The provider's response body could not be decoded into the expected type.
    ///
    /// The associated value is the underlying `DecodingError` or another error from
    /// `JSONDecoder`, giving full context about the malformed field or key.
    case decodingError(any Error & Sendable)
}
