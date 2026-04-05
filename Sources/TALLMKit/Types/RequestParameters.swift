// Sources/TALLMKit/Types/RequestParameters.swift
public struct RequestParameters: Sendable {
    public var temperature: Double?
    public var maxTokens: Int?
    public var topP: Double?
    /// Injected as a system message before the user messages in `send(_:model:parameters:)`.
    public var systemPrompt: String?

    public static let `default` = RequestParameters()

    public init(
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        systemPrompt: String? = nil
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.systemPrompt = systemPrompt
    }
}
