// Sources/TALLMKit/Types/AIResponse.swift
public struct AIResponse: Sendable {
    public let text: String
    public let model: String
    public let usage: TokenUsage?
    public let toolCalls: [ToolCall]?

    public struct TokenUsage: Sendable {
        public let inputTokens: Int
        public let outputTokens: Int
        public let totalTokens: Int

        public init(inputTokens: Int, outputTokens: Int, totalTokens: Int) {
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.totalTokens = totalTokens
        }
    }

    public init(text: String, model: String, usage: TokenUsage? = nil, toolCalls: [ToolCall]? = nil) {
        self.text = text
        self.model = model
        self.usage = usage
        self.toolCalls = toolCalls
    }
}
