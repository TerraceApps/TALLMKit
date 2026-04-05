// Sources/TALLMKit/Types/AIResponse.swift
/// The normalised response returned by every provider after a successful chat call.
///
/// `AIResponse` is provider-agnostic: OpenAI, Anthropic, Grok and Gemini all map
/// their wire-format responses into this single type before returning to the caller.
///
/// ```swift
/// let response = try await sdk.send("Summarise this", model: .anthropic(.claudeSonnet46))
/// print(response.text)                          // the model's reply
/// print(response.usage?.totalTokens ?? 0)       // token consumption
/// if let calls = response.toolCalls { ... }     // tool invocations, if any
/// ```
public struct AIResponse: Sendable {
    /// The model's text reply.
    ///
    /// Empty when the model responded exclusively with tool calls and produced
    /// no accompanying prose.
    public let text: String

    /// The model identifier string echoed back from the provider,
    /// e.g. `"gpt-4o-mini"` or `"claude-sonnet-4-6"`.
    public let model: String

    /// Token consumption for this request, if reported by the provider.
    ///
    /// Some providers (e.g. Gemini) return `nil` usage metadata for certain
    /// request types. Always guard or use optional chaining when reading this value.
    public let usage: TokenUsage?

    /// Tool or function calls the model wants to invoke, if any.
    ///
    /// When non-nil, execute each call locally and send the results back using
    /// `Message.toolResult(toolCallId:content:)` in a follow-up `chat` call.
    /// `nil` means the model produced a plain text reply with no tool invocations.
    public let toolCalls: [ToolCall]?

    /// Token consumption broken down into input, output, and total counts.
    ///
    /// All three values are in the unit reported by the provider (tokens).
    /// `totalTokens` may equal `inputTokens + outputTokens` or may include
    /// additional provider-specific counts (e.g. cached tokens).
    public struct TokenUsage: Sendable {
        /// Number of tokens in the prompt (system + conversation history).
        public let inputTokens: Int

        /// Number of tokens in the model's reply.
        public let outputTokens: Int

        /// Total tokens consumed by the request. Typically `inputTokens + outputTokens`.
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
