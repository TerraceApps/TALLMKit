// Tests/TALLMKitTests/TALLMKitTests.swift
import Testing
import Foundation
@testable import TALLMKit

@Suite("TALLMKit Integration")
struct TALLMKitIntegrationTests {

    static let openAIJSON = """
    {
      "choices": [{ "message": { "role": "assistant", "content": "Hi!" } }],
      "usage": { "prompt_tokens": 5, "completion_tokens": 2, "total_tokens": 7 }
    }
    """.data(using: .utf8)!

    static let anthropicJSON = """
    {
      "content": [{ "type": "text", "text": "Hello from Claude!" }],
      "usage": { "input_tokens": 5, "output_tokens": 3 }
    }
    """.data(using: .utf8)!

    // MARK: – configure + send

    @Test("send routes to OpenAI when OpenAI model specified")
    func sendRoutesToOpenAI() async throws {
        let mock = MockHTTPClient(data: Self.openAIJSON)
        let sdk = TALLMKit(httpClient: mock)
        sdk.configure(.openAI(key: "sk-test"))

        let response = try await sdk.send("Hello", model: .openAI(.gpt4oMini))
        #expect(response.text == "Hi!")
        let url = mock.capturedRequest?.url?.absoluteString ?? ""
        #expect(url.contains("openai.com"))
    }

    @Test("send routes to Anthropic when Anthropic model specified")
    func sendRoutesToAnthropic() async throws {
        let mock = MockHTTPClient(data: Self.anthropicJSON)
        let sdk = TALLMKit(httpClient: mock)
        sdk.configure(.anthropic(key: "sk-ant-test"))

        let response = try await sdk.send("Hello", model: .anthropic(.claudeSonnet46))
        #expect(response.text == "Hello from Claude!")
        let url = mock.capturedRequest?.url?.absoluteString ?? ""
        #expect(url.contains("anthropic.com"))
    }

    @Test("throws providerNotConfigured when provider not configured")
    func throwsProviderNotConfigured() async throws {
        let sdk = TALLMKit()
        await #expect {
            try await sdk.send("Hello", model: .openAI(.gpt4oMini))
        } throws: { error in
            guard let e = error as? AIError, case .providerNotConfigured = e else { return false }
            return true
        }
    }

    @Test("configure can be called multiple times to register multiple providers")
    func configureMultipleProviders() async throws {
        let openAIMock = MockHTTPClient(data: Self.openAIJSON)
        let sdk = TALLMKit(httpClient: openAIMock)
        sdk.configure(.openAI(key: "sk-openai"), .anthropic(key: "sk-ant"))

        let response = try await sdk.send("Hi", model: .openAI(.gpt4oMini))
        #expect(response.text == "Hi!")
    }

    @Test("configure updates existing provider when called with same type again")
    func configureUpdatesProvider() async throws {
        let mock = MockHTTPClient(data: Self.openAIJSON)
        let sdk = TALLMKit(httpClient: mock)
        sdk.configure(.openAI(key: "old-key"))
        sdk.configure(.openAI(key: "new-key"))

        _ = try await sdk.send("Hi", model: .openAI(.gpt4oMini))
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer new-key")
    }

    // MARK: – chat

    @Test("chat passes full message history")
    func chatPassesHistory() async throws {
        let mock = MockHTTPClient(data: Self.openAIJSON)
        let sdk = TALLMKit(httpClient: mock)
        sdk.configure(.openAI(key: "sk-test"))

        let messages: [Message] = [.system("Be helpful"), .user("Hi"), .assistant("Hello!"), .user("How are you?")]
        _ = try await sdk.chat(.openAI(.gpt4oMini), messages: messages)

        let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
        let msgs = body["messages"] as! [[String: Any]]
        #expect(msgs.count == 4)
    }

    // MARK: – send with systemPrompt parameter

    @Test("send prepends system message when systemPrompt is set in parameters")
    func sendPrependsSystemPrompt() async throws {
        let mock = MockHTTPClient(data: Self.openAIJSON)
        let sdk = TALLMKit(httpClient: mock)
        sdk.configure(.openAI(key: "sk-test"))

        let params = RequestParameters(systemPrompt: "You are a test assistant")
        _ = try await sdk.send("Hello", model: .openAI(.gpt4oMini), parameters: params)

        let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
        let msgs = body["messages"] as! [[String: Any]]
        #expect(msgs.count == 2)
        #expect(msgs.first?["role"] as? String == "system")
        #expect(msgs.last?["role"] as? String == "user")
    }

    // MARK: – Grok routing

    static let grokJSON = Self.openAIJSON // Grok is OpenAI-compatible

    @Test("send routes to Grok base URL for Grok models")
    func sendRoutesToGrok() async throws {
        let mock = MockHTTPClient(data: Self.grokJSON)
        let sdk = TALLMKit(httpClient: mock)
        sdk.configure(.grok(key: "xai-test"))

        _ = try await sdk.send("Hi", model: .grok(.grok3))
        let url = mock.capturedRequest?.url?.absoluteString ?? ""
        #expect(url.contains("x.ai"))
    }
}
