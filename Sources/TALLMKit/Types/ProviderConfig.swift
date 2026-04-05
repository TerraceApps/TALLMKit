// Sources/TALLMKit/Types/ProviderConfig.swift
/// Credentials for a single LLM provider, passed to `TALLMKit.configure`.
///
/// Each case carries the API key required to authenticate with that provider's API.
/// You can configure multiple providers at once and switch between them per-request
/// by choosing a different `Model` case:
///
/// ```swift
/// sdk.configure(
///     .openAI(key: "sk-..."),
///     .anthropic(key: "sk-ant-..."),
///     .gemini(key: "AIza...")
/// )
/// // Routes to OpenAI:
/// let r1 = try await sdk.send("Hi", model: .openAI(.gpt4oMini))
/// // Routes to Anthropic:
/// let r2 = try await sdk.send("Hi", model: .anthropic(.claudeSonnet46))
/// ```
public enum ProviderConfig: Sendable {
    /// OpenAI provider — authenticates with a `sk-…` API key.
    case openAI(key: String)
    /// Anthropic provider — authenticates with a `sk-ant-…` API key.
    case anthropic(key: String)
    /// xAI Grok provider — authenticates with an xAI API key.
    case grok(key: String)
    /// Google Gemini provider — authenticates with a Google AI API key.
    case gemini(key: String)
}

/// Internal discriminator used as the dictionary key in `TALLMKit`'s provider registry.
///
/// The value is derived from `ProviderConfig` and `Model` to ensure both always
/// map to the same key for the same provider.
enum ProviderType: String, Hashable, Sendable {
    case openAI
    case anthropic
    case grok
    case gemini
}

extension ProviderConfig {
    /// Returns the `ProviderType` that corresponds to this configuration case.
    ///
    /// Used by `TALLMKit.configure` to key the provider in the internal dictionary.
    var providerType: ProviderType {
        switch self {
        case .openAI:    return .openAI
        case .anthropic: return .anthropic
        case .grok:      return .grok
        case .gemini:    return .gemini
        }
    }
}
