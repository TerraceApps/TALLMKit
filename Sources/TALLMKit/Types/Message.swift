// Sources/TALLMKit/Types/Message.swift
public struct Message: Sendable {
    public enum Role: String, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    public let role: Role
    public let content: String
    /// Only set for `.tool` role messages (OpenAI tool result wire format).
    public let toolCallId: String?

    public init(role: Role, content: String, toolCallId: String? = nil) {
        self.role = role
        self.content = content
        self.toolCallId = toolCallId
    }

    public static func system(_ content: String) -> Message {
        Message(role: .system, content: content)
    }

    public static func user(_ content: String) -> Message {
        Message(role: .user, content: content)
    }

    public static func assistant(_ content: String) -> Message {
        Message(role: .assistant, content: content)
    }

    public static func toolResult(toolCallId: String, content: String) -> Message {
        Message(role: .tool, content: content, toolCallId: toolCallId)
    }
}
