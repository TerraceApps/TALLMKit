import Foundation

/// Describes a single HTTP endpoint — its base URL, path, method, headers and query items.
///
/// Conform to this protocol to define a provider-specific endpoint. The default
/// extension supplies sensible defaults for optional properties and a ready-to-use
/// `urlRequest()` implementation so conforming types need only declare what differs.
///
/// ```swift
/// struct MyEndpoint: Endpoint {
///     let apiKey: String
///     var baseURL: String { "https://api.example.com/v1" }
///     var path:    String { "chat/completions" }
///     var method:  HTTPMethod { .post }
///     var headers: [String: String] {
///         [HTTPHeader.Name.authorization: HTTPHeader.Value.bearer(apiKey)]
///     }
/// }
///
/// var request = try MyEndpoint(apiKey: "key").urlRequest()
/// ```
protocol Endpoint {
    /// The scheme + host + base path of the API, e.g. `"https://api.openai.com/v1"`.
    var baseURL: String { get }

    /// The path component appended to `baseURL`, e.g. `"chat/completions"`.
    /// Defaults to an empty string (no additional path segment).
    var path: String { get }

    /// The HTTP verb for this endpoint. Defaults to `.post`.
    var method: HTTPMethod { get }

    /// HTTP headers to attach to every request built from this endpoint.
    var headers: [String: String] { get }

    /// URL query parameters appended to the final URL, e.g. `?key=<apiKey>`.
    /// Defaults to an empty array (no query items).
    var queryItems: [URLQueryItem] { get }
}

extension Endpoint {
    /// Default path: empty string (no extra path segment beyond `baseURL`).
    var path: String { "" }

    /// Default query items: none.
    var queryItems: [URLQueryItem] { [] }

    /// Constructs a `URLRequest` from the endpoint's properties.
    ///
    /// - Parses `baseURL` via `URLComponents`.
    /// - Appends `path` with `NSString.appendingPathComponent` when non-empty.
    /// - Merges `queryItems` into the URL's query string when non-empty.
    /// - Sets `httpMethod` and all `headers` on the resulting `URLRequest`.
    ///
    /// - Throws: `AIError.httpError` if `baseURL` cannot be parsed or the
    ///   final URL cannot be constructed.
    func urlRequest() throws -> URLRequest {
        guard var components = URLComponents(string: baseURL) else {
            throw AIError.httpError(status: -1, body: "Invalid baseURL: \(baseURL)")
        }
        if !path.isEmpty {
            components.path = (components.path as NSString).appendingPathComponent(path)
        }
        if !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }
        guard let url = components.url else {
            throw AIError.httpError(status: -1, body: "Could not construct URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }
}
