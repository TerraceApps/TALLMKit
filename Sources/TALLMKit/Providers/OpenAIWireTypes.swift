// Sources/TALLMKit/Providers/OpenAIWireTypes.swift
// Internal wire types and shared chat logic for OpenAI-compatible APIs.
import Foundation

// MARK: – Request body

struct OpenAIRequest: Encodable {
    struct Message: Encodable {
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
            let raw = try JSONDecoder().decode(OpenAIRawJSON.self, from: data)
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
    let messages: [Message]
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

// MARK: – Response body

struct OpenAIResponse: Decodable {
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

// MARK: – RawJSON helper (round-trips arbitrary JSON through Codable)

struct OpenAIRawJSON: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode([String: OpenAIRawJSON].self) { value = d.mapValues(\.value) }
        else if let a = try? c.decode([OpenAIRawJSON].self) { value = a.map(\.value) }
        else if let s = try? c.decode(String.self) { value = s }
        else if let n = try? c.decode(Double.self) { value = n }
        else if let b = try? c.decode(Bool.self) { value = b }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let d as [String: Any]: try c.encode(d.mapValues { OpenAIRawJSON($0) })
        case let a as [Any]:         try c.encode(a.map { OpenAIRawJSON($0) })
        case let s as String:        try c.encode(s)
        case let n as Double:        try c.encode(n)
        case let b as Bool:          try c.encode(b)
        default:                     try c.encodeNil()
        }
    }
}

// MARK: – Shared chat implementation

func performOpenAIChat(
    baseURL: URL,
    apiKey: String,
    httpClient: any HTTPClient,
    model: String,
    messages: [Message],
    parameters: RequestParameters
) async throws -> AIResponse {
    let url = baseURL.appendingPathComponent("chat/completions")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    let encodedMessages = messages.map { msg in
        OpenAIRequest.Message(role: msg.role.rawValue, content: msg.content, toolCallId: msg.toolCallId)
    }

    let encodedTools: [OpenAIRequest.Tool]? = parameters.tools.flatMap { tools in
        guard !tools.isEmpty else { return nil }
        return tools.map { tool in
            let schema = (try? JSONSerialization.jsonObject(with: Data(tool.parametersSchema.utf8))) as? [String: Any]
            return OpenAIRequest.Tool(
                function: OpenAIRequest.ToolFunction(
                    name: tool.name,
                    description: tool.description,
                    parameters: schema ?? [:]
                )
            )
        }
    }

    let responseFormat: OpenAIRequest.ResponseFormat? = parameters.jsonMode
        ? .init(type: "json_object") : nil

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
        let body = String(data: data, encoding: .utf8) ?? ""
        switch response.statusCode {
        case 401: throw AIError.invalidAPIKey
        case 429: throw AIError.rateLimited(retryAfter: response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init))
        default:  throw AIError.httpError(status: response.statusCode, body: body)
        }
    }

    do {
        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
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
