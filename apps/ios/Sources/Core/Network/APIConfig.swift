import Foundation

enum APIConfig {
    static let baseURL = URL(string: "http://127.0.0.1:3000")!

    // Xcode 调试开关：true 使用本地 Mock；false 调用本机 Nest 后端。
    static let useMockData = false
}
