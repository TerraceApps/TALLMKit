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
