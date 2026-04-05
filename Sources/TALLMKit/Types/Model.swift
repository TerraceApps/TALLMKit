// Sources/TALLMKit/Types/Model.swift
/// A type-safe model selector that encodes both the provider and the specific model.
///
/// Pass a `Model` value to any `TALLMKit` method. The SDK uses the provider case
/// to look up the correct configured provider and the inner enum's `rawValue` as
/// the model identifier string sent in the API request.
///
/// ```swift
/// sdk.send("Hello", model: .openAI(.gpt4oMini))
/// sdk.send("Hello", model: .anthropic(.claudeSonnet46))
/// sdk.send("Hello", model: .gemini(.gemini20Flash))
/// ```
public enum Model: Sendable {
    /// An OpenAI model accessed via `https://api.openai.com/v1`.
    case openAI(OpenAIModel)
    /// An Anthropic Claude model accessed via `https://api.anthropic.com/v1/messages`.
    case anthropic(AnthropicModel)
    /// An xAI Grok model accessed via `https://api.x.ai/v1` (OpenAI-compatible format).
    case grok(GrokModel)
    /// A Google Gemini model accessed via the Generative Language API.
    case gemini(GeminiModel)
}

/// Available OpenAI chat models.
///
/// `rawValue` is the exact model string sent in the API request body.
public enum OpenAIModel: String, Sendable {
    /// GPT-4o Mini — fast, cost-effective multimodal model.
    case gpt4oMini   = "gpt-4o-mini"
    /// GPT-4o — flagship multimodal model with vision capabilities.
    case gpt4o       = "gpt-4o"
    /// GPT-4 Turbo — high-capability model with a 128k context window.
    case gpt4Turbo   = "gpt-4-turbo"
    /// GPT-3.5 Turbo — fast and affordable model for simpler tasks.
    case gpt35Turbo  = "gpt-3.5-turbo"
}

/// Available Anthropic Claude models.
///
/// `rawValue` is the exact model string sent in the API request body.
public enum AnthropicModel: String, Sendable {
    /// Claude Opus 4.6 — Anthropic's most capable model.
    case claudeOpus46   = "claude-opus-4-6"
    /// Claude Sonnet 4.6 — balanced performance and speed.
    case claudeSonnet46 = "claude-sonnet-4-6"
    /// Claude Haiku 4.5 — fastest and most compact Claude model.
    case claudeHaiku45  = "claude-haiku-4-5-20251001"
    /// Claude 3 Opus — previous-generation high-capability model.
    case claude3Opus    = "claude-3-opus-20240229"
    /// Claude 3.5 Sonnet — strong reasoning with fast response times.
    case claude35Sonnet = "claude-3-5-sonnet-20241022"
    /// Claude 3 Haiku — previous-generation compact and fast model.
    case claude3Haiku   = "claude-3-haiku-20240307"
}

/// Available xAI Grok models.
///
/// `rawValue` is the exact model string sent in the API request body.
public enum GrokModel: String, Sendable {
    /// Grok 3 — xAI's flagship model.
    case grok3     = "grok-3"
    /// Grok 3 Mini — lightweight variant of Grok 3.
    case grok3Mini = "grok-3-mini"
    /// Grok 2 — previous-generation Grok model.
    case grok2     = "grok-2"
    /// Grok Beta — pre-release channel for early feature access.
    case grokBeta  = "grok-beta"
}

/// Available Google Gemini models.
///
/// `rawValue` is the exact model string embedded in the `generateContent` URL path.
public enum GeminiModel: String, Sendable {
    /// Gemini 2.0 Flash — latest fast multimodal model.
    case gemini20Flash  = "gemini-2.0-flash"
    /// Gemini 1.5 Pro — long-context model with up to 2M token window.
    case gemini15Pro    = "gemini-1.5-pro"
    /// Gemini 1.5 Flash — fast and efficient multimodal model.
    case gemini15Flash  = "gemini-1.5-flash"
}

extension Model {
    /// The `ProviderType` key used to look up the configured provider in `TALLMKit`.
    var providerType: ProviderType {
        switch self {
        case .openAI:    return .openAI
        case .anthropic: return .anthropic
        case .grok:      return .grok
        case .gemini:    return .gemini
        }
    }

    /// The raw model identifier string sent to the provider's API.
    var modelId: String {
        switch self {
        case .openAI(let m):    return m.rawValue
        case .anthropic(let m): return m.rawValue
        case .grok(let m):      return m.rawValue
        case .gemini(let m):    return m.rawValue
        }
    }
}
