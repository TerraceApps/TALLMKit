// Examples/TALLMKitExample/TALLMKitExample/ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var viewModel = ChatViewModel()

    var body: some View {
        TabView {
            ChatTab(viewModel: viewModel)
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
            ToolDemoTab(viewModel: viewModel)
                .tabItem { Label("Tool Demo", systemImage: "wrench.and.screwdriver") }
            CompareTab(viewModel: viewModel)
                .tabItem { Label("Compare", systemImage: "rectangle.split.3x1") }
        }
    }
}

// MARK: – Shared provider/model/key controls

struct ProviderSettingsView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        Section("Provider") {
            Picker("Provider", selection: $viewModel.selectedProvider) {
                ForEach(ProviderOption.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.selectedProvider) {
                viewModel.selectedModel = viewModel.availableModels.first ?? ""
            }

            Picker("Model", selection: $viewModel.selectedModel) {
                ForEach(viewModel.availableModels, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)

            SecureField("API Key", text: $viewModel.apiKey)
                .textContentType(.password)
                .autocorrectionDisabled()
        }
    }
}

// MARK: – Chat Tab

struct ChatTab: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        NavigationStack {
            Form {
                ProviderSettingsView(viewModel: viewModel)

                Section("Prompt") {
                    TextField("Enter your message…", text: $viewModel.prompt, axis: .vertical)
                        .lineLimit(3...6)
                    Button(action: viewModel.send) {
                        if viewModel.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Label("Send", systemImage: "paperplane.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .buttonStyle(.borderedProminent)
                }

                if !viewModel.response.isEmpty {
                    Section("Response") {
                        Text(viewModel.response)
                            .textSelection(.enabled)
                        if !viewModel.usageText.isEmpty {
                            Text(viewModel.usageText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("TALLMKit Chat")
        }
    }
}

// MARK: – Tool Demo Tab

struct ToolDemoTab: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        NavigationStack {
            Form {
                ProviderSettingsView(viewModel: viewModel)

                Section {
                    Text("Tap the button to ask the model about Paris weather. The SDK passes a `get_weather` tool; if the model calls it, the result is fed back for a final answer.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button(action: viewModel.toolDemo) {
                        if viewModel.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Label("Run Tool Demo", systemImage: "bolt.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .buttonStyle(.borderedProminent)
                } header: {
                    Text("Weather Tool Demo")
                }

                if !viewModel.toolDemoOutput.isEmpty {
                    Section("Output") {
                        Text(viewModel.toolDemoOutput)
                            .textSelection(.enabled)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Tool Demo")
        }
    }
}

// MARK: – Compare Tab

struct CompareTab: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("API Keys (enter one or more)") {
                    SecureField("OpenAI key (sk-...)", text: $viewModel.combineOpenAIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    SecureField("Anthropic key (sk-ant-...)", text: $viewModel.combineAnthropicKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    SecureField("Gemini key (AIza...)", text: $viewModel.combineGeminiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                }

                Section("Prompt") {
                    TextField("Ask all providers the same question…", text: $viewModel.combinePrompt, axis: .vertical)
                        .lineLimit(3...6)
                    Button(action: viewModel.runCompare) {
                        if viewModel.isCombineLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Label("Compare Providers", systemImage: "arrow.triangle.branch")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.isCombineLoading)
                    .buttonStyle(.borderedProminent)
                }

                if !viewModel.combineResults.isEmpty {
                    ForEach(viewModel.combineResults, id: \.tag) { entry in
                        Section {
                            switch entry.result {
                            case .success(let text):
                                Text(text)
                                    .textSelection(.enabled)
                            case .failure(let message):
                                Label(message, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .font(.callout)
                            }
                        } header: {
                            HStack(spacing: 4) {
                                if case .success = entry.result {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                } else {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                }
                                Text(entry.tag)
                            }
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Compare Providers")
        }
    }
}

#Preview {
    ContentView()
}
