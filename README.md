<div align="center">

# TALLMKit

![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2015%20%7C%20macOS%2012%20%7C%20watchOS%208%20%7C%20tvOS%2015-blue)
![SPM](https://img.shields.io/badge/SPM-Compatible-brightgreen?logo=swift&logoColor=white)
[![GitHub](https://img.shields.io/badge/GitHub-TerraceApps%2FTALLMKit-181717?logo=github)](https://github.com/TerraceApps/TALLMKit)
![Dependencies](https://img.shields.io/badge/Dependencies-0-success)
![Tests](https://img.shields.io/badge/Tests-76%20passing-success)

**A lightweight, provider-agnostic Swift SDK that unifies OpenAI, Anthropic, Grok, and Gemini behind a single async/await interface.**

</div>

---

## Providers

| Provider | Status | Models |
|----------|--------|--------|
| **OpenAI** | ✅ Supported | GPT-4o, GPT-4o Mini, GPT-4 Turbo, GPT-3.5 Turbo |
| **Anthropic** | ✅ Supported | Claude Opus 4.6, Claude Sonnet 4.6, Claude Haiku 4.5 |
| **Grok (xAI)** | ✅ Supported | Grok 3, Grok 3 Mini, Grok 2 |
| **Gemini** | ✅ Supported | Gemini 2.0 Flash, Gemini 1.5 Pro, Gemini 1.5 Flash |

---

## Features

- 🔀 **Unified API** — one interface for all providers, swap with a single line
- ⚡ **Concurrent requests** — fire multiple providers at once with `sdk.combine()`
- 🧠 **Multi-turn chat** — full conversation history support
- 🛠 **Tool calling** — function calling across all providers
- 📦 **Typed decoding** — decode JSON responses directly into `Decodable` types
- 🔒 **Swift 6 concurrency** — fully `Sendable`, actor-safe, zero data races
- 📊 **Token usage** — input/output/total token counts on every response
- 0️⃣ **Zero dependencies** — no third-party packages

---

## Requirements

| | Minimum |
|--|--|
| **Swift** | 6.0 |
| **iOS** | 15.0 |
| **macOS** | 12.0 |
| **watchOS** | 8.0 |
| **tvOS** | 15.0 |

---

## Installation

### Swift Package Manager

Add TALLMKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/TerraceApps/TALLMKit.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
targets: [
    .target(name: "YourApp", dependencies: ["TALLMKit"])
]
```

Or in **Xcode**: `File → Add Package Dependencies` and paste the repo URL.

---

## Quick Start

```swift
import TALLMKit

let sdk = TALLMKit()
sdk.configure(.openAI(key: "sk-..."))

let response = try await sdk.send("What is the Swift concurrency model?", model: .openAI(.gpt4oMini))
print(response.text)
```

Configure once, send anywhere.

---

## Usage

<details>
<summary><strong>All available models</strong></summary>

```swift
// OpenAI
.openAI(.gpt4oMini)   // GPT-4o Mini — fast, affordable
.openAI(.gpt4o)        // GPT-4o — flagship multimodal
.openAI(.gpt4Turbo)    // GPT-4 Turbo — 128k context
.openAI(.gpt35Turbo)   // GPT-3.5 Turbo

// Anthropic
.anthropic(.claudeOpus46)    // Most capable
.anthropic(.claudeSonnet46)  // Balanced
.anthropic(.claudeHaiku45)   // Fastest

// Grok (xAI)
.grok(.grok3)      // Flagship
.grok(.grok3Mini)  // Lightweight

// Gemini
.gemini(.gemini20Flash)  // Latest fast multimodal
.gemini(.gemini15Pro)    // Long context (2M tokens)
.gemini(.gemini15Flash)  // Fast and efficient
```

</details>

---

### Configure providers

```swift
sdk.configure(
    .openAI(key: "sk-..."),
    .anthropic(key: "sk-ant-..."),
    .grok(key: "xai-..."),
    .gemini(key: "AIza...")
)
```

> Calling `configure` again with the same provider type replaces it — useful for switching API keys at runtime.

---

### Single message

```swift
let response = try await sdk.send("Explain Swift actors in one sentence.", model: .openAI(.gpt4oMini))
print(response.text)
```

---

### Multi-turn conversation

```swift
var history: [Message] = [
    .system("You are a helpful Swift tutor."),
    .user("What is an actor?"),
    .assistant("An actor protects mutable state from data races..."),
    .user("Can they be subclassed?")
]

let response = try await sdk.chat(.anthropic(.claudeSonnet46), messages: history)
history.append(.assistant(response.text))
```

---

### Request parameters

```swift
let params = RequestParameters(temperature: 0.2, maxTokens: 256, systemPrompt: "Be concise.")
let response = try await sdk.send("What is a Result type?", model: .openAI(.gpt4o), parameters: params)
```

---

### Token usage

```swift
let response = try await sdk.send("Write a haiku about Swift.", model: .anthropic(.claudeHaiku45))
if let usage = response.usage {
    print("↑ \(usage.inputTokens)  ↓ \(usage.outputTokens)  total \(usage.totalTokens)")
}
```

---

### Concurrent multi-provider requests

Send a prompt to multiple providers simultaneously. Every slot resolves independently — one failure never blocks the others.

```swift
let multi = await sdk.combine([
    CombineRequest(tag: "openai",    message: "Best Swift feature?", model: .openAI(.gpt4oMini)),
    CombineRequest(tag: "anthropic", message: "Best Swift feature?", model: .anthropic(.claudeSonnet46)),
    CombineRequest(tag: "gemini",    message: "Best Swift feature?", model: .gemini(.gemini20Flash)),
])

for (tag, response) in multi.successes {
    print("\(tag): \(response.text)")
}

// Check failures
for (tag, error) in multi.failures {
    print("\(tag) failed: \(error)")
}
```

---

### Tool calling

Define a tool, attach it to a request, and handle the model's call:

```swift
var params = RequestParameters()
params.tools = [
    Tool(name: "get_weather", description: "Get temperature for a city",
         parameters: .object(properties: ["city": .string], required: ["city"]))
]

let first = try await sdk.send("Weather in Tokyo?", model: .openAI(.gpt4oMini), parameters: params)

if let call = first.toolCalls?.first {
    let final = try await sdk.chat(.openAI(.gpt4oMini), messages: [
        .user("Weather in Tokyo?"),
        .assistant(from: first),
        .toolResult(toolCallId: call.id, content: #"{"temp": 18, "unit": "C"}"#)
    ])
    print(final.text)
}
```

---

### Typed JSON decoding

```swift
struct Movie: Decodable, Sendable { let title: String; let year: Int; let genre: String }

let result = try await sdk.send(
    "Give me a classic Sci-Fi movie as JSON",
    model: .openAI(.gpt4oMini),
    decoding: Movie.self
)
print("\(result.value.title) (\(result.value.year))")  // "Blade Runner (1982)"
```

---

### Error handling

```swift
do {
    let response = try await sdk.send("Hello", model: .openAI(.gpt4oMini))
    print(response.text)
} catch AIError.invalidAPIKey {
    // bad or missing key
} catch AIError.rateLimited(let retryAfter) {
    // back off and retry
} catch AIError.providerNotConfigured {
    // call sdk.configure(...) first
} catch AIError.httpError(let status, _) {
    // non-2xx from the provider
}
```

---

## Example App

A runnable SwiftUI app lives in `Examples/TALLMKitExample/`. Three tabs, every feature covered:

| Tab | What it shows |
|-----|---------------|
| **Chat** | Single message send with any configured provider |
| **Tool Demo** | Live tool calling round-trip |
| **Compare** | `sdk.combine()` — same prompt, all providers, side by side |

Open `Examples/TALLMKitExample/TALLMKitExample.xcodeproj` in Xcode, select a simulator, press `⌘R`.

---

## Contributing

Pull requests are welcome. For major changes, open an issue first.

---

<div align="center">

Made with ❤️ by [TerraceApps](https://github.com/TerraceApps)

</div>
