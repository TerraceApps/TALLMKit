// Sources/TALLMKit/Types/RequestParameters.swift
/// Sampling and feature parameters forwarded to the provider on each request.
///
/// All properties are optional and default to `nil` / `false`, meaning the provider
/// uses its own defaults. Override only the values you need:
///
/// ```swift
/// var params = RequestParameters()
/// params.temperature = 0.2
/// params.maxTokens   = 512
/// params.systemPrompt = "Always respond in JSON."
/// params.jsonMode    = true
///
/// let response = try await sdk.send("List 3 fruits", model: .openAI(.gpt4oMini), parameters: params)
/// ```
public struct RequestParameters: Sendable {

    /// Controls randomness in the model's output.
    ///
    /// Typical range is `0.0` (deterministic) to `2.0` (very random). When `nil`,
    /// the provider's default (usually `1.0`) is used.
    public var temperature: Double?

    /// Maximum number of tokens the model may generate in its reply.
    ///
    /// When `nil`, Anthropic defaults to `1024`; other providers use their own defaults.
    public var maxTokens: Int?

    /// Nucleus sampling probability mass.
    ///
    /// Only the tokens comprising the top `topP` probability mass are considered.
    /// Typical range is `0.0`–`1.0`. Use either `temperature` or `topP`, not both.
    public var topP: Double?

    /// A system-level instruction prepended automatically by `TALLMKit.send`.
    ///
    /// When set, `send(_:model:parameters:)` inserts `Message.system(systemPrompt)`
    /// before the user message. Has no effect when calling `chat(_:messages:parameters:)`
    /// directly — include system messages in the `messages` array instead.
    public var systemPrompt: String?

    /// Tools (functions) the model is allowed to call.
    ///
    /// Each `Tool` provides the model with a name, description, and JSON Schema for
    /// its parameters. When `nil`, tool calling is disabled for the request.
    public var tools: [Tool]?

    /// When `true`, instructs the provider to emit a valid JSON object as its reply.
    ///
    /// Provider-specific behaviour:
    /// - **OpenAI / Grok**: sets `response_format: {type: "json_object"}` in the body.
    /// - **Anthropic**: prepends `"Respond with valid JSON only, no other text."` to the system prompt.
    /// - **Gemini**: sets `responseMimeType: "application/json"` in `generationConfig`.
    ///
    /// Set automatically to `true` by the typed-decoding overloads `send(_:model:parameters:decoding:)`.
    public var jsonMode: Bool

    /// A `RequestParameters` with all properties at their defaults (nil / false).
    public static let `default` = RequestParameters()

    /// Creates a new `RequestParameters`.
    ///
    /// All parameters default to `nil` or `false`; only pass the values you want to override.
    public init(
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        systemPrompt: String? = nil,
        tools: [Tool]? = nil,
        jsonMode: Bool = false
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.jsonMode = jsonMode
    }
}
