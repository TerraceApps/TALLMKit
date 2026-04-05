import Foundation

struct Endpoint {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]

    func urlRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }
}

// MARK: - Builder

extension Endpoint {
    struct Builder {
        private var baseURL: URL?
        private var path: String = ""
        private var queryItems: [URLQueryItem] = []
        private var method: HTTPMethod = .post
        private var headers: [String: String] = [:]

        func baseURL(_ url: URL) -> Builder {
            var copy = self; copy.baseURL = url; return copy
        }

        func baseURL(_ string: String) -> Builder {
            var copy = self; copy.baseURL = URL(string: string); return copy
        }

        func path(_ path: String) -> Builder {
            var copy = self; copy.path = path; return copy
        }

        func queryItem(_ name: String, value: String) -> Builder {
            var copy = self
            copy.queryItems.append(URLQueryItem(name: name, value: value))
            return copy
        }

        func method(_ method: HTTPMethod) -> Builder {
            var copy = self; copy.method = method; return copy
        }

        func header(_ name: String, value: String) -> Builder {
            var copy = self; copy.headers[name] = value; return copy
        }

        func contentTypeJSON() -> Builder {
            header(HTTPHeader.Name.contentType, value: HTTPHeader.Value.applicationJSON)
        }

        func bearerAuth(_ token: String) -> Builder {
            header(HTTPHeader.Name.authorization, value: HTTPHeader.Value.bearer(token))
        }

        func build() throws -> Endpoint {
            guard let base = baseURL else {
                throw AIError.httpError(status: 0, body: "Endpoint: baseURL is required")
            }
            var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
            if !path.isEmpty {
                components.path = (components.path as NSString).appendingPathComponent(path)
            }
            if !queryItems.isEmpty {
                components.queryItems = (components.queryItems ?? []) + queryItems
            }
            guard let url = components.url else {
                throw AIError.httpError(status: 0, body: "Endpoint: could not construct URL")
            }
            return Endpoint(url: url, method: method, headers: headers)
        }
    }

    static func builder() -> Builder { Builder() }
}
