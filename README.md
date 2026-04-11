<div align="center">

# TALLMKit

![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2015%20%7C%20macOS%2012%20%7C%20watchOS%208%20%7C%20tvOS%2015-blue)
![SPM](https://img.shields.io/badge/SPM-Compatible-brightgreen?logo=swift&logoColor=white)
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
    .package(url: "https://github.com/your-org/TALLMKit.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
targets: [
    .target(name: "YourApp", dependencies: ["TALLMKit"])
]
```

Or add it in **Xcode**: `File → Add Package Dependencies` and paste the repo URL.

---

## Quick Start

```swift
import TALLMKit

let sdk = TALLMKit()
sdk.configure(.openAI(key: "sk-..."))

let response = try await sdk.send("What is the Swift concurrency model?", model: .openAI(.gpt4oMini))
print(response.text)
```

That's it. Configure once, send anywhere.

---

## Quick Start

```swift
import TALLMKit

let sdk = TALLMKit()
sdk.configure(.openAI(key: "sk-..."))

let response = try await sdk.send("What is the Swift concurrency model?", model: .openAI(.gpt4oMini))
print(response.text)
```

That's it. Configure once, send anywhere.

---

## Usage

<details>
<summary><strong>All available models</strong></summary>

```swift
// OpenAI
.openAI(.gpt4oMini)   // GPT-4o Mini — fast, affordable
.openAI(.gpt4o)        // GPT-4o — flagship multimodal
.openAI(.gpt4Turbo)    // GPT-4 Turbo — 128k context
.openAI(.gpt35Turbo)   // GPT-3.5 Turbo — legacy fast

// Anthropic
.anthropic(.claudeOpus46)    // Most capable
.anthropic(.claudeSonnet46)  // Balanced
.anthropic(.claudeHaiku45)   // Fastest

// Grok (xAI)
.grok(.grok3)      // Flagship
.grok(.grok3Mini)  // Lightweight
.grok(.grok2)      // Previous gen

// Gemini
.gemini(.gemini20Flash)  // Latest fast multimodal
.gemini(.gemini15Pro)    // Long context (2M tokens)
.gemini(.gemini15Flash)  // Fast and efficient
```

</details>

### Configure providers

Register one or more providers at startup. Calling `configure` again with the same provider replaces it.

```swift
let sdk = TALLMKit()
sdk.configure(
    .openAI(key: "sk-..."),
    .anthropic(key: "sk-ant-..."),
    .grok(key: "xai-..."),
    .gemini(key: "AIza...")
)
```

---

### Single message

```swift
let response = try await sdk.send("Summarize quantum computing in one sentence.", model: .openAI(.gpt4oMini))
print(response.text)
```

### Multi-turn conversation

```swift
var history: [Message] = [
    .system("You are a helpful Swift tutor."),
    .user("What is an actor in Swift?"),
    .assistant("An actor is a reference type that protects its mutable state from data races..."),
    .user("Can actors be subclassed?")
]

let response = try await sdk.chat(.anthropic(.claudeSonnet46), messages: history)
history.append(.assistant(response.text))
```

### Request parameters

```swift
let params = RequestParameters(
    temperature: 0.3,
    maxTokens: 256,
    systemPrompt: "You are a concise technical writer."
)
let response = try await sdk.send("Explain Result type in Swift.", model: .openAI(.gpt4o), parameters: params)
```

### Token usage

```swift
let response = try await sdk.send("Write a haiku about Swift.", model: .anthropic(.claudeHaiku45))

if let usage = response.usage {
    print("↑ \(usage.inputTokens)  ↓ \(usage.outputTokens)  total \(usage.totalTokens)")
}
```

---
