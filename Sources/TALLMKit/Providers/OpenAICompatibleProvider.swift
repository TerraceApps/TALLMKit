// Sources/TALLMKit/Providers/OpenAICompatibleProvider.swift
import Foundation

enum OpenAIVariant: Sendable {
    case openAI
    case grok

    var baseURL: URL {
        switch self {
        case .openAI: return URL(string: "https://api.openai.com/v1")!
        case .grok:   return URL(string: "https://api.x.ai/v1")!
        }
    }
}

final class OpenAICompatibleProvider: AIProvider, Sendable {
    private let baseURL: URL
    private let apiKey: String
    private let httpClient: any HTTPClientProtocol

    init(variant: OpenAIVariant, apiKey: String, httpClient: any HTTPClientProtocol) {
        self.baseURL = variant.baseURL
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

        // Encode messages — .tool role becomes role "tool" with tool_call_id
        let encodedMessages = messages.map { msg -> OpenAIRequest.OpenAIMessage in
            OpenAIRequest.OpenAIMessage(
                role: msg.role.rawValue,
                content: msg.content,
                toolCallId: msg.toolCallId
            )
        }

        // Encode tools if present
        let encodedTools: [OpenAIRequest.OpenAITool]? = parameters.tools.flatMap { tools in
            tools.isEmpty ? nil : tools.map { tool in
                let schema = (try? JSONSerialization.jsonObject(with: Data(tool.parametersSchema.utf8))) as? [String: Any]
                return OpenAIRequest.OpenAITool(
                    function: OpenAIRequest.OpenAIToolFunction(
                        name: tool.name,
                        description: tool.description,
                        parameters: schema ?? [:]
                    )
                )
            }
        }

        let responseFormat: OpenAIRequest.ResponseFormat? = parameters.jsonMode
            ? OpenAIRequest.ResponseFormat(type: "json_object")
            : nil

        let body = OpenAIRequest(
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
            let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            let text = decoded.choices.first?.message.content ?? ""
            let usage = decoded.usage.map {
                AIResponse.TokenUsage(
                    inputTokens: $0.promptTokens,
                    outputTokens: $0.completionTokens,
                    totalTokens: $0.totalTokens
                )
            }

            // Decode tool calls if present
            let toolCalls: [ToolCall]? = decoded.choices.first?.message.toolCalls.flatMap { calls in
                calls.isEmpty ? nil : calls.map {
                    ToolCall(id: $0.id, name: $0.function.name, arguments: $0.function.arguments)
                }
            }

            return AIResponse(text: text, model: model, usage: usage, toolCalls: toolCalls)
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
        let toolCallId: String?

        enum CodingKeys: String, CodingKey {
            case role, content
            case toolCallId = "tool_call_id"
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(role, forKey: .role)
            try c.encode(content, forKey: .content)
            if let id = toolCallId {
                try c.encode(id, forKey: .toolCallId)
            }
        }
    }

    struct OpenAIToolFunction: Encodable {
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

    struct OpenAITool: Encodable {
        let type: String = "function"
        let function: OpenAIToolFunction
    }

    struct ResponseFormat: Encodable {
        let type: String
    }

    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double?
    let maxTokens: Int?
    let topP: Double?
    let tools: [OpenAITool]?
    let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, tools
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case responseFormat = "response_format"
    }
}

/// Helper to round-trip arbitrary JSON through Codable.
private struct RawJSON: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode([String: RawJSON].self) { value = d.mapValues(\.value) }
        else if let a = try? c.decode([RawJSON].self) { value = a.map(\.value) }
        else if let s = try? c.decode(String.self) { value = s }
        else if let n = try? c.decode(Double.self) { value = n }
        else if let b = try? c.decode(Bool.self) { value = b }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let d as [String: Any]:
            try c.encode(d.mapValues { RawJSON($0) })
        case let a as [Any]:
            try c.encode(a.map { RawJSON($0) })
        case let s as String:
            try c.encode(s)
        case let n as Double:
            try c.encode(n)
        case let b as Bool:
            try c.encode(b)
        default:
            try c.encodeNil()
        }
    }
}

private struct OpenAIResponse: Decodable {
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
