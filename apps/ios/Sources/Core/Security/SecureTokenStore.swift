import Foundation
import Security

struct AuthTokens: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: Date
    let refreshTokenExpiresAt: Date
}

protocol SecureTokenStore: Sendable {
    func saveAccessToken(_ token: String) throws
    func loadAccessToken() throws -> String?
    func deleteAccessToken() throws
    func saveTokens(_ tokens: AuthTokens) throws
    func loadTokens() throws -> AuthTokens?
    func deleteTokens() throws
}

struct KeychainStore: SecureTokenStore {
    private let service: String
    private let account: String

    init(
        service: String = Bundle.main.bundleIdentifier ?? "com.douxiaolang.familyguard",
        account: String = "api-access-token"
    ) {
        self.service = service
        self.account = account
    }

    func saveAccessToken(_ token: String) throws {
        guard !token.isEmpty, let data = token.data(using: .utf8) else {
            throw KeychainStoreError.invalidToken
        }

        let query = baseQuery
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            var newItem = query
            attributes.forEach { newItem[$0.key] = $0.value }
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainStoreError.unhandledStatus(addStatus)
            }
            return
        }

        guard status == errSecSuccess else {
            throw KeychainStoreError.unhandledStatus(status)
        }
    }

    func loadAccessToken() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainStoreError.unhandledStatus(status)
        }

        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            throw KeychainStoreError.invalidStoredData
        }

        return token
    }

    func deleteAccessToken() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unhandledStatus(status)
        }
    }

    func saveTokens(_ tokens: AuthTokens) throws {
        guard !tokens.accessToken.isEmpty, !tokens.refreshToken.isEmpty else {
            throw KeychainStoreError.invalidToken
        }
        let data = try JSONEncoder().encode(tokens)
        try save(data: data, account: tokenPairAccount)
        try? deleteAccessToken()
    }

    func loadTokens() throws -> AuthTokens? {
        guard let data = try loadData(account: tokenPairAccount) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(AuthTokens.self, from: data)
        } catch {
            throw KeychainStoreError.invalidStoredData
        }
    }

    func deleteTokens() throws {
        try delete(account: tokenPairAccount)
        try deleteAccessToken()
    }

    private var baseQuery: [String: Any] {
        baseQuery(account: account)
    }

    private var tokenPairAccount: String {
        "\(account)-auth-tokens-v2"
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func save(data: Data, account: String) throws {
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            attributes.forEach { newItem[$0.key] = $0.value }
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainStoreError.unhandledStatus(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainStoreError.unhandledStatus(status)
        }
    }

    private func loadData(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainStoreError.unhandledStatus(status)
        }
        return data
    }

    private func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unhandledStatus(status)
        }
    }
}

enum KeychainStoreError: LocalizedError {
    case invalidToken
    case invalidStoredData
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidToken:
            return "Access token 为空，无法保存"
        case .invalidStoredData:
            return "Keychain 中的 access token 格式无效"
        case let .unhandledStatus(status):
            let message = SecCopyErrorMessageString(status, nil) as String?
            return "Keychain 操作失败（\(status)）：\(message ?? "未知错误")"
        }
    }
}
