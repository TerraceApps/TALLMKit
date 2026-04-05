enum HTTPHeader {
    enum Name {
        static let contentType      = "Content-Type"
        static let authorization    = "Authorization"
        static let apiKey           = "x-api-key"
        static let anthropicVersion = "anthropic-version"
    }

    enum Value {
        static let applicationJSON  = "application/json"
        static func bearer(_ token: String) -> String { "Bearer \(token)" }
    }
}
