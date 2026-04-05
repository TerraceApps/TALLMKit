// Sources/TALLMKit/Types/Tool.swift
import Foundation

/// A function/tool the model can invoke.
public struct Tool: Sendable {
    public let name: String
    public let description: String
    /// JSON Schema string, e.g. `{"type":"object","properties":{...},"required":[...]}`
    public let parametersSchema: String

    public init(name: String, description: String, parametersSchema: String) {
        self.name = name
        self.description = description
        self.parametersSchema = parametersSchema
    }
}

/// A single tool/function invocation requested by the model.
public struct ToolCall: Sendable {
    /// Provider-specific call ID (used when returning the tool result).
    public let id: String
    /// The function name the model wants to call.
    public let name: String
    /// JSON-encoded arguments string.
    public let arguments: String

    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

/// Wraps a strongly-typed decoded value alongside token-usage metadata.
public struct TypedResponse<T: Decodable & Sendable>: Sendable {
    public let value: T
    public let usage: AIResponse.TokenUsage?

    public init(value: T, usage: AIResponse.TokenUsage?) {
        self.value = value
        self.usage = usage
    }
}
