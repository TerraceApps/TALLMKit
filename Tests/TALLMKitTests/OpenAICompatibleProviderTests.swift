// Tests/TALLMKitTests/OpenAICompatibleProviderTests.swift
import Testing
import Foundation
@testable import TALLMKit

@Suite("OpenAICompatibleProvider")
struct OpenAICompatibleProviderTests {

    // MARK: – Fixtures

    static let successJSON = """
    {
      "id": "chatcmpl-abc",
      "choices": [{
        "message": { "role": "assistant", "content": "Hello there!" }
      }],
      "usage": { "prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15 }
    }
    """.data(using: .utf8)!

    // MARK: – Response parsing

    @Test("Parses text from choices[0].message.content")
    func parsesResponseText() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = OpenAICompatibleProvider(
            variant: .openAI,
            apiKey: "sk-test",
            httpClient: mock
        )
        let response = try await provider.chat(
            model: "gpt-4o-mini",
            messages: [.user("Hi")],
            parameters: .default
        )
        #expect(response.text == "Hello there!")
        #expect(response.model == "gpt-4o-mini")
    }

    @Test("Parses token usage")
    func parsesUsage() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = OpenAICompatibleProvider(
            variant: .openAI,
            apiKey: "sk-test",
            httpClient: mock
        )
        let response = try await provider.chat(
            model: "gpt-4o-mini",
            messages: [.user("Hi")],
            parameters: .default
        )
        #expect(response.usage?.inputTokens == 10)
        #expect(response.usage?.outputTokens == 5)
        #expect(response.usage?.totalTokens == 15)
    }

    // MARK: – Request building

    @Test("Sends Authorization: Bearer header")
    func sendsAuthHeader() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = OpenAICompatibleProvider(
            variant: .openAI,
            apiKey: "sk-test-key",
            httpClient: mock
        )
        _ = try await provider.chat(model: "gpt-4o-mini", messages: [.user("Hi")], parameters: .default)
        #expect(mock.capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-key")
    }

    @Test("Sends request to /chat/completions")
    func sendsToCorrectEndpoint() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = OpenAICompatibleProvider(
            variant: .openAI,
            apiKey: "sk-test",
            httpClient: mock
        )
        _ = try await provider.chat(model: "gpt-4o-mini", messages: [.user("Hi")], parameters: .default)
        #expect(mock.capturedRequest?.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
    }

    @Test("Uses Grok base URL when configured for Grok")
    func usesGrokBaseURL() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = OpenAICompatibleProvider(
            variant: .grok,
            apiKey: "xai-test",
            httpClient: mock
        )
        _ = try await provider.chat(model: "grok-3", messages: [.user("Hi")], parameters: .default)
        #expect(mock.capturedRequest?.url?.absoluteString == "https://api.x.ai/v1/chat/completions")
    }

    // MARK: – Error handling

    @Test("Throws invalidAPIKey on 401")
    func throwsInvalidAPIKeyOn401() async throws {
        let mock = MockHTTPClient(data: Data(), statusCode: 401)
        let provider = OpenAICompatibleProvider(
            variant: .openAI,
            apiKey: "bad-key",
            httpClient: mock
        )
        await #expect {
            try await provider.chat(model: "gpt-4o-mini", messages: [.user("Hi")], parameters: .default)
        } throws: { error in
            guard let e = error as? AIError, case .invalidAPIKey = e else { return false }
            return true
        }
    }

    @Test("Throws rateLimited on 429")
    func throwsRateLimitedOn429() async throws {
        let mock = MockHTTPClient(data: Data(), statusCode: 429)
        let provider = OpenAICompatibleProvider(
            variant: .openAI,
            apiKey: "sk-test",
            httpClient: mock
        )
        await #expect {
            try await provider.chat(model: "gpt-4o-mini", messages: [.user("Hi")], parameters: .default)
        } throws: { error in
            guard let e = error as? AIError, case .rateLimited = e else { return false }
            return true
        }
    }

    @Test("Throws httpError on 500")
    func throwsHttpErrorOn500() async throws {
        let body = "Internal Server Error".data(using: .utf8)!
        let mock = MockHTTPClient(data: body, statusCode: 500)
        let provider = OpenAICompatibleProvider(
            variant: .openAI,
            apiKey: "sk-test",
            httpClient: mock
        )
        await #expect {
            try await provider.chat(model: "gpt-4o-mini", messages: [.user("Hi")], parameters: .default)
        } throws: { error in
            guard let e = error as? AIError, case .httpError(let status, _) = e else { return false }
            return status == 500
        }
    }

    @Test("Throws networkError when HTTPClient throws")
    func throwsNetworkError() async throws {
        let mock = MockHTTPClient()
        mock.stubbedError = URLError(.notConnectedToInternet)
        let provider = OpenAICompatibleProvider(
            variant: .openAI,
            apiKey: "sk-test",
            httpClient: mock
        )
        await #expect {
            try await provider.chat(model: "gpt-4o-mini", messages: [.user("Hi")], parameters: .default)
        } throws: { error in
            guard let e = error as? AIError, case .networkError = e else { return false }
            return true
        }
    }
}
