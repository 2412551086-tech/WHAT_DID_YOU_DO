import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "接口地址不正确"
        case .invalidResponse:
            return "后端返回格式不正确"
        case let .requestFailed(statusCode, message):
            return "请求失败 \(statusCode)：\(message)"
        }
    }

    var isUnauthorized: Bool {
        if case let .requestFailed(statusCode, _) = self {
            return statusCode == 401
        }
        return false
    }
}

struct APIDebugSnapshot: Sendable {
    var lastRequestPath: String?
    var lastStatusCode: Int?
    var lastErrorMessage: String?
}

protocol APIClientProtocol: Sendable {
    func setAccessToken(_ token: String?) async
    func currentDebugSnapshot() async -> APIDebugSnapshot
    func get<Response: Decodable & Sendable>(
        _ path: String,
        queryItems: [URLQueryItem]
    ) async throws -> Response
    func post<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody
    ) async throws -> Response
    func post<Response: Decodable & Sendable>(_ path: String) async throws -> Response
    func patch<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody
    ) async throws -> Response
    func delete<Response: Decodable & Sendable>(_ path: String) async throws -> Response
}

extension APIClientProtocol {
    func get<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        try await get(path, queryItems: [])
    }
}

actor APIClient: APIClientProtocol {
    private let baseURL: URL
    private var accessToken: String?
    private var debugSnapshot = APIDebugSnapshot()

    init(baseURL: URL = APIConfig.baseURL) {
        self.baseURL = baseURL
    }

    func setAccessToken(_ token: String?) {
        accessToken = token
    }

    func currentDebugSnapshot() -> APIDebugSnapshot {
        debugSnapshot
    }

    func get<Response: Decodable & Sendable>(
        _ path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        try await request(path, method: "GET", queryItems: queryItems, body: Optional<Data>.none)
    }

    func post<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody
    ) async throws -> Response {
        let data = try Self.encoder.encode(body)
        return try await request(path, method: "POST", body: data)
    }

    func post<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        try await request(path, method: "POST", body: Optional<Data>.none)
    }

    func patch<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody
    ) async throws -> Response {
        let data = try Self.encoder.encode(body)
        return try await request(path, method: "PATCH", body: data)
    }

    func delete<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        try await request(path, method: "DELETE", body: Optional<Data>.none)
    }

    private func request<Response: Decodable & Sendable>(
        _ path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data?
    ) async throws -> Response {
        debugSnapshot = APIDebugSnapshot(lastRequestPath: Self.displayPath(path, queryItems: queryItems))

        do {
            guard var components = URLComponents(
                url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
                resolvingAgainstBaseURL: false
            ) else {
                throw APIError.invalidURL
            }

            if !queryItems.isEmpty {
                components.queryItems = queryItems
            }

            guard let url = components.url else {
                throw APIError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            if let body {
                request.httpBody = body
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }

            if let accessToken {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            debugSnapshot.lastStatusCode = httpResponse.statusCode

            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = Self.decodeErrorMessage(from: data)
                throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: message)
            }

            let decoded = try Self.decoder.decode(Response.self, from: data)
            debugSnapshot.lastErrorMessage = nil
            return decoded
        } catch {
            debugSnapshot.lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    private static func displayPath(_ path: String, queryItems: [URLQueryItem]) -> String {
        let normalizedPath = "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !queryItems.isEmpty else {
            return normalizedPath
        }

        var components = URLComponents()
        components.queryItems = queryItems
        return normalizedPath + (components.percentEncodedQuery.map { "?\($0)" } ?? "")
    }

    private static let encoder: JSONEncoder = {
        JSONEncoder()
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = APIClient.decodeDate(value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date string: \(value)"
            )
        }
        return decoder
    }()

    private static func decodeDate(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]
        return plainFormatter.date(from: value)
    }

    private static func decodeErrorMessage(from data: Data) -> String {
        if let error = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            if let messages = error.messageList {
                return messages.joined(separator: "，")
            }
            return error.message ?? error.error ?? "未知错误"
        }

        return String(data: data, encoding: .utf8) ?? "未知错误"
    }
}

private struct APIErrorResponse: Decodable {
    let message: String?
    let error: String?
    let messageList: [String]?

    enum CodingKeys: String, CodingKey {
        case message
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = try container.decodeIfPresent(String.self, forKey: .error)

        if let single = try? container.decodeIfPresent(String.self, forKey: .message) {
            message = single
            messageList = nil
        } else {
            message = nil
            messageList = try container.decodeIfPresent([String].self, forKey: .message)
        }
    }
}
