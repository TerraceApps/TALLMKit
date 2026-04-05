// Sources/TALLMKit/Types/Message.swift
public struct Message: Sendable {
    public enum Role: String, Sendable {
        case system
        case user
        case assistant
    }

    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
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
}
