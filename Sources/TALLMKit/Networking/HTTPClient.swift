// Sources/TALLMKit/Networking/HTTPClient.swift
import Foundation

protocol HTTPClientProtocol: Sendable {
    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

final class HTTPClient: HTTPClientProtocol, Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

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
