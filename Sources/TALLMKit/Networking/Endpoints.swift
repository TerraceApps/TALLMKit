import Foundation

/// Namespace for all provider-specific `Endpoint` implementations.
///
/// Each nested struct encodes the base URL, path, HTTP method, and authentication
/// headers for one provider's chat API. Providers instantiate the appropriate
/// struct and call `urlRequest()` to obtain a ready-to-use `URLRequest`.
///
/// ```swift
/// // Inside OpenAIProvider:
/// var request = try Endpoints.OpenAI(apiKey: apiKey).urlRequest()
///
/// // Inside GeminiProvider (model-specific path):
/// var request = try Endpoints.Gemini(apiKey: apiKey, model: model).urlRequest()
/// ```
enum Endpoints {

    /// Endpoint for the OpenAI Chat Completions API.
    ///
    /// - Base URL: `https://api.openai.com/v1`
    /// - Path: `chat/completions`
    /// - Auth: `Authorization: Bearer <apiKey>`
    struct OpenAI: Endpoint {
        /// The OpenAI API key used in the `Authorization` header.
        let apiKey: String

        var baseURL: String { "https://api.openai.com/v1" }
        var path:    String { "chat/completions" }
        var method:  HTTPMethod { .post }
        var headers: [String: String] {
            [
                HTTPHeader.Name.contentType:   HTTPHeader.Value.applicationJSON,
                HTTPHeader.Name.authorization: HTTPHeader.Value.bearer(apiKey)
            ]
        }
    }

    /// Endpoint for the xAI Grok Chat Completions API.
    ///
    /// Grok uses the same OpenAI-compatible wire format but routes to
    /// `https://api.x.ai/v1`.
    ///
    /// - Base URL: `https://api.x.ai/v1`
    /// - Path: `chat/completions`
    /// - Auth: `Authorization: Bearer <apiKey>`
    struct Grok: Endpoint {
        /// The xAI API key used in the `Authorization` header.
        let apiKey: String

        var baseURL: String { "https://api.x.ai/v1" }
        var path:    String { "chat/completions" }
        var method:  HTTPMethod { .post }
        var headers: [String: String] {
            [
                HTTPHeader.Name.contentType:   HTTPHeader.Value.applicationJSON,
                HTTPHeader.Name.authorization: HTTPHeader.Value.bearer(apiKey)
            ]
        }
    }

    /// Endpoint for the Anthropic Messages API.
    ///
    /// Authentication uses the custom `x-api-key` header together with the
    /// mandatory `anthropic-version` header (pinned to `2023-06-01`).
    ///
    /// - Base URL: `https://api.anthropic.com/v1/messages`
    /// - Path: none (the base URL is the full endpoint)
    /// - Auth: `x-api-key: <apiKey>` + `anthropic-version: 2023-06-01`
    struct Anthropic: Endpoint {
        /// The Anthropic API key used in the `x-api-key` header.
        let apiKey: String

        var baseURL: String { "https://api.anthropic.com/v1/messages" }
        var method:  HTTPMethod { .post }
        var headers: [String: String] {
            [
                HTTPHeader.Name.contentType:      HTTPHeader.Value.applicationJSON,
                HTTPHeader.Name.apiKey:           apiKey,
                HTTPHeader.Name.anthropicVersion: "2023-06-01"
            ]
        }
    }

    /// Endpoint for the Google Gemini `generateContent` API.
    ///
    /// The model name is embedded in the path and the API key is passed as a
    /// query parameter rather than a header.
    ///
    /// - Base URL: `https://generativelanguage.googleapis.com/v1beta/models`
    /// - Path: `<model>:generateContent`
    /// - Auth: `?key=<apiKey>` query parameter
    struct Gemini: Endpoint {
        /// The Google AI API key passed as the `key` query parameter.
        let apiKey: String

        /// The Gemini model identifier, e.g. `"gemini-2.0-flash"`.
        /// Determines the path component `<model>:generateContent`.
        let model: String

        var baseURL: String { "https://generativelanguage.googleapis.com/v1beta/models" }
        var path:    String { "\(model):generateContent" }
        var method:  HTTPMethod { .post }
        var headers: [String: String] {
            [HTTPHeader.Name.contentType: HTTPHeader.Value.applicationJSON]
        }
        var queryItems: [URLQueryItem] {
            [URLQueryItem(name: "key", value: apiKey)]
        }
    }
}
