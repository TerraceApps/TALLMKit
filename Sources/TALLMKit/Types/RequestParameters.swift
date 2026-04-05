// Sources/TALLMKit/Types/RequestParameters.swift
public struct RequestParameters: Sendable {
    public var temperature: Double?
    public var maxTokens: Int?
    public var topP: Double?
    /// Injected as a system message before the user messages in `send(_:model:parameters:)`.
    public var systemPrompt: String?
    /// Tools the model may call. Nil means no tool calling.
    public var tools: [Tool]?
    /// When true, asks the provider to emit valid JSON output.
    public var jsonMode: Bool

    public static let `default` = RequestParameters()

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
