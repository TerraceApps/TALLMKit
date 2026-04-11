// Tests/TALLMKitTests/CombineTests.swift
import Testing
import Foundation
@testable import TALLMKit

@Suite("MultiResponse")
struct MultiResponseTests {

    @Test("subscript returns result for known tag")
    func subscriptKnownTag() {
        let response = AIResponse(text: "Hello", model: "gpt-4o-mini")
        let multi = MultiResponse(results: ["openai": .success(response)])
        guard case .success(let r) = multi["openai"] else {
            Issue.record("Expected success")
            return
        }
        #expect(r.text == "Hello")
    }

    @Test("subscript returns nil for unknown tag")
    func subscriptUnknownTag() {
        let multi = MultiResponse(results: [:])
        #expect(multi["missing"] == nil)
    }

    @Test("successes returns only successful results unwrapped")
    func successesFiltersCorrectly() {
        let good = AIResponse(text: "OK", model: "gpt-4o-mini")
        let multi = MultiResponse(results: [
            "a": .success(good),
            "b": .failure(AIError.invalidAPIKey)
        ])
        #expect(multi.successes.count == 1)
        #expect(multi.successes["a"]?.text == "OK")
    }

    @Test("failures returns only failed results")
    func failuresFiltersCorrectly() {
        let good = AIResponse(text: "OK", model: "gpt-4o-mini")
        let multi = MultiResponse(results: [
            "a": .success(good),
            "b": .failure(AIError.invalidAPIKey)
        ])
        #expect(multi.failures.count == 1)
        guard case .failure(let error) = multi["b"],
              let aiError = error as? AIError,
              case .invalidAPIKey = aiError else {
            Issue.record("Expected AIError.invalidAPIKey for key 'b'")
            return
        }
    }

    @Test("successes is empty when all failed")
    func successesEmptyOnAllFailure() {
        let multi = MultiResponse(results: [
            "x": .failure(AIError.providerNotConfigured)
        ])
        #expect(multi.successes.isEmpty)
    }

    @Test("failures is empty when all succeeded")
    func failuresEmptyOnAllSuccess() {
        let good = AIResponse(text: "Hi", model: "gpt-4o-mini")
        let multi = MultiResponse(results: ["x": .success(good)])
        #expect(multi.failures.isEmpty)
    }
}
