import Foundation

enum Endpoints {
    struct OpenAI: Endpoint {
        let apiKey: String
        var baseURL: String { "https://api.openai.com/v1" }
        var path: String { "chat/completions" }
        var method: HTTPMethod { .post }
        var headers: [String: String] {
            [
                HTTPHeader.Name.contentType: HTTPHeader.Value.applicationJSON,
                HTTPHeader.Name.authorization: HTTPHeader.Value.bearer(apiKey)
            ]
        }
    }

    struct Grok: Endpoint {
        let apiKey: String
        var baseURL: String { "https://api.x.ai/v1" }
        var path: String { "chat/completions" }
        var method: HTTPMethod { .post }
        var headers: [String: String] {
            [
                HTTPHeader.Name.contentType: HTTPHeader.Value.applicationJSON,
                HTTPHeader.Name.authorization: HTTPHeader.Value.bearer(apiKey)
            ]
        }
    }

    struct Anthropic: Endpoint {
        let apiKey: String
        var baseURL: String { "https://api.anthropic.com/v1/messages" }
        var method: HTTPMethod { .post }
        var headers: [String: String] {
            [
                HTTPHeader.Name.contentType: HTTPHeader.Value.applicationJSON,
                HTTPHeader.Name.apiKey: apiKey,
                HTTPHeader.Name.anthropicVersion: "2023-06-01"
            ]
        }
    }

    struct Gemini: Endpoint {
        let apiKey: String
        let model: String
        var baseURL: String { "https://generativelanguage.googleapis.com/v1beta/models" }
        var path: String { "\(model):generateContent" }
        var method: HTTPMethod { .post }
        var headers: [String: String] {
            [HTTPHeader.Name.contentType: HTTPHeader.Value.applicationJSON]
        }
        var queryItems: [URLQueryItem] {
            [URLQueryItem(name: "key", value: apiKey)]
        }
    }
}
