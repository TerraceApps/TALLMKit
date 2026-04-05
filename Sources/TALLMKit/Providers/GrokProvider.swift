// Sources/TALLMKit/Providers/GrokProvider.swift
import Foundation

final class GrokProvider: AIProvider, Sendable {
    private static let baseURL = URL(string: "https://api.x.ai/v1")!
    private let apiKey: String
    private let httpClient: any HTTPClient

    init(apiKey: String, httpClient: any HTTPClient) {
        self.apiKey = apiKey
        self.httpClient = httpClient
    }

    func chat(model: String, messages: [Message], parameters: RequestParameters) async throws -> AIResponse {
        try await performOpenAIChat(
            baseURL: Self.baseURL,
            apiKey: apiKey,
            httpClient: httpClient,
            model: model,
            messages: messages,
            parameters: parameters
        )
    }
}
