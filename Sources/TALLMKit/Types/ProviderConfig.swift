// Sources/TALLMKit/Types/ProviderConfig.swift
public enum ProviderConfig: Sendable {
    case openAI(key: String)
    case anthropic(key: String)
    case grok(key: String)
    case gemini(key: String)
}

// Internal identifier used as dictionary key in TALLMKit
enum ProviderType: String, Hashable, Sendable {
    case openAI
    case anthropic
    case grok
    case gemini
}

extension ProviderConfig {
    var providerType: ProviderType {
        switch self {
        case .openAI:    return .openAI
        case .anthropic: return .anthropic
        case .grok:      return .grok
        case .gemini:    return .gemini
        }
    }
}
