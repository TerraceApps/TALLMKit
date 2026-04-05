import Foundation

/// Abstracts the HTTP transport layer used by all providers.
///
/// `HTTPClient` is an internal protocol. The production implementation
/// (`HTTPClientImpl`) is created inside `TALLMKit.init()`. Tests inject a
/// `MockHTTPClient` via the internal `TALLMKit.init(httpClient:)` initialiser.
protocol HTTPClient: Sendable {
    /// Executes a `URLRequest` and returns the raw response body and metadata.
    ///
    /// - Parameter request: The fully-constructed `URLRequest` to send.
    /// - Returns: A tuple of the response body `Data` and the `HTTPURLResponse`.
    /// - Throws: `AIError.networkError` on transport failures;
    ///   re-throws `AIError` values from the underlying session unchanged.
    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Production HTTP client backed by `URLSession`.
///
/// Uses `URLSession.shared` by default. A custom session can be injected
/// for testing or configuration purposes (e.g. custom timeout, caching policy).
final class HTTPClientImpl: HTTPClient, Sendable {
    private let session: URLSession

    /// Creates a new client.
    ///
    /// - Parameter session: The `URLSession` to use for all requests.
    ///   Defaults to `URLSession.shared`.
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Sends `request` using the underlying `URLSession`.
    ///
    /// - Returns: `(Data, HTTPURLResponse)` on success.
    /// - Throws: `AIError.networkError` if the response is not an
    ///   `HTTPURLResponse` or if a non-`AIError` transport error occurs.
    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AIError.networkError(URLError(.badServerResponse))
            }
            return (data, http)
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.networkError(error)
        }
    }
}
