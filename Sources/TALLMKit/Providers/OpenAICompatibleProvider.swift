// Sources/TALLMKit/Providers/OpenAICompatibleProvider.swift
import Foundation

final class OpenAICompatibleProvider: AIProvider, Sendable {
    private let baseURL: URL
    private let apiKey: String
    private let httpClient: any HTTPClientProtocol

    init(baseURL: URL, apiKey: String, httpClient: any HTTPClientProtocol) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.httpClient = httpClient
    }

    func chat(
        model: String,
        messages: [Message],
        parameters: RequestParameters
    ) async throws -> AIResponse {
        let url = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = OpenAIRequest(
            model: model,
            messages: messages.map { OpenAIRequest.OpenAIMessage(role: $0.role.rawValue, content: $0.content) },
            temperature: parameters.temperature,
            maxTokens: parameters.maxTokens,
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
            let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let text = decoded.choices.first?.message.content else {
                throw AIError.decodingError(DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "No choices in response")
                ))
            }
            let usage = decoded.usage.map {
                AIResponse.TokenUsage(
                    inputTokens: $0.promptTokens,
                    outputTokens: $0.completionTokens,
                    totalTokens: $0.totalTokens
                )
            }
            return AIResponse(text: text, model: model, usage: usage)
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.decodingError(error)
        }
    }
}

// MARK: – Codable wire types (internal)

private struct OpenAIRequest: Encodable {
    struct OpenAIMessage: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double?
    let maxTokens: Int?
    let topP: Double?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
        case topP = "top_p"
    }
}

private struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        struct Msg: Decodable {
            let role: String
            let content: String
        }
        let message: Msg
    }

    struct Usage: Decodable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }

    let choices: [Choice]
    let usage: Usage?
}
