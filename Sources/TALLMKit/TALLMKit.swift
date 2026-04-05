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
    private let httpClient: any HTTPClientProtocol

    public init() {
        self.httpClient = HTTPClient()
    }

    /// Test-only initialiser; accessible via `@testable import TALLMKit`.
    init(httpClient: any HTTPClientProtocol) {
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

    // MARK: – Private

    private func makeProvider(for config: ProviderConfig) -> any AIProvider {
        switch config {
        case .openAI(let key):
            return OpenAICompatibleProvider(
                baseURL: URL(string: "https://api.openai.com/v1")!,
                apiKey: key,
                httpClient: httpClient
            )
        case .anthropic(let key):
            return AnthropicProvider(apiKey: key, httpClient: httpClient)
        case .grok(let key):
            return OpenAICompatibleProvider(
                baseURL: URL(string: "https://api.x.ai/v1")!,
                apiKey: key,
                httpClient: httpClient
            )
        case .gemini(let key):
            return GeminiProvider(apiKey: key, httpClient: httpClient)
        }
    }
}
