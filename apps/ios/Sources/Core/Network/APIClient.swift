import CryptoKit
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

    static func isConnectivityError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else {
            return false
        }

        return [
            .notConnectedToInternet,
            .networkConnectionLost,
            .cannotConnectToHost,
            .cannotFindHost,
            .dnsLookupFailed,
            .timedOut,
        ].contains(urlError.code)
    }
}

struct APIDebugSnapshot: Sendable {
    var lastRequestPath: String?
    var lastStatusCode: Int?
    var lastErrorMessage: String?
    var usedCachedResponse = false
    var cachedResponseDate: Date?
}

protocol APIClientProtocol: Sendable {
    func setAccessToken(_ token: String?) async
    func setAuthTokens(_ tokens: AuthTokens?) async
    func setPreferCachedResponses(_ enabled: Bool) async
    func clearCachedResponses() async
    func currentDebugSnapshot() async -> APIDebugSnapshot
    func consumeOfflineFallbackFlag() async -> Bool
    func get<Response: Decodable & Sendable>(
        _ path: String,
        queryItems: [URLQueryItem]
    ) async throws -> Response
    func post<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody,
        headers: [String: String]
    ) async throws -> Response
    func post<Response: Decodable & Sendable>(_ path: String) async throws -> Response
    func patch<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody
    ) async throws -> Response
    func delete<Response: Decodable & Sendable>(_ path: String) async throws -> Response
}

extension APIClientProtocol {
    func setAuthTokens(_ tokens: AuthTokens?) async {
        await setAccessToken(tokens?.accessToken)
    }
    func setPreferCachedResponses(_ enabled: Bool) async {}
    func clearCachedResponses() async {}
    func consumeOfflineFallbackFlag() async -> Bool { false }

    func get<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        try await get(path, queryItems: [])
    }

    func post<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody
    ) async throws -> Response {
        try await post(path, body: body, headers: [:])
    }
}

actor APIClient: APIClientProtocol {
    private let baseURL: URL
    private let responseCache: APIResponseCache
    private let tokenStore: any SecureTokenStore
    private let urlSession: URLSession
    private var accessToken: String?
    private var authTokens: AuthTokens?
    private var refreshTask: Task<AuthTokens, Error>?
    private var debugSnapshot = APIDebugSnapshot()
    private var usedOfflineFallback = false
    private var preferCachedResponses = false

    init(
        baseURL: URL = APIConfig.baseURL,
        responseCache: APIResponseCache = APIResponseCache(),
        tokenStore: any SecureTokenStore = KeychainStore(),
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.responseCache = responseCache
        self.tokenStore = tokenStore
        self.urlSession = urlSession
    }

    func setAccessToken(_ token: String?) {
        accessToken = token
        if token == nil {
            authTokens = nil
        }
    }

    func setAuthTokens(_ tokens: AuthTokens?) async {
        authTokens = tokens
        accessToken = tokens?.accessToken
    }

    func setPreferCachedResponses(_ enabled: Bool) {
        preferCachedResponses = enabled
    }

    func clearCachedResponses() async {
        await responseCache.removeAll()
    }

    func currentDebugSnapshot() -> APIDebugSnapshot {
        debugSnapshot
    }

    func consumeOfflineFallbackFlag() -> Bool {
        defer { usedOfflineFallback = false }
        return usedOfflineFallback
    }

    func get<Response: Decodable & Sendable>(
        _ path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        try await request(path, method: "GET", queryItems: queryItems, body: Optional<Data>.none)
    }

    func post<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody,
        headers: [String: String]
    ) async throws -> Response {
        let data = try Self.encoder.encode(body)
        return try await request(path, method: "POST", body: data, headers: headers)
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
        body: Data?,
        headers: [String: String] = [:],
        allowsAuthRetry: Bool = true
    ) async throws -> Response {
        let displayPath = Self.displayPath(path, queryItems: queryItems)
        debugSnapshot = APIDebugSnapshot(lastRequestPath: displayPath)

        do {
            if authTokens != nil && !Self.isAuthenticationEntryPoint(path) {
                try await refreshTokensIfNeeded(force: false)
            }

            let cacheKey = Self.cacheKey(
                baseURL: baseURL,
                accessToken: accessToken,
                displayPath: displayPath
            )
            if method == "GET",
               preferCachedResponses,
               let cached = await responseCache.load(for: cacheKey),
               let decoded = try? Self.decoder.decode(Response.self, from: cached.data) {
                usedOfflineFallback = true
                debugSnapshot.lastErrorMessage = "启动时已载入本地数据"
                debugSnapshot.usedCachedResponse = true
                debugSnapshot.cachedResponseDate = cached.savedAt
                return decoded
            }

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

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = method
            urlRequest.timeoutInterval = 8
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

            for (name, value) in headers {
                urlRequest.setValue(value, forHTTPHeaderField: name)
            }

            if let body {
                urlRequest.httpBody = body
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }

            if let accessToken {
                urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await urlSession.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            debugSnapshot.lastStatusCode = httpResponse.statusCode

            if httpResponse.statusCode == 401,
               allowsAuthRetry,
               authTokens != nil,
               !Self.isAuthenticationEntryPoint(path) {
                try await refreshTokensIfNeeded(force: true)
                return try await request(
                    path,
                    method: method,
                    queryItems: queryItems,
                    body: body,
                    headers: headers,
                    allowsAuthRetry: false
                )
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = Self.decodeErrorMessage(from: data)
                throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: message)
            }

            // Nest/Express serializes a successful `null` result as an empty body.
            // Normalizing it keeps optional response contracts decodable while
            // non-optional response types still fail loudly.
            let responseData = data.isEmpty ? Data("null".utf8) : data
            let decoded = try Self.decoder.decode(Response.self, from: responseData)
            debugSnapshot.lastErrorMessage = nil
            if method == "GET" {
                await responseCache.save(responseData, for: cacheKey)
            }
            return decoded
        } catch {
            let cacheKey = Self.cacheKey(
                baseURL: baseURL,
                accessToken: accessToken,
                displayPath: displayPath
            )
            if method == "GET",
               APIError.isConnectivityError(error),
               let cached = await responseCache.load(for: cacheKey),
               let decoded = try? Self.decoder.decode(Response.self, from: cached.data) {
                usedOfflineFallback = true
                debugSnapshot.lastStatusCode = nil
                debugSnapshot.lastErrorMessage = "网络不可用，正在使用本地数据"
                debugSnapshot.usedCachedResponse = true
                debugSnapshot.cachedResponseDate = cached.savedAt
                return decoded
            }
            debugSnapshot.lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    private static func isAuthenticationEntryPoint(_ path: String) -> Bool {
        path.hasPrefix("auth/mock-login")
            || path.hasPrefix("auth/email/")
            || path.hasPrefix("auth/refresh")
    }

    private func refreshTokensIfNeeded(force: Bool) async throws {
        guard let tokens = authTokens else { return }
        if !force && tokens.accessTokenExpiresAt.timeIntervalSinceNow > 120 {
            return
        }
        if let refreshTask {
            let refreshed = try await refreshTask.value
            try install(refreshed)
            return
        }

        let baseURL = baseURL
        let urlSession = urlSession
        let task = Task<AuthTokens, Error> {
            try await Self.refreshTokens(
                baseURL: baseURL,
                refreshToken: tokens.refreshToken,
                urlSession: urlSession
            )
        }
        refreshTask = task
        defer { refreshTask = nil }

        do {
            let refreshed = try await task.value
            try install(refreshed)
        } catch {
            if !force,
               APIError.isConnectivityError(error),
               tokens.accessTokenExpiresAt > Date() {
                return
            }
            throw error
        }
    }

    private func install(_ tokens: AuthTokens) throws {
        authTokens = tokens
        accessToken = tokens.accessToken
        try tokenStore.saveTokens(tokens)
    }

    private static func refreshTokens(
        baseURL: URL,
        refreshToken: String,
        urlSession: URLSession
    ) async throws -> AuthTokens {
        let url = baseURL.appendingPathComponent("auth/refresh")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(RefreshTokenRequest(refreshToken: refreshToken))

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: decodeErrorMessage(from: data)
            )
        }
        return try decoder.decode(RefreshTokenResponse.self, from: data).tokens
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

    private static func cacheKey(baseURL: URL, accessToken: String?, displayPath: String) -> String {
        let tokenScope = accessToken.flatMap(jwtSessionId) ?? accessToken.map(stableHash) ?? "public"
        return "\(baseURL.absoluteString)|\(tokenScope)|\(displayPath)"
    }

    private static func jwtSessionId(_ token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count == 3,
              let data = Data(base64URLEncoded: String(parts[1])),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return payload["sid"] as? String
    }

    private static func stableHash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
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

private extension Data {
    init?(base64URLEncoded value: String) {
        var normalized = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder != 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: normalized)
    }
}

struct CachedAPIResponse: Codable, Sendable {
    let data: Data
    let savedAt: Date
}

actor APIResponseCache {
    private let directoryURL: URL

    init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directoryURL = base.appendingPathComponent("WhatDidYouDo/APIResponseCache", isDirectory: true)
        }
    }

    func save(_ data: Data, for key: String) {
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
            let envelope = CachedAPIResponse(data: data, savedAt: Date())
            let encoded = try JSONEncoder().encode(envelope)
            try encoded.write(to: fileURL(for: key), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            // A cache write must never block a successful API response.
        }
    }

    func load(for key: String) -> CachedAPIResponse? {
        guard let data = try? Data(contentsOf: fileURL(for: key)) else { return nil }
        return try? JSONDecoder().decode(CachedAPIResponse.self, from: data)
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    private func fileURL(for key: String) -> URL {
        let filename = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return directoryURL.appendingPathComponent(filename).appendingPathExtension("json")
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
