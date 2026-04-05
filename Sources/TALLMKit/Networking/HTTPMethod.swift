/// Represents an HTTP request method.
///
/// The `rawValue` is the uppercase string written into `URLRequest.httpMethod`.
///
/// ```swift
/// request.httpMethod = HTTPMethod.post.rawValue  // → "POST"
/// ```
enum HTTPMethod: String {
    /// `GET` — retrieve a resource without side effects.
    case get  = "GET"
    /// `POST` — submit data or trigger an action; used by all provider chat APIs.
    case post = "POST"
}
