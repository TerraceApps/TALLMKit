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

    func chat(
        model: String,
        messages: [Message],
        parameters: RequestParameters
    ) async throws -> AIResponse {
        let url = Self.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let encodedMessages = messages.map { msg in
            GrokRequest.Msg(role: msg.role.rawValue, content: msg.content, toolCallId: msg.toolCallId)
        }

        let encodedTools: [GrokRequest.Tool]? = parameters.tools.flatMap { tools in
            guard !tools.isEmpty else { return nil }
            return tools.map { tool in
                let schema = (try? JSONSerialization.jsonObject(with: Data(tool.parametersSchema.utf8))) as? [String: Any]
                return GrokRequest.Tool(
                    function: GrokRequest.ToolFunction(name: tool.name, description: tool.description, parameters: schema ?? [:])
                )
            }
        }

        let responseFormat: GrokRequest.ResponseFormat? = parameters.jsonMode ? .init(type: "json_object") : nil

        let body = GrokRequest(
            model: model,
            messages: encodedMessages,
            temperature: parameters.temperature,
            maxTokens: parameters.maxTokens,
            topP: parameters.topP,
            tools: encodedTools,
            responseFormat: responseFormat
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
            let decoded = try JSONDecoder().decode(GrokResponse.self, from: data)
            let text = decoded.choices.first?.message.content ?? ""
            let usage = decoded.usage.map {
                AIResponse.TokenUsage(inputTokens: $0.promptTokens, outputTokens: $0.completionTokens, totalTokens: $0.totalTokens)
            }
            let toolCalls: [ToolCall]? = decoded.choices.first?.message.toolCalls.flatMap { calls in
                calls.isEmpty ? nil : calls.map { ToolCall(id: $0.id, name: $0.function.name, arguments: $0.function.arguments) }
            }
            return AIResponse(text: text, model: model, usage: usage, toolCalls: toolCalls)
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.decodingError(error)
        }
    }
}

// MARK: – Wire types

private struct GrokRequest: Encodable {
    struct Msg: Encodable {
        let role: String
        let content: String
        let toolCallId: String?

        enum CodingKeys: String, CodingKey {
            case role, content
            case toolCallId = "tool_call_id"
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(role, forKey: .role)
            try c.encode(content, forKey: .content)
            if let id = toolCallId { try c.encode(id, forKey: .toolCallId) }
        }
    }

    struct ToolFunction: Encodable {
        let name: String
        let description: String
        let parameters: [String: Any]

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encode(description, forKey: .description)
            let data = try JSONSerialization.data(withJSONObject: parameters)
            let raw = try JSONDecoder().decode(RawJSON.self, from: data)
            try c.encode(raw, forKey: .parameters)
        }
        enum CodingKeys: String, CodingKey { case name, description, parameters }
    }

    struct Tool: Encodable {
        let type: String = "function"
        let function: ToolFunction
    }

    struct ResponseFormat: Encodable {
        let type: String
    }

    let model: String
    let messages: [Msg]
    let temperature: Double?
    let maxTokens: Int?
    let topP: Double?
    let tools: [Tool]?
    let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, tools
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case responseFormat = "response_format"
    }
}

private struct GrokResponse: Decodable {
    struct Choice: Decodable {
        struct Msg: Decodable {
            struct ToolCall: Decodable {
                struct Function: Decodable {
                    let name: String
                    let arguments: String
                }
                let id: String
                let function: Function
            }
            let role: String
            let content: String?
            let toolCalls: [ToolCall]?

            enum CodingKeys: String, CodingKey {
                case role, content
                case toolCalls = "tool_calls"
            }
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
