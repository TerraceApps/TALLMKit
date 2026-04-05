// Sources/TALLMKit/Types/AIError.swift
import Foundation

public enum AIError: Error, Sendable {
    /// No provider has been configured for the model's provider type.
    case providerNotConfigured
    /// The API key was rejected (HTTP 401).
    case invalidAPIKey
    /// A network-layer failure (URLError, etc.).
    case networkError(any Error & Sendable)
    /// A non-2xx HTTP response.
    case httpError(status: Int, body: String)
    /// HTTP 429. retryAfter is the Retry-After header value in seconds, if present.
    case rateLimited(retryAfter: TimeInterval?)
    /// The provider's response body could not be decoded.
    case decodingError(any Error & Sendable)
}
