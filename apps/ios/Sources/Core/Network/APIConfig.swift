import Foundation

enum APIEnvironment: String, CaseIterable, Sendable {
    case localSimulator
    case localNetwork
    case production

    var displayName: String {
        switch self {
        case .localSimulator:
            return "Local Simulator"
        case .localNetwork:
            return "Local Network"
        case .production:
            return "Production"
        }
    }

    var baseURL: URL {
        switch self {
        case .localSimulator:
            return URL(string: "http://127.0.0.1:3000")!
        case .localNetwork:
            return APIConfig.localNetworkBaseURL
        case .production:
            return APIConfig.productionBaseURL
        }
    }
}

enum APIConfig {
    // Xcode Scheme 可通过环境变量覆盖：
    // WDD_API_ENV=localSimulator | localNetwork | production
    // WDD_LOCAL_NETWORK_BASE_URL=http://<Mac 局域网 IP>:3000
    static var environment: APIEnvironment {
        resolvedEnvironment(
            defaultEnvironment: defaultEnvironment,
            overrideValue: ProcessInfo.processInfo.environment["WDD_API_ENV"],
            isDebug: isDebugBuild
        )
    }

    static var environmentLabel: String {
        environment.displayName
    }

    static var baseURL: URL {
        validatedBaseURL(environment.baseURL)
    }

    // Xcode 调试开关：true 使用本地 Mock；false 调用本机 Nest 后端。
    static let useMockData = false

    static var localNetworkBaseURL: URL {
        url(
            from: ProcessInfo.processInfo.environment["WDD_LOCAL_NETWORK_BASE_URL"]
                ?? Bundle.main.object(forInfoDictionaryKey: "WDDLocalNetworkBaseURL") as? String,
            fallback: "http://192.168.1.30:3000"
        )
    }

    static var productionBaseURL: URL {
        url(
            from: ProcessInfo.processInfo.environment["WDD_PRODUCTION_BASE_URL"],
            fallback: "https://api.douxiaolang.com"
        )
    }

    static func resolvedEnvironment(
        defaultEnvironment: APIEnvironment,
        overrideValue: String?,
        isDebug: Bool
    ) -> APIEnvironment {
        let requested = overrideValue.flatMap(APIEnvironment.init(rawValue:)) ?? defaultEnvironment

        guard isDebug || requested != .localSimulator else {
            return .production
        }

        return requested
    }

    static func isLoopbackURL(_ url: URL) -> Bool {
        guard let host = url.host(percentEncoded: false)?.lowercased() else {
            return false
        }

        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    private static var defaultEnvironment: APIEnvironment {
        #if DEBUG
        #if targetEnvironment(simulator)
        .localSimulator
        #else
        .localNetwork
        #endif
        #else
        .production
        #endif
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    private static func validatedBaseURL(_ url: URL) -> URL {
        #if DEBUG
        return url
        #else
        guard !isLoopbackURL(url) else {
            assertionFailure("Release build must not use a loopback API baseURL.")
            return productionBaseURL
        }
        return url
        #endif
    }

    private static func url(from value: String?, fallback: String) -> URL {
        guard let value,
              let url = URL(string: value),
              url.scheme != nil,
              url.host(percentEncoded: false) != nil
        else {
            return URL(string: fallback)!
        }

        return url
    }
}
