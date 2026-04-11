// Sources/TALLMKit/Types/MultiResponse.swift

/// The combined result returned by `TALLMKit.combine(_:)`.
///
/// Each key is a `tag` from the corresponding `CombineRequest`.
/// Each value is `.success(AIResponse)` or `.failure(Error)`.
///
/// ```swift
/// let multi = await sdk.combine([...])
///
/// switch multi["openai"] {
/// case .success(let r): print(r.text)
/// case .failure(let e): print(e)
/// case nil: break
/// }
///
/// for (tag, response) in multi.successes { print("\(tag): \(response.text)") }
/// for (tag, error) in multi.failures    { print("\(tag): \(error)") }
/// ```
public struct MultiResponse: @unchecked Sendable {
    /// The raw results dictionary. Every tag from the input `[CombineRequest]` is present.
    public let results: [String: Result<AIResponse, Error>]

    public init(results: [String: Result<AIResponse, Error>]) {
        self.results = results
    }

    /// Returns the result for `tag`, or `nil` if no request had that tag.
    public subscript(tag: String) -> Result<AIResponse, Error>? {
        results[tag]
    }

    /// All successful responses, keyed by tag.
    public var successes: [String: AIResponse] {
        results.compactMapValues { try? $0.get() }
    }

    /// All failed results, keyed by tag.
    public var failures: [String: Error] {
        results.compactMapValues { result in
            if case .failure(let e) = result { return e }
            return nil
        }
    }
}
