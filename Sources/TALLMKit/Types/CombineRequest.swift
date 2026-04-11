// Sources/TALLMKit/Types/CombineRequest.swift

/// A single request slot for use with `TALLMKit.combine(_:)`.
///
/// Supply a unique `tag` per slot — it becomes the key in `MultiResponse.results`.
/// Duplicate tags within one `combine` call result in last-writer-wins behaviour.
///
/// ```swift
/// CombineRequest(tag: "openai", message: "Hello", model: .openAI(.gpt4oMini))
/// CombineRequest(tag: "claude", message: "Hi!", model: .anthropic(.claudeSonnet46), parameters: params)
/// ```
public struct CombineRequest: Sendable {
    /// Unique identifier for this request slot. Used as the key in `MultiResponse`.
    public let tag: String
    /// The user message sent to the model.
    public let message: String
    /// The provider and model to send this request to.
    public let model: Model
    /// Sampling and feature parameters. Defaults to `.default`.
    public let parameters: RequestParameters

    public init(
        tag: String,
        message: String,
        model: Model,
        parameters: RequestParameters = .default
    ) {
        self.tag = tag
        self.message = message
        self.model = model
        self.parameters = parameters
    }
}
