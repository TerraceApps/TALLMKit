// Tests/TALLMKitTests/CombineTests.swift
import Testing
import Foundation
@testable import TALLMKit

@Suite("MultiResponse")
struct MultiResponseTests {

    @Test("subscript returns result for known tag")
    func subscriptKnownTag() {
        let response = AIResponse(text: "Hello", model: "gpt-4o-mini")
        let multi = MultiResponse(results: ["openai": .success(response)])
        guard case .success(let r) = multi["openai"] else {
            Issue.record("Expected success")
            return
        }
        #expect(r.text == "Hello")
    }

    @Test("subscript returns nil for unknown tag")
    func subscriptUnknownTag() {
        let multi = MultiResponse(results: [:])
        #expect(multi["missing"] == nil)
    }

    @Test("successes returns only successful results unwrapped")
    func successesFiltersCorrectly() {
        let good = AIResponse(text: "OK", model: "gpt-4o-mini")
        let multi = MultiResponse(results: [
            "a": .success(good),
            "b": .failure(AIError.invalidAPIKey)
        ])
        #expect(multi.successes.count == 1)
        #expect(multi.successes["a"]?.text == "OK")
    }

    @Test("failures returns only failed results")
    func failuresFiltersCorrectly() {
        let good = AIResponse(text: "OK", model: "gpt-4o-mini")
        let multi = MultiResponse(results: [
            "a": .success(good),
            "b": .failure(AIError.invalidAPIKey)
        ])
        #expect(multi.failures.count == 1)
        guard case .failure(let error) = multi["b"],
              let aiError = error as? AIError,
              case .invalidAPIKey = aiError else {
            Issue.record("Expected AIError.invalidAPIKey for key 'b'")
            return
        }
        // Also confirm the failures computed property surfaces the same error
        guard let failureError = multi.failures["b"],
              let failureAIError = failureError as? AIError,
              case .invalidAPIKey = failureAIError else {
            Issue.record("Expected AIError.invalidAPIKey in multi.failures for key 'b'")
            return
        }
    }

    @Test("successes is empty when all failed")
    func successesEmptyOnAllFailure() {
        let multi = MultiResponse(results: [
            "x": .failure(AIError.providerNotConfigured)
        ])
        #expect(multi.successes.isEmpty)
    }

    @Test("failures is empty when all succeeded")
    func failuresEmptyOnAllSuccess() {
        let good = AIResponse(text: "Hi", model: "gpt-4o-mini")
        let multi = MultiResponse(results: ["x": .success(good)])
        #expect(multi.failures.isEmpty)
    }
}

@Suite("TALLMKit.combine")
struct CombineIntegrationTests {

    static let openAIJSON = """
    {
      "choices": [{ "message": { "role": "assistant", "content": "OpenAI reply" } }],
      "usage": { "prompt_tokens": 5, "completion_tokens": 2, "total_tokens": 7 }
    }
    """.data(using: .utf8)!

    static let anthropicJSON = """
    {
      "content": [{ "type": "text", "text": "Anthropic reply" } ],
      "usage": { "input_tokens": 5, "output_tokens": 3 }
    }
    """.data(using: .utf8)!

    func makeRoutingClient() -> RoutingMockHTTPClient {
        RoutingMockHTTPClient { request in
            let url = request.url?.absoluteString ?? ""
            let data: Data
            if url.contains("openai.com") {
                data = CombineIntegrationTests.openAIJSON
            } else if url.contains("anthropic.com") {
                data = CombineIntegrationTests.anthropicJSON
            } else {
                throw AIError.httpError(status: 500, body: "Unknown provider")
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }
    }

    @Test("combine returns success for all configured providers")
    func combineAllSucceed() async {
        let sdk = TALLMKit(httpClient: makeRoutingClient())
        sdk.configure(.openAI(key: "sk-test"), .anthropic(key: "sk-ant-test"))

        let multi = await sdk.combine([
            CombineRequest(tag: "openai", message: "Hello", model: .openAI(.gpt4oMini)),
            CombineRequest(tag: "claude", message: "Hello", model: .anthropic(.claudeSonnet46)),
        ])

        #expect(multi.successes.count == 2)
        #expect(multi.successes["openai"]?.text == "OpenAI reply")
        #expect(multi.successes["claude"]?.text == "Anthropic reply")
        #expect(multi.failures.isEmpty)
    }

    @Test("combine captures providerNotConfigured as failure for unconfigured provider")
    func combineUnconfiguredProviderIsFailure() async {
        let sdk = TALLMKit(httpClient: makeRoutingClient())
        sdk.configure(.openAI(key: "sk-test"))
        // Anthropic NOT configured

        let multi = await sdk.combine([
            CombineRequest(tag: "openai", message: "Hello", model: .openAI(.gpt4oMini)),
            CombineRequest(tag: "claude", message: "Hello", model: .anthropic(.claudeSonnet46)),
        ])

        #expect(multi.successes.count == 1)
        #expect(multi.successes["openai"]?.text == "OpenAI reply")
        guard case .failure(let error) = multi["claude"],
              let aiError = error as? AIError,
              case .providerNotConfigured = aiError else {
            Issue.record("Expected providerNotConfigured failure for 'claude'")
            return
        }
    }

    @Test("combine with empty array returns empty MultiResponse")
    func combineEmptyInput() async {
        let sdk = TALLMKit()
        let multi = await sdk.combine([])
        #expect(multi.results.isEmpty)
    }

    @Test("combine captures network error as failure without throwing")
    func combineNetworkErrorIsFailure() async {
        let errorClient = RoutingMockHTTPClient { _ in
            throw URLError(.notConnectedToInternet)
        }
        let sdk = TALLMKit(httpClient: errorClient)
        sdk.configure(.openAI(key: "sk-test"))

        let multi = await sdk.combine([
            CombineRequest(tag: "openai", message: "Hello", model: .openAI(.gpt4oMini)),
        ])

        #expect(multi.successes.isEmpty)
        #expect(multi.failures["openai"] != nil)
    }
}
