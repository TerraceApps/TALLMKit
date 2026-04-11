// Sources/TALLMKit/TALLMKit.swift
import Foundation

/// The main entry point for TALLMKit.
///
/// ```swift
/// let sdk = TALLMKit()
/// sdk.configure(.openAI(key: "sk-..."), .anthropic(key: "sk-ant-..."))
/// let response = try await sdk.send("Hello!", model: .openAI(.gpt4oMini))
/// print(response.text)
/// ```
public final class TALLMKit: @unchecked Sendable {
    private let lock = NSLock()
    private var _providers: [ProviderType: any AIProvider] = [:]
    private let httpClient: any HTTPClient

    /// Creates a new `TALLMKit` instance with the default `URLSession`-backed HTTP client.
    ///
    /// Call `configure` after initialisation to register at least one provider
    /// before making any `send` or `chat` calls.
    public init() {
        self.httpClient = HTTPClientImpl()
    }

    /// Test-only initialiser — injects a custom `HTTPClient` implementation.
    ///
    /// Accessible from test targets via `@testable import TALLMKit`.
    /// Not part of the public API; use `TALLMKit()` in production code.
    ///
    /// - Parameter httpClient: A mock or stub conforming to `HTTPClient`,
    ///   used to intercept network calls in unit tests.
    init(httpClient: any HTTPClient) {
        self.httpClient = httpClient
    }

    // MARK: – Configuration

    /// Configure one or more providers. Calling configure again with the same
    /// provider type replaces the existing configuration.
    ///
    /// ```swift
    /// sdk.configure(.openAI(key: "sk-..."), .anthropic(key: "sk-ant-..."))
    /// // Switch provider later:
    /// sdk.configure(.gemini(key: "gemini-key"))
    /// ```
    public func configure(_ configs: ProviderConfig...) {
        lock.withLock {
            for config in configs {
                _providers[config.providerType] = makeProvider(for: config)
            }
        }
    }

    // MARK: – Public API

    /// Send a single message and receive a response.
    ///
    /// If `parameters.systemPrompt` is set, it is prepended as a system message.
    public func send(
        _ message: String,
        model: Model,
        parameters: RequestParameters = .default
    ) async throws -> AIResponse {
        var messages: [Message] = []
        if let systemPrompt = parameters.systemPrompt {
            messages.append(.system(systemPrompt))
        }
        messages.append(.user(message))
        return try await chat(model, messages: messages, parameters: parameters)
    }

    /// Send a full conversation and receive a response.
    public func chat(
        _ model: Model,
        messages: [Message],
        parameters: RequestParameters = .default
    ) async throws -> AIResponse {
        let provider: any AIProvider = try lock.withLock {
            guard let p = _providers[model.providerType] else {
                throw AIError.providerNotConfigured
            }
            return p
        }
        return try await provider.chat(model: model.modelId, messages: messages, parameters: parameters)
    }

    /// Send a single message and decode the JSON response into a `Decodable` type.
    ///
    /// Automatically sets `jsonMode = true` on the parameters before calling the provider.
    public func send<T: Decodable & Sendable>(
        _ message: String,
        model: Model,
        parameters: RequestParameters = .default,
        decoding: T.Type
    ) async throws -> TypedResponse<T> {
        var p = parameters
        p.jsonMode = true
        var messages: [Message] = []
        if let systemPrompt = p.systemPrompt {
            messages.append(.system(systemPrompt))
        }
        messages.append(.user(message))
        return try await chat(model, messages: messages, parameters: p, decoding: decoding)
    }

    /// Send a full conversation and decode the JSON response into a `Decodable` type.
    ///
    /// Automatically sets `jsonMode = true` on the parameters before calling the provider.
    public func chat<T: Decodable & Sendable>(
        _ model: Model,
        messages: [Message],
        parameters: RequestParameters = .default,
        decoding: T.Type
    ) async throws -> TypedResponse<T> {
        var p = parameters
        p.jsonMode = true
        let response = try await chat(model, messages: messages, parameters: p)
        guard !response.text.isEmpty else {
            throw AIError.decodingError(
                DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Empty response text"))
            )
        }
        do {
            let value = try JSONDecoder().decode(T.self, from: Data(response.text.utf8))
            return TypedResponse(value: value, usage: response.usage)
        } catch {
            throw AIError.decodingError(error)
        }
    }

    /// Send multiple requests to different providers concurrently.
    ///
    /// All requests fire simultaneously via `withTaskGroup`. The method returns
    /// when every request has either completed or failed.
    ///
    /// Errors are **captured per slot** — the call itself never throws.
    /// Use `MultiResponse.successes`, `MultiResponse.failures`, or subscript
    /// access on the returned value to inspect results.
    ///
    /// ```swift
    /// let multi = await sdk.combine([
    ///     CombineRequest(tag: "openai", message: "Hello", model: .openAI(.gpt4oMini)),
    ///     CombineRequest(tag: "claude", message: "Hi!", model: .anthropic(.claudeSonnet46)),
    /// ])
    /// print(multi.successes)  // [String: AIResponse]
    /// print(multi.failures)   // [String: Error]
    /// ```
    ///
    /// - Parameter requests: One or more `CombineRequest` values. Duplicate tags
    ///   result in last-writer-wins. An empty array returns an empty `MultiResponse` immediately.
    /// - Returns: A `MultiResponse` containing a `Result` for every input tag.
    public func combine(_ requests: [CombineRequest]) async -> MultiResponse {
        var results: [String: Result<AIResponse, Error>] = [:]

        await withTaskGroup(of: (String, Result<AIResponse, Error>).self) { group in
            for request in requests {
                group.addTask {
                    do {
                        let response = try await self.send(
                            request.message,
                            model: request.model,
                            parameters: request.parameters
                        )
                        return (request.tag, .success(response))
                    } catch {
                        return (request.tag, .failure(error))
                    }
                }
            }
            for await (tag, result) in group {
                results[tag] = result
            }
        }

        return MultiResponse(results: results)
    }

    // MARK: – Private

    private func makeProvider(for config: ProviderConfig) -> any AIProvider {
        switch config {
        case .openAI(let key):
            return OpenAIProvider(apiKey: key, httpClient: httpClient)
        case .anthropic(let key):
            return AnthropicProvider(apiKey: key, httpClient: httpClient)
        case .grok(let key):
            return GrokProvider(apiKey: key, httpClient: httpClient)
        case .gemini(let key):
            return GeminiProvider(apiKey: key, httpClient: httpClient)
        }
    }
}
