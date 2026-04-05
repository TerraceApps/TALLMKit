// Sources/TALLMKit/Types/Model.swift
public enum Model: Sendable {
    case openAI(OpenAIModel)
    case anthropic(AnthropicModel)
    case grok(GrokModel)
    case gemini(GeminiModel)
}

public enum OpenAIModel: String, Sendable {
    case gpt4oMini   = "gpt-4o-mini"
    case gpt4o       = "gpt-4o"
    case gpt4Turbo   = "gpt-4-turbo"
    case gpt35Turbo  = "gpt-3.5-turbo"
}

public enum AnthropicModel: String, Sendable {
    case claudeOpus46   = "claude-opus-4-6"
    case claudeSonnet46 = "claude-sonnet-4-6"
    case claudeHaiku45  = "claude-haiku-4-5-20251001"
    case claude3Opus    = "claude-3-opus-20240229"
    case claude35Sonnet = "claude-3-5-sonnet-20241022"
    case claude3Haiku   = "claude-3-haiku-20240307"
}

public enum GrokModel: String, Sendable {
    case grok3     = "grok-3"
    case grok3Mini = "grok-3-mini"
    case grok2     = "grok-2"
    case grokBeta  = "grok-beta"
}

public enum GeminiModel: String, Sendable {
    case gemini20Flash  = "gemini-2.0-flash"
    case gemini15Pro    = "gemini-1.5-pro"
    case gemini15Flash  = "gemini-1.5-flash"
}

extension Model {
    var providerType: ProviderType {
        switch self {
        case .openAI:    return .openAI
        case .anthropic: return .anthropic
        case .grok:      return .grok
        case .gemini:    return .gemini
        }
    }

    var modelId: String {
        switch self {
        case .openAI(let m):    return m.rawValue
        case .anthropic(let m): return m.rawValue
        case .grok(let m):      return m.rawValue
        case .gemini(let m):    return m.rawValue
        }
    }
}
