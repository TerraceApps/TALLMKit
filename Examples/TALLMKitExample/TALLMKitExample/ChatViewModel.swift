// Examples/TALLMKitExample/TALLMKitExample/ChatViewModel.swift
import Foundation
import Observation
import TALLMKit

enum ProviderOption: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case grok = "Grok"
    case gemini = "Gemini"
    var id: String { rawValue }
}

@MainActor
@Observable
final class ChatViewModel {
    var selectedProvider: ProviderOption = .openAI
    var apiKey: String = ""
    var selectedModel: String = "gpt-4o-mini"
    var prompt: String = ""
    var response: String = ""
    var usageText: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var toolDemoOutput: String = ""

    var availableModels: [String] {
        switch selectedProvider {
        case .openAI:     return ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo"]
        case .anthropic:  return ["claude-sonnet-4-6-20251101", "claude-haiku-4-5-20251001"]
        case .grok:       return ["grok-3", "grok-3-mini"]
        case .gemini:     return ["gemini-2.0-flash", "gemini-1.5-pro"]
        }
    }

    func send() {
        guard !apiKey.isEmpty else { errorMessage = "Please enter an API key."; return }
        guard !prompt.isEmpty else { errorMessage = "Please enter a prompt."; return }
        errorMessage = nil
        isLoading = true
        response = ""
        usageText = ""

        Task {
            defer { isLoading = false }
            do {
                let sdk = TALLMKit()
                configureSDK(sdk)
                let model = resolveModel()
                let result = try await sdk.send(prompt, model: model)
                response = result.text
                if let u = result.usage {
                    usageText = "↑\(u.inputTokens) ↓\(u.outputTokens) total \(u.totalTokens)"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toolDemo() {
        guard !apiKey.isEmpty else { errorMessage = "Please enter an API key."; return }
        errorMessage = nil
        isLoading = true
        toolDemoOutput = ""

        Task {
            defer { isLoading = false }
            do {
                let sdk = TALLMKit()
                configureSDK(sdk)
                let model = resolveModel()

                let weatherTool = Tool(
                    name: "get_weather",
                    description: "Get current temperature for a city",
                    parametersSchema: """
                    {"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}
                    """
                )
                var params = RequestParameters()
                params.tools = [weatherTool]

                let firstResponse = try await sdk.send(
                    "What's the weather in Paris right now?",
                    model: model,
                    parameters: params
                )

                if let calls = firstResponse.toolCalls, let call = calls.first {
                    // Simulate tool execution locally
                    let fakeWeather = "{\"temperature\": 22, \"unit\": \"C\", \"condition\": \"Sunny\"}"
                    toolDemoOutput = """
                    Model requested tool: \(call.name)
                    Arguments: \(call.arguments)

                    (Simulating tool execution…)
                    Tool result: \(fakeWeather)
                    """

                    let followUp = try await sdk.chat(model, messages: [
                        .user("What's the weather in Paris right now?"),
                        .assistant(firstResponse.text),
                        .toolResult(toolCallId: call.id, content: fakeWeather)
                    ])
                    toolDemoOutput += "\n\nFinal answer: \(followUp.text)"
                } else {
                    toolDemoOutput = "Model responded directly (no tool call):\n\(firstResponse.text)"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: – Helpers

    private func configureSDK(_ sdk: TALLMKit) {
        switch selectedProvider {
        case .openAI:    sdk.configure(.openAI(key: apiKey))
        case .anthropic: sdk.configure(.anthropic(key: apiKey))
        case .grok:      sdk.configure(.grok(key: apiKey))
        case .gemini:    sdk.configure(.gemini(key: apiKey))
        }
    }

    private func resolveModel() -> Model {
        switch selectedProvider {
        case .openAI:
            switch selectedModel {
            case "gpt-4o": return .openAI(.gpt4o)
            default:       return .openAI(.gpt4oMini)
            }
        case .anthropic:
            return .anthropic(.claudeSonnet46)
        case .grok:
            return .grok(.grok3)
        case .gemini:
            return .gemini(.gemini20Flash)
        }
    }
}
