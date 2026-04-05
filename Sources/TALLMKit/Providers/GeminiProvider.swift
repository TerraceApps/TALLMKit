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

        // Encode messages; .tool role becomes a "user" turn with functionResponse part
        let contents: [GeminiContent] = chatMessages.map { msg in
            if msg.role == .tool {
                // functionResponse: use toolCallId as the function name
                let funcName = msg.toolCallId ?? "unknown"
                let responseData = (try? JSONSerialization.jsonObject(with: Data(msg.content.utf8))) as? [String: Any]
                let part = GeminiFunctionResponsePart(
                    functionResponse: GeminiFunctionResponsePart.FunctionResponse(
                        name: funcName,
                        response: responseData ?? [:]
                    )
                )
                return GeminiContent(role: "user", parts: [.functionResponse(part)])
            } else {
                let role = msg.role == .assistant ? "model" : msg.role.rawValue
                return GeminiContent(role: role, parts: [.text(GeminiPart(text: msg.content))])
            }
        }

        // Encode tools if present
        let encodedTools: [GeminiRequest.GeminiTool]? = parameters.tools.flatMap { tools in
            guard !tools.isEmpty else { return nil }
            let decls = tools.map { tool -> GeminiRequest.FunctionDeclaration in
                let schema = (try? JSONSerialization.jsonObject(with: Data(tool.parametersSchema.utf8))) as? [String: Any]
                return GeminiRequest.FunctionDeclaration(
                    name: tool.name,
                    description: tool.description,
                    parameters: schema ?? [:]
                )
            }
            return [GeminiRequest.GeminiTool(functionDeclarations: decls)]
        }

        let genConfig: GeminiRequest.GenerationConfig? = {
            let hasParams = parameters.temperature != nil || parameters.maxTokens != nil
                || parameters.topP != nil || parameters.jsonMode
            guard hasParams else { return nil }
            return GeminiRequest.GenerationConfig(
                temperature: parameters.temperature,
                maxOutputTokens: parameters.maxTokens,
                topP: parameters.topP,
                responseMimeType: parameters.jsonMode ? "application/json" : nil
            )
        }()

        let body = GeminiRequest(
            contents: contents,
            systemInstruction: systemInstruction,
            generationConfig: genConfig,
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
            let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
            let candidate = decoded.candidates.first

            let text = candidate?.content.parts
                .compactMap { part -> String? in
                    if case .text(let t) = part { return t }
                    return nil
                }
                .joined() ?? ""

            // Decode functionCall parts
            let toolCalls: [ToolCall]? = {
                let calls = (candidate?.content.parts ?? []).compactMap { part -> ToolCall? in
                    guard case .functionCall(let fc) = part else { return nil }
                    let args: String
                    if let argData = try? JSONSerialization.data(withJSONObject: fc.args ?? [:]),
                       let argStr = String(data: argData, encoding: .utf8) {
                        args = argStr
                    } else {
                        args = "{}"
                    }
                    // Gemini doesn't return call IDs; use function name as ID
                    return ToolCall(id: fc.name, name: fc.name, arguments: args)
                }
                return calls.isEmpty ? nil : calls
            }()

            if text.isEmpty && toolCalls == nil {
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
            return AIResponse(text: text, model: model, usage: usage, toolCalls: toolCalls)
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

private struct GeminiFunctionResponsePart: Encodable {
    struct FunctionResponse: Encodable {
        let name: String
        let response: [String: Any]

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            let data = try JSONSerialization.data(withJSONObject: response)
            let raw = try JSONDecoder().decode(RawJSON.self, from: data)
            try c.encode(raw, forKey: .response)
        }
        enum CodingKeys: String, CodingKey { case name, response }
    }
    let functionResponse: FunctionResponse
}

private enum GeminiContentPart: Encodable {
    case text(GeminiPart)
    case functionResponse(GeminiFunctionResponsePart)

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let p): try p.encode(to: encoder)
        case .functionResponse(let p): try p.encode(to: encoder)
        }
    }
}

private struct GeminiContent: Encodable {
    let role: String
    let parts: [GeminiContentPart]
}

private struct GeminiRequest: Encodable {
    struct SystemInstruction: Encodable {
        let parts: [GeminiPart]
    }

    struct GenerationConfig: Encodable {
        let temperature: Double?
        let maxOutputTokens: Int?
        let topP: Double?
        let responseMimeType: String?
    }

    struct FunctionDeclaration: Encodable {
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

    struct GeminiTool: Encodable {
        let functionDeclarations: [FunctionDeclaration]
    }

    let contents: [GeminiContent]
    let systemInstruction: SystemInstruction?
    let generationConfig: GenerationConfig?
    let tools: [GeminiTool]?

    enum CodingKeys: String, CodingKey {
        case contents
        case systemInstruction = "system_instruction"
        case generationConfig
        case tools
    }
}

private struct GeminiResponse: Decodable {
    enum Part {
        case text(String)
        case functionCall(FunctionCall)
        case unknown
    }

    struct FunctionCall {
        let name: String
        let args: [String: Any]?
    }

    struct Candidate: Decodable {
        struct Content: Decodable {
            let parts: [Part]
            let role: String

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                role = try c.decode(String.self, forKey: .role)
                parts = try c.decode([PartWrapper].self, forKey: .parts).map(\.part)
            }
            enum CodingKeys: String, CodingKey { case parts, role }
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

private struct PartWrapper: Decodable {
    let part: GeminiResponse.Part

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try c.decodeIfPresent(String.self, forKey: .text) {
            part = .text(text)
        } else if let fc = try? c.nestedContainer(keyedBy: FCKeys.self, forKey: .functionCall) {
            let name = try fc.decode(String.self, forKey: .name)
            var args: [String: Any]? = nil
            if let rawArgs = try? fc.decode(RawJSON.self, forKey: .args) {
                args = rawArgs.value as? [String: Any]
            }
            part = .functionCall(GeminiResponse.FunctionCall(name: name, args: args))
        } else {
            part = .unknown
        }
    }

    enum CodingKeys: String, CodingKey { case text, functionCall }
    enum FCKeys: String, CodingKey { case name, args }
}

// MARK: – RawJSON helper

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
