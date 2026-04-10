// Tests/TALLMKitTests/ToolCallingTests.swift
import Testing
import Foundation
@testable import TALLMKit

@Suite("Tool Calling")
struct ToolCallingTests {

    static let weatherTool = Tool(
        name: "get_weather",
        description: "Get current temperature for a city",
        parameters: .object(
            properties: ["city": .string],
            required: ["city"]
        )
    )

    // MARK: – OpenAI / Grok

    @Suite("OpenAI")
    struct OpenAIToolTests {

        static let toolCallResponseJSON = """
        {
          "choices": [{
            "message": {
              "role": "assistant",
              "content": null,
              "tool_calls": [{
                "id": "call_abc123",
                "type": "function",
                "function": {
                  "name": "get_weather",
                  "arguments": "{\\"city\\":\\"Paris\\"}"
                }
              }]
            }
          }],
          "usage": { "prompt_tokens": 20, "completion_tokens": 10, "total_tokens": 30 }
        }
        """.data(using: .utf8)!

        static let textResponseJSON = """
        {
          "choices": [{ "message": { "role": "assistant", "content": "It is 22°C in Paris." } }],
          "usage": { "prompt_tokens": 5, "completion_tokens": 8, "total_tokens": 13 }
        }
        """.data(using: .utf8)!

        @Test("Encodes tools in request body")
        func encodesToolsInRequest() async throws {
            let mock = MockHTTPClient(data: Self.textResponseJSON)
            let provider = OpenAIProvider(apiKey: "sk-test", httpClient: mock)
            var params = RequestParameters.default
            params.tools = [ToolCallingTests.weatherTool]
            _ = try await provider.chat(model: "gpt-4o-mini", messages: [.user("Weather?")], parameters: params)

            let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
            let tools = body["tools"] as? [[String: Any]]
            #expect(tools != nil)
            #expect(tools?.count == 1)
            let fn = (tools?.first?["function"] as? [String: Any])
            #expect(fn?["name"] as? String == "get_weather")
            #expect(fn?["description"] as? String == "Get current temperature for a city")
        }

        @Test("Decodes tool calls from response")
        func decodesToolCallsFromResponse() async throws {
            let mock = MockHTTPClient(data: Self.toolCallResponseJSON)
            let provider = OpenAIProvider(apiKey: "sk-test", httpClient: mock)
            let response = try await provider.chat(model: "gpt-4o-mini", messages: [.user("Weather?")], parameters: .default)
            #expect(response.toolCalls != nil)
            #expect(response.toolCalls?.count == 1)
            #expect(response.toolCalls?.first?.id == "call_abc123")
            #expect(response.toolCalls?.first?.name == "get_weather")
            #expect(response.toolCalls?.first?.arguments.contains("Paris") == true)
        }

        @Test("Encodes tool result message with tool_call_id")
        func encodesToolResultMessage() async throws {
            let mock = MockHTTPClient(data: Self.textResponseJSON)
            let provider = OpenAIProvider(apiKey: "sk-test", httpClient: mock)
            let messages: [Message] = [
                .user("Weather in Paris?"),
                .toolResult(toolCallId: "call_abc123", content: "{\"temp\": 22}")
            ]
            _ = try await provider.chat(model: "gpt-4o-mini", messages: messages, parameters: .default)

            let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
            let msgs = body["messages"] as! [[String: Any]]
            let toolMsg = msgs.last
            #expect(toolMsg?["role"] as? String == "tool")
            #expect(toolMsg?["tool_call_id"] as? String == "call_abc123")
        }

        @Test("Adds response_format json_object when jsonMode is true")
        func addsJsonResponseFormat() async throws {
            let mock = MockHTTPClient(data: Self.textResponseJSON)
            let provider = OpenAIProvider(apiKey: "sk-test", httpClient: mock)
            var params = RequestParameters.default
            params.jsonMode = true
            _ = try await provider.chat(model: "gpt-4o-mini", messages: [.user("Give JSON")], parameters: params)

            let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
            let fmt = body["response_format"] as? [String: Any]
            #expect(fmt?["type"] as? String == "json_object")
        }
    }

    // MARK: – Anthropic

    @Suite("Anthropic")
    struct AnthropicToolTests {

        static let toolUseResponseJSON = """
        {
          "content": [
            {
              "type": "tool_use",
              "id": "toolu_01XFDUDYJgAACTvnkyLAND8x",
              "name": "get_weather",
              "input": {"city": "Paris"}
            }
          ],
          "usage": { "input_tokens": 25, "output_tokens": 15 }
        }
        """.data(using: .utf8)!

        static let textResponseJSON = """
        {
          "content": [{ "type": "text", "text": "It is 22°C in Paris." }],
          "usage": { "input_tokens": 10, "output_tokens": 8 }
        }
        """.data(using: .utf8)!

        @Test("Encodes tools with input_schema in request body")
        func encodesToolsInRequest() async throws {
            let mock = MockHTTPClient(data: Self.textResponseJSON)
            let provider = AnthropicProvider(apiKey: "sk-ant-test", httpClient: mock)
            var params = RequestParameters.default
            params.tools = [ToolCallingTests.weatherTool]
            _ = try await provider.chat(model: "claude-sonnet-4-6", messages: [.user("Weather?")], parameters: params)

            let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
            let tools = body["tools"] as? [[String: Any]]
            #expect(tools != nil)
            #expect(tools?.first?["name"] as? String == "get_weather")
            #expect(tools?.first?["input_schema"] != nil)
        }

        @Test("Decodes tool_use blocks from response")
        func decodesToolCallsFromResponse() async throws {
            let mock = MockHTTPClient(data: Self.toolUseResponseJSON)
            let provider = AnthropicProvider(apiKey: "sk-ant-test", httpClient: mock)
            let response = try await provider.chat(model: "claude-sonnet-4-6", messages: [.user("Weather?")], parameters: .default)
            #expect(response.toolCalls != nil)
            #expect(response.toolCalls?.first?.id == "toolu_01XFDUDYJgAACTvnkyLAND8x")
            #expect(response.toolCalls?.first?.name == "get_weather")
            #expect(response.toolCalls?.first?.arguments.contains("Paris") == true)
        }

        @Test("Encodes tool result as user message with tool_result content block")
        func encodesToolResultMessage() async throws {
            let mock = MockHTTPClient(data: Self.textResponseJSON)
            let provider = AnthropicProvider(apiKey: "sk-ant-test", httpClient: mock)
            let messages: [Message] = [
                .user("Weather in Paris?"),
                .toolResult(toolCallId: "toolu_01XFDUDYJgAACTvnkyLAND8x", content: "{\"temp\": 22}")
            ]
            _ = try await provider.chat(model: "claude-sonnet-4-6", messages: messages, parameters: .default)

            let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
            let msgs = body["messages"] as! [[String: Any]]
            let toolMsg = msgs.last
            // tool result is encoded as a user message with content array
            #expect(toolMsg?["role"] as? String == "user")
            let contentBlocks = toolMsg?["content"] as? [[String: Any]]
            #expect(contentBlocks?.first?["type"] as? String == "tool_result")
            #expect(contentBlocks?.first?["tool_use_id"] as? String == "toolu_01XFDUDYJgAACTvnkyLAND8x")
        }

        @Test("Prepends JSON instruction to system prompt when jsonMode is true")
        func prependsJsonInstruction() async throws {
            let mock = MockHTTPClient(data: Self.textResponseJSON)
            let provider = AnthropicProvider(apiKey: "sk-ant-test", httpClient: mock)
            var params = RequestParameters.default
            params.jsonMode = true
            _ = try await provider.chat(model: "claude-sonnet-4-6", messages: [.user("Give JSON")], parameters: params)

            let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
            let system = body["system"] as? String
            #expect(system?.contains("valid JSON") == true)
        }
    }

    // MARK: – Gemini

    @Suite("Gemini")
    struct GeminiToolTests {

        static let functionCallResponseJSON = """
        {
          "candidates": [{
            "content": {
              "role": "model",
              "parts": [{
                "functionCall": {
                  "name": "get_weather",
                  "args": { "city": "Paris" }
                }
              }]
            }
          }],
          "usageMetadata": { "promptTokenCount": 20, "candidatesTokenCount": 10, "totalTokenCount": 30 }
        }
        """.data(using: .utf8)!

        static let textResponseJSON = """
        {
          "candidates": [{
            "content": { "role": "model", "parts": [{ "text": "It is 22°C in Paris." }] }
          }],
          "usageMetadata": { "promptTokenCount": 5, "candidatesTokenCount": 8, "totalTokenCount": 13 }
        }
        """.data(using: .utf8)!

        @Test("Encodes tools as functionDeclarations in request body")
        func encodesToolsInRequest() async throws {
            let mock = MockHTTPClient(data: Self.textResponseJSON)
            let provider = GeminiProvider(apiKey: "gemini-test", httpClient: mock)
            var params = RequestParameters.default
            params.tools = [ToolCallingTests.weatherTool]
            _ = try await provider.chat(model: "gemini-2.0-flash", messages: [.user("Weather?")], parameters: params)

            let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
            let tools = body["tools"] as? [[String: Any]]
            #expect(tools != nil)
            let decls = tools?.first?["functionDeclarations"] as? [[String: Any]]
            #expect(decls?.first?["name"] as? String == "get_weather")
        }

        @Test("Decodes functionCall parts from response")
        func decodesToolCallsFromResponse() async throws {
            let mock = MockHTTPClient(data: Self.functionCallResponseJSON)
            let provider = GeminiProvider(apiKey: "gemini-test", httpClient: mock)
            let response = try await provider.chat(model: "gemini-2.0-flash", messages: [.user("Weather?")], parameters: .default)
            #expect(response.toolCalls != nil)
            #expect(response.toolCalls?.first?.name == "get_weather")
            #expect(response.toolCalls?.first?.arguments.contains("Paris") == true)
        }

        @Test("Encodes tool result message as user turn with functionResponse part")
        func encodesToolResultMessage() async throws {
            let mock = MockHTTPClient(data: Self.textResponseJSON)
            let provider = GeminiProvider(apiKey: "gemini-test", httpClient: mock)
            let messages: [Message] = [
                .user("Weather in Paris?"),
                .toolResult(toolCallId: "get_weather", content: "{\"temp\": 22}")
            ]
            _ = try await provider.chat(model: "gemini-2.0-flash", messages: messages, parameters: .default)

            let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
            let contents = body["contents"] as! [[String: Any]]
            let toolContent = contents.last
            #expect(toolContent?["role"] as? String == "user")
            let parts = toolContent?["parts"] as? [[String: Any]]
            #expect(parts?.first?["functionResponse"] != nil)
        }

        @Test("Adds responseMimeType application/json when jsonMode is true")
        func addsJsonMimeType() async throws {
            let mock = MockHTTPClient(data: Self.textResponseJSON)
            let provider = GeminiProvider(apiKey: "gemini-test", httpClient: mock)
            var params = RequestParameters.default
            params.jsonMode = true
            _ = try await provider.chat(model: "gemini-2.0-flash", messages: [.user("Give JSON")], parameters: params)

            let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
            let genConfig = body["generationConfig"] as? [String: Any]
            #expect(genConfig?["responseMimeType"] as? String == "application/json")
        }
    }
}
