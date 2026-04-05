/// Namespace for HTTP header name and value constants used across all providers.
///
/// Centralising these strings eliminates typos and makes it easy to find every
/// place a particular header is used via Xcode's "Find Selected Symbol" action.
///
/// ```swift
/// request.setValue(
///     HTTPHeader.Value.bearer(apiKey),
///     forHTTPHeaderField: HTTPHeader.Name.authorization
/// )
/// ```
enum HTTPHeader {

    /// Standard and provider-specific HTTP header field names.
    enum Name {
        /// `"Content-Type"` — specifies the body media type.
        static let contentType      = "Content-Type"
        /// `"Authorization"` — carries bearer tokens for OpenAI and Grok.
        static let authorization    = "Authorization"
        /// `"x-api-key"` — Anthropic's custom API key header.
        static let apiKey           = "x-api-key"
        /// `"anthropic-version"` — required by Anthropic to select the API version.
        static let anthropicVersion = "anthropic-version"
    }

    /// Common HTTP header values and value-factory helpers.
    enum Value {
        /// `"application/json"` — used as the `Content-Type` for all provider requests.
        static let applicationJSON  = "application/json"

        /// Formats an API key as an OAuth 2.0 Bearer token string.
        ///
        /// - Parameter token: The raw API key string.
        /// - Returns: `"Bearer <token>"` ready to be set as the `Authorization` header value.
        static func bearer(_ token: String) -> String { "Bearer \(token)" }
    }
}
