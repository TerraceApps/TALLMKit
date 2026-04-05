// Tests/TALLMKitTests/TypedDecodingTests.swift
import Testing
import Foundation
@testable import TALLMKit

@Suite("Typed Decoding")
struct TypedDecodingTests {

    struct WeatherInfo: Decodable, Sendable {
        let city: String
        let temperature: Double
        let condition: String
    }

    static let validWeatherJSON = """
    {
      "choices": [{
        "message": {
          "role": "assistant",
          "content": "{\\"city\\":\\"Paris\\",\\"temperature\\":22.5,\\"condition\\":\\"Sunny\\"}"
        }
      }],
      "usage": { "prompt_tokens": 10, "completion_tokens": 20, "total_tokens": 30 }
    }
    """.data(using: .utf8)!

    static let invalidJSONResponse = """
    {
      "choices": [{ "message": { "role": "assistant", "content": "This is not JSON at all!" } }],
      "usage": { "prompt_tokens": 5, "completion_tokens": 5, "total_tokens": 10 }
    }
    """.data(using: .utf8)!

    static let wrongShapeJSON = """
    {
      "choices": [{
        "message": {
          "role": "assistant",
          "content": "{\\"wrong_field\\":123}"
        }
      }],
      "usage": { "prompt_tokens": 5, "completion_tokens": 5, "total_tokens": 10 }
    }
    """.data(using: .utf8)!

    @Test("Decodes valid JSON into model")
    func decodesValidJSONIntoModel() async throws {
        let mock = MockHTTPClient(data: Self.validWeatherJSON)
        let sdk = TALLMKit(httpClient: mock)
        sdk.configure(.openAI(key: "sk-test"))

        let result = try await sdk.chat(
            .openAI(.gpt4oMini),
            messages: [.user("Paris weather as JSON")],
            decoding: WeatherInfo.self
        )
        #expect(result.value.city == "Paris")
        #expect(result.value.temperature == 22.5)
        #expect(result.value.condition == "Sunny")
    }

    @Test("Throws decodingError on invalid JSON response")
    func throwsDecodingErrorOnInvalidJSON() async throws {
        let mock = MockHTTPClient(data: Self.invalidJSONResponse)
        let sdk = TALLMKit(httpClient: mock)
        sdk.configure(.openAI(key: "sk-test"))

        await #expect {
            try await sdk.chat(
                .openAI(.gpt4oMini),
                messages: [.user("Paris weather as JSON")],
                decoding: WeatherInfo.self
            )
        } throws: { error in
            guard let e = error as? AIError, case .decodingError = e else { return false }
            return true
        }
    }

    @Test("Throws decodingError on type mismatch (wrong shape)")
    func throwsDecodingErrorOnTypeMismatch() async throws {
        let mock = MockHTTPClient(data: Self.wrongShapeJSON)
        let sdk = TALLMKit(httpClient: mock)
        sdk.configure(.openAI(key: "sk-test"))

        await #expect {
            try await sdk.chat(
                .openAI(.gpt4oMini),
                messages: [.user("Paris weather as JSON")],
                decoding: WeatherInfo.self
            )
        } throws: { error in
            guard let e = error as? AIError, case .decodingError = e else { return false }
            return true
        }
    }

    @Test("Preserves usage in TypedResponse")
    func preservesUsageInTypedResponse() async throws {
        let mock = MockHTTPClient(data: Self.validWeatherJSON)
        let sdk = TALLMKit(httpClient: mock)
        sdk.configure(.openAI(key: "sk-test"))

        let result = try await sdk.chat(
            .openAI(.gpt4oMini),
            messages: [.user("Paris weather as JSON")],
            decoding: WeatherInfo.self
        )
        #expect(result.usage?.inputTokens == 10)
        #expect(result.usage?.outputTokens == 20)
        #expect(result.usage?.totalTokens == 30)
    }

    @Test("send overload with decoding decodes JSON")
    func sendOverloadDecodesJSON() async throws {
        let mock = MockHTTPClient(data: Self.validWeatherJSON)
        let sdk = TALLMKit(httpClient: mock)
        sdk.configure(.openAI(key: "sk-test"))

        let result = try await sdk.send(
            "Paris weather as JSON",
            model: .openAI(.gpt4oMini),
            decoding: WeatherInfo.self
        )
        #expect(result.value.city == "Paris")
    }

    @Test("Sets jsonMode in request when using typed decoding")
    func setsJsonModeInRequest() async throws {
        let mock = MockHTTPClient(data: Self.validWeatherJSON)
        let sdk = TALLMKit(httpClient: mock)
        sdk.configure(.openAI(key: "sk-test"))

        _ = try await sdk.chat(
            .openAI(.gpt4oMini),
            messages: [.user("Paris weather as JSON")],
            decoding: WeatherInfo.self
        )

        let body = try JSONSerialization.jsonObject(with: mock.capturedRequest!.httpBody!) as! [String: Any]
        let fmt = body["response_format"] as? [String: Any]
        #expect(fmt?["type"] as? String == "json_object")
    }
}
