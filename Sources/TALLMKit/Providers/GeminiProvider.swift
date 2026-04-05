// Sources/TALLMKit/Providers/GeminiProvider.swift
import Foundation

final class GeminiProvider: AIProvider, Sendable {
    private static let baseURLString = "https://generativelanguage.googleapis.com/v1beta/models"
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
        let urlString = "\(Self.baseURLString)/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw AIError.httpError(status: 0, body: "Invalid URL for model \(model)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // System messages go to systemInstruction; others become contents
        let systemText = messages
            .filter { $0.role == .system }
            .map(\.content)
            .joined(separator: "\n")
        let chatMessages = messages.filter { $0.role != .system }

        let systemInstruction: GeminiRequest.SystemInstruction? = systemText.isEmpty
            ? nil
            : GeminiRequest.SystemInstruction(parts: [GeminiPart(text: systemText)])

        let contents = chatMessages.map { msg in
            // Gemini uses "model" instead of "assistant"
            let role = msg.role == .assistant ? "model" : msg.role.rawValue
            return GeminiContent(role: role, parts: [GeminiPart(text: msg.content)])
        }

        let genConfig: GeminiRequest.GenerationConfig? = {
            guard parameters.temperature != nil || parameters.maxTokens != nil || parameters.topP != nil else { return nil }
            return GeminiRequest.GenerationConfig(
                temperature: parameters.temperature,
                maxOutputTokens: parameters.maxTokens,
                topP: parameters.topP
            )
        }()

        let body = GeminiRequest(
            contents: contents,
            systemInstruction: systemInstruction,
            generationConfig: genConfig
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
            let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
            let text = decoded.candidates.first?.content.parts
                .compactMap(\.text)
                .joined() ?? ""
            guard !text.isEmpty else {
                throw AIError.decodingError(DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "No text in Gemini response")
                ))
            }
            let usage = decoded.usageMetadata.map { meta in
                AIResponse.TokenUsage(
                    inputTokens: meta.promptTokenCount ?? 0,
                    outputTokens: meta.candidatesTokenCount ?? 0,
                    totalTokens: meta.totalTokenCount ?? 0
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

// MARK: – Wire types

private struct GeminiPart: Encodable {
    let text: String
}

private struct GeminiContent: Encodable {
    let role: String
    let parts: [GeminiPart]
}

private struct GeminiRequest: Encodable {
    struct SystemInstruction: Encodable {
        let parts: [GeminiPart]
    }

    struct GenerationConfig: Encodable {
        let temperature: Double?
        let maxOutputTokens: Int?
        let topP: Double?
    }

    let contents: [GeminiContent]
    let systemInstruction: SystemInstruction?
    let generationConfig: GenerationConfig?

    enum CodingKeys: String, CodingKey {
        case contents
        case systemInstruction = "system_instruction"
        case generationConfig
    }
}

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable { let text: String? }
            let parts: [Part]
            let role: String
        }
        let content: Content
    }

    struct UsageMetadata: Decodable {
        let promptTokenCount: Int?
        let candidatesTokenCount: Int?
        let totalTokenCount: Int?
    }

    let candidates: [Candidate]
    let usageMetadata: UsageMetadata?
}
