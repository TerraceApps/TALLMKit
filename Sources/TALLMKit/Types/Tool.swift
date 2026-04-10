// Sources/TALLMKit/Types/Tool.swift
import Foundation

/// A type-safe representation of a JSON Schema used to describe tool parameters.
///
/// Build schemas using the enum cases and pass them to `Tool.parameters`.
/// The SDK serializes to JSON internally — no manual JSON string required.
///
/// ```swift
/// let schema: JSONSchema = .object(
///     properties: ["city": .string, "unit": .optional(.enum(["C", "F"]))],
///     required: ["city"]
/// )
/// ```
public indirect enum JSONSchema: Sendable {
    /// A JSON string value.
    case string
    /// A JSON integer value.
    case integer
    /// A JSON floating-point number value.
    case number
    /// A JSON boolean value.
    case boolean
    /// A JSON object with named properties. `required` lists mandatory property names.
    case object(properties: [String: JSONSchema], required: [String] = [])
    /// A JSON array whose items all conform to the given schema.
    case array(of: JSONSchema)
    /// A string constrained to one of the provided values.
    case `enum`([String])
    /// Marks the wrapped schema as nullable (`"nullable": true`).
    case optional(JSONSchema)

    /// Converts this schema to a `[String: Any]` dictionary suitable for JSON serialization.
    ///
    /// - Note: This method is internal. It is used by SDK providers to build request bodies
    ///   and is not part of the public API.
    func toJSON() -> [String: Any] {
        switch self {
        case .string:
            return ["type": "string"]
        case .integer:
            return ["type": "integer"]
        case .number:
            return ["type": "number"]
        case .boolean:
            return ["type": "boolean"]
        case .array(let inner):
            return ["type": "array", "items": inner.toJSON()]
        case .enum(let values):
            return ["type": "string", "enum": values]
        case .object(let props, let required):
            var dict: [String: Any] = [
                "type": "object",
                "properties": props.mapValues { $0.toJSON() }
            ]
            if !required.isEmpty { dict["required"] = required }
            return dict
        case .optional(let inner):
            var dict = inner.toJSON()
            dict["nullable"] = true
            return dict
        }
    }
}

/// Describes a function or action the model is allowed to call.
///
/// Define a tool by providing its name, a human-readable description, and a
/// `JSONSchema` value for its parameters. Pass one or more tools in
/// `RequestParameters.tools` to enable function calling for a request.
///
/// ```swift
/// let weatherTool = Tool(
///     name: "get_weather",
///     description: "Returns the current temperature for a given city.",
///     parameters: .object(
///         properties: ["city": .string],
///         required: ["city"]
///     )
/// )
///
/// var params = RequestParameters()
/// params.tools = [weatherTool]
/// let response = try await sdk.send("What's the weather in Tokyo?",
///                                    model: .openAI(.gpt4oMini),
///                                    parameters: params)
/// ```
public struct Tool: Sendable {
    /// The function name the model will use to invoke this tool.
    public let name: String

    /// A concise description of what the tool does and when the model should use it.
    public let description: String

    /// The JSON Schema describing this tool's input parameters.
    public let parameters: JSONSchema

    /// Creates a new `Tool`.
    ///
    /// - Parameters:
    ///   - name: The function name (e.g. `"get_weather"`).
    ///   - description: What the function does (shown to the model).
    ///   - parameters: A `JSONSchema` value describing the function's input object.
    public init(name: String, description: String, parameters: JSONSchema) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// A single function invocation the model wants to execute.
///
/// When a model decides to call a tool, it returns one or more `ToolCall` values
/// in `AIResponse.toolCalls`. Execute the named function locally with the provided
/// arguments, then send the result back using `Message.toolResult(toolCallId:content:)`.
///
/// ```swift
/// if let calls = response.toolCalls {
///     for call in calls {
///         let result = myFunctions[call.name]?(call.arguments) ?? "{}"
///         messages.append(.toolResult(toolCallId: call.id, content: result))
///     }
///     let followUp = try await sdk.chat(model, messages: messages)
/// }
/// ```
public struct ToolCall: Sendable {
    /// Provider-specific opaque identifier for this invocation.
    ///
    /// Pass this value as `toolCallId` in `Message.toolResult(toolCallId:content:)`
    /// to correlate the result with the original call. Gemini uses the function name
    /// as the ID; other providers use unique generated strings.
    public let id: String

    /// The name of the function the model wants to invoke.
    ///
    /// Matches `Tool.name` from the tool list sent in the request.
    public let name: String

    /// The function's input arguments encoded as a JSON object string.
    ///
    /// Decode this string against the parameter schema you defined in `Tool.parametersSchema`:
    ///
    /// ```swift
    /// struct WeatherArgs: Decodable { let city: String }
    /// let args = try JSONDecoder().decode(WeatherArgs.self, from: Data(call.arguments.utf8))
    /// ```
    public let arguments: String

    /// Creates a new `ToolCall`.
    ///
    /// This initialiser is used internally by providers when decoding API responses.
    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

/// A provider-agnostic response that pairs a strongly-typed decoded value with
/// the token usage from the underlying API call.
///
/// Returned by the typed-decoding overloads of `TALLMKit.send` and `TALLMKit.chat`:
///
/// ```swift
/// struct Forecast: Decodable, Sendable {
///     let city: String
///     let temperature: Double
/// }
///
/// let result = try await sdk.chat(
///     .openAI(.gpt4oMini),
///     messages: [.user("Give me Paris weather as JSON")],
///     decoding: Forecast.self
/// )
/// print(result.value.temperature)        // 22.0
/// print(result.usage?.totalTokens ?? 0)  // e.g. 45
/// ```
public struct TypedResponse<T: Decodable & Sendable>: Sendable {
    /// The value decoded from the model's JSON response.
    public let value: T

    /// Token consumption for the underlying request, if reported by the provider.
    public let usage: AIResponse.TokenUsage?

    /// Creates a new `TypedResponse`. Used internally after successful JSON decoding.
    public init(value: T, usage: AIResponse.TokenUsage?) {
        self.value = value
        self.usage = usage
    }
}
