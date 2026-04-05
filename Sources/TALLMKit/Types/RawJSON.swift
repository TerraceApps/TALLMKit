// Sources/TALLMKit/Types/RawJSON.swift
import Foundation

/// Round-trips arbitrary JSON dictionaries/arrays through Codable.
/// Used by providers to encode tool parameter schemas and decode tool inputs.
struct RawJSON: Codable {
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
