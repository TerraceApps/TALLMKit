// Sources/TALLMKit/Types/RawJSON.swift
import Foundation

/// A `Codable` wrapper that round-trips arbitrary JSON values through Swift's
/// `Codable` infrastructure without losing type fidelity.
///
/// Swift's `JSONEncoder` and `JSONDecoder` cannot directly handle `[String: Any]`
/// or `[Any]` dictionaries. `RawJSON` bridges that gap by recursively wrapping
/// every JSON primitive in this type, which knows how to encode and decode itself.
///
/// **Internal use only.** Providers use `RawJSON` in two places:
/// 1. **Encoding** — converting `Tool.parametersSchema` (a JSON string) into a
///    nested JSON object inside the request body.
/// 2. **Decoding** — extracting `[String: Any]` tool-call arguments from the
///    provider's response without requiring a concrete `Decodable` type.
///
/// ```swift
/// // Encode a [String: Any] into a Codable request body field:
/// let data = try JSONSerialization.data(withJSONObject: myDict)
/// let raw  = try JSONDecoder().decode(RawJSON.self, from: data)
/// try container.encode(raw, forKey: .parameters)
///
/// // Decode back to [String: Any]:
/// let raw  = try container.decode(RawJSON.self, forKey: .args)
/// let dict = raw.value as? [String: Any]
/// ```
struct RawJSON: Codable {
    /// The unwrapped JSON value — one of `[String: Any]`, `[Any]`, `String`,
    /// `Double`, `Bool`, or `NSNull`.
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode([String: RawJSON].self) { value = d.mapValues(\.value) }
        else if let a = try? c.decode([RawJSON].self) { value = a.map(\.value) }
        else if let s = try? c.decode(String.self) { value = s }
        else if let n = try? c.decode(Double.self) { value = n }
        else if let b = try? c.decode(Bool.self) { value = b }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let d as [String: Any]: try c.encode(d.mapValues { RawJSON($0) })
        case let a as [Any]:         try c.encode(a.map { RawJSON($0) })
        case let s as String:        try c.encode(s)
        case let n as Double:        try c.encode(n)
        case let b as Bool:          try c.encode(b)
        default:                     try c.encodeNil()
        }
    }
}
