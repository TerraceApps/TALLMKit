// Sources/TALLMKit/Providers/AnthropicProvider.swift
import Foundation

final class AnthropicProvider: AIProvider, Sendable {
    private static let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiKey: String
    private let httpClient: any HTTPClientProtocol

    init(apiKey: String, httpClient: any HTTPClientProtocol) {
        self.apiKey = apiKey
        self.httpClient = httpClient
    }

    func chat(
        model: String,
        messages: [Message],
        parameters: RequestParameters
    ) async throws -> AIResponse {
        var request = URLRequest(url: Self.baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Anthropic requires system messages in a separate top-level field
        let systemContent = messages
            .filter { $0.role == .system }
            .map(\.content)
            .joined(separator: "\n")
        let chatMessages = messages.filter { $0.role != .system }

        let body = AnthropicRequest(
            model: model,
            messages: chatMessages.map { AnthropicRequest.Msg(role: $0.role.rawValue, content: $0.content) },
            system: systemContent.isEmpty ? nil : systemContent,
            maxTokens: parameters.maxTokens ?? 1024,
            temperature: parameters.temperature,
            topP: parameters.topP
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, HTTPURLResponse)
        do {
            (data, response) = try await httpClient.perform(request)
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.networkError(error)
        }

        guard (200..<300).contains(response.statusCode) else {
            try handleHTTPError(response, data: data)
        }

        do {
            let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            let text = decoded.content
                .filter { $0.type == "text" }
                .compactMap(\.text)
                .joined()
            guard !text.isEmpty else {
                throw AIError.decodingError(DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "No text content in response")
                ))
            }
            let usage = AIResponse.TokenUsage(
                inputTokens: decoded.usage.inputTokens,
                outputTokens: decoded.usage.outputTokens,
                totalTokens: decoded.usage.inputTokens + decoded.usage.outputTokens
            )
            return AIResponse(text: text, model: model, usage: usage)
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.decodingError(error)
        }
    }
}

// MARK: – Wire types

private struct AnthropicRequest: Encodable {
    struct Msg: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Msg]
    let system: String?
    let maxTokens: Int
    let temperature: Double?
    let topP: Double?

    enum CodingKeys: String, CodingKey {
        case model, messages, system, temperature
        case maxTokens = "max_tokens"
        case topP = "top_p"
    }
}

private struct AnthropicResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    struct Usage: Decodable {
        let inputTokens: Int
        let outputTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    let content: [ContentBlock]
    let usage: Usage
}
