// Tests/TALLMKitTests/GeminiProviderTests.swift
import Testing
import Foundation
@testable import TALLMKit

@Suite("GeminiProvider")
struct GeminiProviderTests {

    static let successJSON = """
    {
      "candidates": [{
        "content": {
          "parts": [{ "text": "Hello from Gemini!" }],
          "role": "model"
        }
      }],
      "usageMetadata": {
        "promptTokenCount": 3,
        "candidatesTokenCount": 4,
        "totalTokenCount": 7
      }
    }
    """.data(using: .utf8)!

    @Test("Parses text from candidates[0].content.parts[0].text")
    func parsesResponseText() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = GeminiProvider(apiKey: "gemini-test-key", httpClient: mock)
        let response = try await provider.chat(
            model: "gemini-2.0-flash",
            messages: [.user("Hello")],
            parameters: .default
        )
        #expect(response.text == "Hello from Gemini!")
        #expect(response.model == "gemini-2.0-flash")
    }

    @Test("Parses token usage")
    func parsesUsage() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = GeminiProvider(apiKey: "gemini-test-key", httpClient: mock)
        let response = try await provider.chat(
            model: "gemini-2.0-flash",
            messages: [.user("Hello")],
            parameters: .default
        )
        #expect(response.usage?.inputTokens == 3)
        #expect(response.usage?.outputTokens == 4)
        #expect(response.usage?.totalTokens == 7)
    }

    @Test("Sends request to correct generateContent URL with API key")
    func sendsToCorrectEndpoint() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = GeminiProvider(apiKey: "my-gemini-key", httpClient: mock)
        _ = try await provider.chat(model: "gemini-2.0-flash", messages: [.user("Hi")], parameters: .default)
        let url = mock.capturedRequest?.url?.absoluteString ?? ""
        #expect(url.contains("gemini-2.0-flash:generateContent"))
        #expect(url.contains("key=my-gemini-key"))
    }

    @Test("Maps 'assistant' role to 'model' in Gemini contents")
    func mapsAssistantRoleToModel() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = GeminiProvider(apiKey: "key", httpClient: mock)
        let messages: [Message] = [.user("Hi"), .assistant("Hello"), .user("How are you?")]
        _ = try await provider.chat(model: "gemini-2.0-flash", messages: messages, parameters: .default)

        let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
        let contents = body["contents"] as! [[String: Any]]
        #expect(contents[1]["role"] as? String == "model")
    }

    @Test("Places system messages in systemInstruction field")
    func placesSystemInSystemInstruction() async throws {
        let mock = MockHTTPClient(data: Self.successJSON)
        let provider = GeminiProvider(apiKey: "key", httpClient: mock)
        let messages: [Message] = [.system("Be concise"), .user("Hi")]
        _ = try await provider.chat(model: "gemini-2.0-flash", messages: messages, parameters: .default)

        let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
        let sysInstruction = body["system_instruction"] as? [String: Any]
        let parts = sysInstruction?["parts"] as? [[String: Any]]
        #expect(parts?.first?["text"] as? String == "Be concise")

        let contents = body["contents"] as! [[String: Any]]
        #expect(contents.count == 1)
        #expect(contents.first?["role"] as? String == "user")
    }

    @Test("Throws invalidAPIKey on 401")
    func throwsInvalidAPIKeyOn401() async throws {
        let mock = MockHTTPClient(data: Data(), statusCode: 401)
        let provider = GeminiProvider(apiKey: "bad-key", httpClient: mock)
        await #expect {
            try await provider.chat(model: "gemini-2.0-flash", messages: [.user("Hi")], parameters: .default)
        } throws: { error in
            guard let e = error as? AIError, case .invalidAPIKey = e else { return false }
            return true
        }
    }

    @Test("Throws rateLimited on 429")
    func throwsRateLimitedOn429() async throws {
        let mock = MockHTTPClient(data: Data(), statusCode: 429)
        let provider = GeminiProvider(apiKey: "key", httpClient: mock)
        await #expect {
            try await provider.chat(model: "gemini-2.0-flash", messages: [.user("Hi")], parameters: .default)
        } throws: { error in
            guard let e = error as? AIError, case .rateLimited = e else { return false }
            return true
        }
    }
}
