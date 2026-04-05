// Tests/TALLMKitTests/AnthropicProviderTests.swift
import Testing
import Foundation
@testable import TALLMKit

@Suite("AnthropicProvider")
struct AnthropicProviderTests {

    static let successJSON = """
    {
      "id": "msg_01",
      "content": [{ "type": "text", "text": "Hi from Claude!" }],
      "model": "claude-sonnet-4-6",
      "usage": { "input_tokens": 8, "output_tokens": 4 }
    }
    """.data(using: .utf8)!

    @Test("Parses text from content[0].text")
    func parsesResponseText() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = AnthropicProvider(apiKey: "sk-ant-test", httpClient: mock)
        let response = try await provider.chat(
            model: "claude-sonnet-4-6",
            messages: [.user("Hello")],
            parameters: .default
        )
        #expect(response.text == "Hi from Claude!")
        #expect(response.model == "claude-sonnet-4-6")
    }

    @Test("Parses token usage")
    func parsesUsage() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = AnthropicProvider(apiKey: "sk-ant-test", httpClient: mock)
        let response = try await provider.chat(
            model: "claude-sonnet-4-6",
            messages: [.user("Hello")],
            parameters: .default
        )
        #expect(response.usage?.inputTokens == 8)
        #expect(response.usage?.outputTokens == 4)
        #expect(response.usage?.totalTokens == 12)
    }

    @Test("Sends x-api-key header")
    func sendsApiKeyHeader() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = AnthropicProvider(apiKey: "sk-ant-test", httpClient: mock)
        _ = try await provider.chat(model: "claude-sonnet-4-6", messages: [.user("Hi")], parameters: .default)
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "x-api-key") == "sk-ant-test")
    }

    @Test("Sends anthropic-version header")
    func sendsVersionHeader() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = AnthropicProvider(apiKey: "sk-ant-test", httpClient: mock)
        _ = try await provider.chat(model: "claude-sonnet-4-6", messages: [.user("Hi")], parameters: .default)
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
    }

    @Test("Sends request to /v1/messages")
    func sendsToCorrectEndpoint() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = AnthropicProvider(apiKey: "sk-ant-test", httpClient: mock)
        _ = try await provider.chat(model: "claude-sonnet-4-6", messages: [.user("Hi")], parameters: .default)
        #expect(mock.capturedRequest?.url?.absoluteString == "https://api.anthropic.com/v1/messages")
    }

    @Test("Extracts system messages into top-level system field")
    func extractsSystemMessages() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = AnthropicProvider(apiKey: "sk-ant-test", httpClient: mock)
        let messages: [Message] = [.system("You are helpful"), .user("Hi")]
        _ = try await provider.chat(model: "claude-sonnet-4-6", messages: messages, parameters: .default)

        let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
        let systemField = body["system"] as? String
        let msgs = body["messages"] as? [[String: Any]]
        #expect(systemField == "You are helpful")
        #expect(msgs?.count == 1)
        #expect(msgs?.first?["role"] as? String == "user")
    }

    @Test("Defaults max_tokens to 1024 when not specified")
    func defaultsMaxTokens() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = AnthropicProvider(apiKey: "sk-ant-test", httpClient: mock)
        _ = try await provider.chat(model: "claude-sonnet-4-6", messages: [.user("Hi")], parameters: .default)

        let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
        #expect(body["max_tokens"] as? Int == 1024)
    }

    @Test("Throws invalidAPIKey on 401")
    func throwsInvalidAPIKeyOn401() async throws {
        let mock = MockHTTPClient(data: Data(), statusCode: 401)
        let provider = AnthropicProvider(apiKey: "bad", httpClient: mock)
        await #expect {
            try await provider.chat(model: "claude-sonnet-4-6", messages: [.user("Hi")], parameters: .default)
        } throws: { error in
            guard let e = error as? AIError, case .invalidAPIKey = e else { return false }
            return true
        }
    }

    @Test("Throws rateLimited on 429")
    func throwsRateLimitedOn429() async throws {
        let mock = MockHTTPClient(data: Data(), statusCode: 429)
        let provider = AnthropicProvider(apiKey: "sk-ant-test", httpClient: mock)
        await #expect {
            try await provider.chat(model: "claude-sonnet-4-6", messages: [.user("Hi")], parameters: .default)
        } throws: { error in
            guard let e = error as? AIError, case .rateLimited = e else { return false }
            return true
        }
    }
}
