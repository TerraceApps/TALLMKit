// Sources/TALLMKit/Providers/AnthropicProvider.swift
import Foundation

final class AnthropicProvider: AIProvider, Sendable {
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
        var request = try Endpoints.Anthropic(apiKey: apiKey).urlRequest()

        // Anthropic requires system messages in a separate top-level field
        var systemContent = messages
            .filter { $0.role == .system }
            .map(\.content)
            .joined(separator: "\n")

        // jsonMode: prepend instruction to system prompt
        if parameters.jsonMode {
            let jsonInstruction = "Respond with valid JSON only, no other text."
            systemContent = systemContent.isEmpty ? jsonInstruction : "\(jsonInstruction)\n\(systemContent)"
        }

        // Build content blocks per message
        let chatMessages: [AnthropicRequest.Msg] = messages
            .filter { $0.role != .system }
            .map { msg in
                if msg.role == .tool, let tcid = msg.toolCallId {
                    // Tool result: user message with tool_result content block
                    let block = AnthropicRequest.ContentBlock.toolResult(
                        toolUseId: tcid, content: msg.content
                    )
                    return AnthropicRequest.Msg(role: "user", content: .blocks([block]))
                } else {
                    return AnthropicRequest.Msg(role: msg.role.rawValue, content: .text(msg.content))
                }
            }

        // Encode tools if present
        let encodedTools: [AnthropicRequest.AnthropicTool]? = parameters.tools.flatMap { tools in
            tools.isEmpty ? nil : tools.map { tool in
                let schema = (try? JSONSerialization.jsonObject(with: Data(tool.parametersSchema.utf8))) as? [String: Any]
                return AnthropicRequest.AnthropicTool(
                    name: tool.name,
                    description: tool.description,
                    inputSchema: schema ?? [:]
                )
            }
        }

        let body = AnthropicRequest(
            model: model,
            messages: chatMessages,
            system: systemContent.isEmpty ? nil : systemContent,
            maxTokens: parameters.maxTokens ?? 1024,
            temperature: parameters.temperature,
            topP: parameters.topP,
            tools: encodedTools
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

            // Decode tool_use blocks
            let toolCalls: [ToolCall]? = {
                let calls = decoded.content
                    .filter { $0.type == "tool_use" }
                    .compactMap { block -> ToolCall? in
                        guard let id = block.id, let name = block.name else { return nil }
                        let args: String
                        if let inputData = try? JSONSerialization.data(withJSONObject: block.input ?? [:]),
                           let inputStr = String(data: inputData, encoding: .utf8) {
                            args = inputStr
                        } else {
                            args = "{}"
                        }
                        return ToolCall(id: id, name: name, arguments: args)
                    }
                return calls.isEmpty ? nil : calls
            }()

            // For tool_use responses, text may be empty — that's valid
            if text.isEmpty && toolCalls == nil {
                throw AIError.decodingError(DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "No text content in response")
                ))
            }

            let usage = AIResponse.TokenUsage(
                inputTokens: decoded.usage.inputTokens,
                outputTokens: decoded.usage.outputTokens,
                totalTokens: decoded.usage.inputTokens + decoded.usage.outputTokens
            )
            return AIResponse(text: text, model: model, usage: usage, toolCalls: toolCalls)
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.decodingError(error)
        }
    }
}

// MARK: – Wire types

private struct AnthropicRequest: Encodable {
    enum ContentBlock {
        case toolResult(toolUseId: String, content: String)
    }

    enum MessageContent: Encodable {
        case text(String)
        case blocks([ContentBlock])

        func encode(to encoder: Encoder) throws {
            switch self {
            case .text(let s):
                var c = encoder.singleValueContainer()
                try c.encode(s)
            case .blocks(let blocks):
                var c = encoder.unkeyedContainer()
                for block in blocks {
                    switch block {
                    case .toolResult(let id, let content):
                        var bc = c.nestedContainer(keyedBy: ToolResultKeys.self)
                        try bc.encode("tool_result", forKey: .type)
                        try bc.encode(id, forKey: .toolUseId)
                        try bc.encode(content, forKey: .content)
                    }
                }
            }
        }

        enum ToolResultKeys: String, CodingKey {
            case type
            case toolUseId = "tool_use_id"
            case content
        }
    }

    struct Msg: Encodable {
        let role: String
        let content: MessageContent
    }

    struct AnthropicTool: Encodable {
        let name: String
        let description: String
        let inputSchema: [String: Any]

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encode(description, forKey: .description)
            let data = try JSONSerialization.data(withJSONObject: inputSchema)
            let raw = try JSONDecoder().decode(RawJSON.self, from: data)
            try c.encode(raw, forKey: .inputSchema)
        }

        enum CodingKeys: String, CodingKey {
            case name, description
            case inputSchema = "input_schema"
        }
    }

    let model: String
    let messages: [Msg]
    let system: String?
    let maxTokens: Int
    let temperature: Double?
    let topP: Double?
    let tools: [AnthropicTool]?

    enum CodingKeys: String, CodingKey {
        case model, messages, system, temperature, tools
        case maxTokens = "max_tokens"
        case topP = "top_p"
    }
}

private struct AnthropicResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
        // tool_use fields
        let id: String?
        let name: String?
        let input: [String: Any]?

        enum CodingKeys: String, CodingKey { case type, text, id, name, input }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type = try c.decode(String.self, forKey: .type)
            text = try c.decodeIfPresent(String.self, forKey: .text)
            id = try c.decodeIfPresent(String.self, forKey: .id)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            if let raw = try? c.decode(RawJSON.self, forKey: .input) {
                input = raw.value as? [String: Any]
            } else {
                input = nil
            }
        }
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
