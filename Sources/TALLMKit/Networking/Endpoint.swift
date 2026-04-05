import Foundation

protocol Endpoint {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem] { get }
}

extension Endpoint {
    var path: String { "" }
    var queryItems: [URLQueryItem] { [] }

    func urlRequest() throws -> URLRequest {
        guard var components = URLComponents(string: baseURL) else {
            throw AIError.httpError(status: 0, body: "Invalid baseURL: \(baseURL)")
        }
        if !path.isEmpty {
            components.path = (components.path as NSString).appendingPathComponent(path)
        }
        if !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }
        guard let url = components.url else {
            throw AIError.httpError(status: 0, body: "Could not construct URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }
}
