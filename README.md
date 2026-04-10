# TALLMKit

A lightweight, provider-agnostic Swift package that unifies OpenAI, Anthropic, Grok, and Gemini behind a single async/await interface.

## Requirements
- iOS 15+ / macOS 12+
- Swift 6
- Zero external dependencies

## Installation

```swift
// Package.swift
.package(url: "https://github.com/your-org/TALLMKit.git", from: "1.0.0")
```

## Quick Start

```swift
import TALLMKit

let sdk = TALLMKit()
sdk.configure(.openAI(key: "sk-..."))
let response = try await sdk.send("What is the Swift concurrency model?", model: .openAI(.gpt4oMini))
print(response.text)
```

---

## Examples

### 1. Configure multiple providers

```swift
let sdk = TALLMKit()
sdk.configure(
    .openAI(key: "sk-..."),
    .anthropic(key: "sk-ant-..."),
    .grok(key: "xai-..."),
    .gemini(key: "AIza...")
)
```

### 2. Single message (simple)

```swift
let sdk = TALLMKit()
sdk.configure(.openAI(key: "sk-..."))

let response = try await sdk.send("Summarize quantum computing in one sentence.", model: .openAI(.gpt4oMini))
print(response.text)
```

### 3. Multi-turn conversation

```swift
let sdk = TALLMKit()
sdk.configure(.anthropic(key: "sk-ant-..."))

var history: [Message] = [
    .system("You are a helpful Swift tutor."),
    .user("What is an actor in Swift?"),
    .assistant("An actor is a reference type that protects its mutable state from data races..."),
    .user("Can actors be subclassed?")
]

let response = try await sdk.chat(.anthropic(.claudeSonnet46), messages: history)
print(response.text)
history.append(.assistant(response.text))
```

### 4. System prompt via RequestParameters

```swift
let sdk = TALLMKit()
sdk.configure(.openAI(key: "sk-..."))

let params = RequestParameters(
    temperature: 0.3,
    maxTokens: 256,
    systemPrompt: "You are a concise technical writer. Reply in plain English."
)
let response = try await sdk.send("Explain Result type in Swift.", model: .openAI(.gpt4o), parameters: params)
print(response.text)
```

### 5. Switch provider with one line

```swift
let sdk = TALLMKit()
sdk.configure(.openAI(key: "sk-..."))

// User changes preference in Settings → just reconfigure
sdk.configure(.gemini(key: "AIza..."))

let response = try await sdk.send("Hello!", model: .gemini(.gemini20Flash))
print(response.text)
```

### 6. Token usage tracking

```swift
let sdk = TALLMKit()
sdk.configure(.anthropic(key: "sk-ant-..."))

let response = try await sdk.send(
    "Write a haiku about Swift.",
    model: .anthropic(.claudeHaiku45)
)

if let usage = response.usage {
    print("In: \(usage.inputTokens) | Out: \(usage.outputTokens) | Total: \(usage.totalTokens)")
}
```

### 7. Tool calling

```swift
let weatherTool = Tool(
    name: "get_weather",
    description: "Get current temperature for a city",
    parameters: .object(
        properties: ["city": .string, "unit": .optional(.enum(["C", "F"]))],
        required: ["city"]
    )
)
var params = RequestParameters()
params.tools = [weatherTool]
let response = try await sdk.send("What's the weather in Paris?",
                                   model: .openAI(.gpt4oMini),
                                   parameters: params)
if let calls = response.toolCalls {
    // Execute tool locally, then send result back
    let result = try await sdk.chat(.openAI(.gpt4oMini), messages: [
        .user("What's the weather in Paris?"),
        .assistant(from: response),
        .toolResult(toolCallId: calls[0].id, content: "{\"temp\": 22, \"unit\": \"C\"}")
    ])
    print(result.text)
}
```

### 8. Typed JSON decoding

```swift
struct WeatherInfo: Decodable, Sendable {
    let city: String
    let temperature: Double
    let condition: String
}
let result = try await sdk.chat(
    .openAI(.gpt4oMini),
    messages: [.user("Give me Paris weather as JSON")],
    decoding: WeatherInfo.self
)
print(result.value.temperature) // Double
print(result.usage?.totalTokens) // Optional<Int>
```

### 9. Error handling

```swift
let sdk = TALLMKit()
sdk.configure(.openAI(key: "sk-..."))

do {
    let response = try await sdk.send("Hello", model: .openAI(.gpt4oMini))
    print(response.text)
} catch AIError.providerNotConfigured {
    print("No provider configured. Call sdk.configure(...) first.")
} catch AIError.invalidAPIKey {
    print("Invalid API key. Check your credentials.")
} catch AIError.rateLimited(let retryAfter) {
    let wait = retryAfter.map { "Retry after \($0)s." } ?? "Try again later."
    print("Rate limited. \(wait)")
} catch AIError.httpError(let status, let body) {
    print("HTTP \(status): \(body)")
} catch AIError.networkError(let error) {
    print("Network error: \(error.localizedDescription)")
} catch {
    print("Unexpected error: \(error)")
}
```

---

## Example App

A runnable SwiftUI iOS app lives in `Examples/TALLMKitExample/`.

**To open and run:**

1. Open `Examples/TALLMKitExample/TALLMKitExample.xcodeproj` in Xcode.
2. Select an iOS simulator (iOS 17+).
3. Press **⌘R** to build and run.
4. In the **Chat** tab: pick a provider, enter your API key, type a prompt, tap Send.
5. In the **Tool Demo** tab: enter your API key and tap **Run Tool Demo** to see tool calling in action.

The example app references TALLMKit as a local Swift package — no additional setup required.
