import Foundation
import Security
import XCTest
@testable import WhatDidYouDo

@MainActor
final class WhatDidYouDoTests: XCTestCase {
    func testEstimatedPointsUsesDefaultPointsAtStandardDuration() {
        let chore = makeChore(minutes: 15, points: 21)

        XCTAssertEqual(AppViewModel.estimatedPoints(for: chore, selectedMinutes: 15), 21)
    }

    func testEstimatedPointsScalesForLongerAndShorterDurations() {
        let chore = makeChore(minutes: 15, points: 21)

        XCTAssertEqual(AppViewModel.estimatedPoints(for: chore, selectedMinutes: 20), 28)
        XCTAssertEqual(AppViewModel.estimatedPoints(for: chore, selectedMinutes: 10), 14)
    }

    func testEstimatedPointsFallsBackWhenStandardDurationIsZero() {
        let chore = makeChore(minutes: 0, points: 21)

        XCTAssertEqual(AppViewModel.estimatedPoints(for: chore, selectedMinutes: 20), 21)
    }

    func testDurationMemoryUsesDefaultThenSavedValue() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = makeViewModel(defaults: fixture.defaults)
        let chore = makeChore(id: "dishes", minutes: 15, points: 21)

        XCTAssertEqual(viewModel.getDefaultDuration(for: chore), 15)

        viewModel.saveLastDuration(choreId: chore.id, minutes: 20)

        XCTAssertEqual(viewModel.getDefaultDuration(for: chore), 20)
    }

    func testDurationMemoryIsIndependentPerChore() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = makeViewModel(defaults: fixture.defaults)
        let dishes = makeChore(id: "dishes", minutes: 15, points: 21)
        let bathroom = makeChore(id: "bathroom", minutes: 30, points: 45)

        viewModel.saveLastDuration(choreId: dishes.id, minutes: 20)

        XCTAssertEqual(viewModel.getDefaultDuration(for: dishes), 20)
        XCTAssertEqual(viewModel.getDefaultDuration(for: bathroom), 30)
    }

    func testActivityItemDTOInteractionFieldsDecode() throws {
        let data = Data(
            #"""
            {
              "id": "record-1",
              "recordId": "record-1",
              "familyId": "family-1",
              "user": {
                "id": "user-1",
                "displayName": "用户一",
                "identityLabel": "老妈",
                "avatarKey": "avatar_01"
              },
              "createdBy": {
                "id": "user-1",
                "displayName": "用户一",
                "identityLabel": "老妈",
                "avatarKey": "avatar_01"
              },
              "chore": {
                "id": "chore-1",
                "name": "洗碗",
                "category": "厨房类",
                "icon": "fork.knife"
              },
              "choreName": "洗碗",
              "minutes": 15,
              "actualMinutes": 20,
              "points": 28,
              "note": null,
              "imageUrls": [],
              "likeCount": 1,
              "likedBy": [
                {
                  "id": "user-2",
                  "displayName": "用户二",
                  "identityLabel": "室友",
                  "avatarKey": "avatar_02"
                }
              ],
              "likedByMe": true,
              "canDelete": true,
              "createdAt": "2026-06-22T08:00:00.000Z"
            }
            """#.utf8
        )

        let dto = try APIClient.decoder.decode(ActivityItemDTO.self, from: data)

        XCTAssertEqual(dto.likeCount, 1)
        XCTAssertEqual(dto.likedByMe, true)
        XCTAssertEqual(dto.canDelete, true)
        XCTAssertEqual(dto.createdBy?.identityLabel, "老妈")
        XCTAssertEqual(dto.createdBy?.avatarKey, "avatar_01")
        XCTAssertEqual(dto.likedBy?.first?.identityLabel, "室友")
        XCTAssertEqual(dto.likedBy?.first?.avatarKey, "avatar_02")
    }

    func testFamilyDTOInviteAndMembershipFieldsDecode() throws {
        let data = Data(
            #"""
            {
              "id": "family-1",
              "name": "测试家庭",
              "requirePhotoProof": false,
              "timezone": "Asia/Shanghai",
              "inviteCode": "ABC12345",
              "memberRole": "OWNER",
              "status": "ACTIVE"
            }
            """#.utf8
        )

        let dto = try APIClient.decoder.decode(FamilyDTO.self, from: data)

        XCTAssertEqual(dto.inviteCode, "ABC12345")
        XCTAssertEqual(dto.timezone, "Asia/Shanghai")
        XCTAssertEqual(dto.memberRole, "OWNER")
        XCTAssertEqual(dto.status, "ACTIVE")
    }

    func testAPIConfigDebugDefaultUsesLocalSimulator() {
        let environment = APIConfig.resolvedEnvironment(
            defaultEnvironment: .localSimulator,
            overrideValue: nil,
            isDebug: true
        )

        XCTAssertEqual(environment, .localSimulator)
        XCTAssertEqual(environment.baseURL.absoluteString, "http://127.0.0.1:3000")
    }

    func testAPIConfigCanSelectLocalNetworkForDeviceDebugging() {
        let environment = APIConfig.resolvedEnvironment(
            defaultEnvironment: .localSimulator,
            overrideValue: "localNetwork",
            isDebug: true
        )

        XCTAssertEqual(environment, .localNetwork)
        XCTAssertFalse(APIConfig.isLoopbackURL(environment.baseURL))
    }

    func testAPIConfigReleaseDoesNotAllowLocalSimulator() {
        let environment = APIConfig.resolvedEnvironment(
            defaultEnvironment: .production,
            overrideValue: "localSimulator",
            isDebug: false
        )

        XCTAssertEqual(environment, .production)
        XCTAssertFalse(APIConfig.isLoopbackURL(environment.baseURL))
    }

    func testMockModeDoesNotCallNetwork() async {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = SpyAPIClient()
        let viewModel = AppViewModel(
            apiClient: client,
            dataMode: .mock,
            userDefaults: fixture.defaults
        )
        viewModel.phoneNumber = "123456"

        viewModel.mockLogin()

        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(viewModel.modeLabel, "Mock 模式")
        XCTAssertEqual(viewModel.accessToken, "mock-token")
        XCTAssertEqual(viewModel.sessionState, .authenticated)
    }

    func testAPIModeUsesInjectedAPIClient() async throws {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = SpyAPIClient()
        let tokenStore = MockSecureTokenStore()
        let viewModel = AppViewModel(
            apiClient: client,
            tokenStore: tokenStore,
            dataMode: .api,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: false
        )
        viewModel.phoneNumber = "654321"

        viewModel.mockLogin()

        for _ in 0..<50 {
            if await client.requestCount > 0 {
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }

        let paths = await client.requestPaths
        XCTAssertEqual(viewModel.modeLabel, "API 模式")
        XCTAssertEqual(paths, ["POST /auth/mock-login"])
    }

    func testKeychainStoreSavesLoadsAndDeletesToken() throws {
        let store = KeychainStore(
            service: "com.whatdidyoudo.tests.\(UUID().uuidString)",
            account: "access-token"
        )
        defer { try? store.deleteAccessToken() }

        do {
            let initialToken = try store.loadAccessToken()
            XCTAssertNil(initialToken)
            try store.saveAccessToken("keychain-test-token")
            let savedToken = try store.loadAccessToken()
            XCTAssertEqual(savedToken, "keychain-test-token")
            try store.deleteAccessToken()
            let deletedToken = try store.loadAccessToken()
            XCTAssertNil(deletedToken)
        } catch KeychainStoreError.unhandledStatus(errSecMissingEntitlement) {
            throw XCTSkip("Unsigned CI test hosts cannot access Keychain")
        }
    }

    func testAPILoginSavesAccessToken() async throws {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = StubAPIClient(responses: Self.loginResponses)
        let tokenStore = MockSecureTokenStore()
        let viewModel = AppViewModel(
            apiClient: client,
            tokenStore: tokenStore,
            dataMode: .api,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: false
        )
        viewModel.phoneNumber = "123456"

        viewModel.mockLogin()
        try await waitUntil { tokenStore.token == "api-token" && !viewModel.isLoading }

        XCTAssertEqual(viewModel.accessToken, "api-token")
        XCTAssertEqual(tokenStore.saveCount, 1)
        XCTAssertEqual(viewModel.sessionState, .authenticated)
        XCTAssertEqual(viewModel.rootScreen, .createFamily)
    }

    func testLogoutDeletesStoredToken() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let tokenStore = MockSecureTokenStore(token: "stored-token")
        let viewModel = AppViewModel(
            tokenStore: tokenStore,
            dataMode: .api,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: false
        )

        viewModel.logout()

        XCTAssertNil(tokenStore.token)
        XCTAssertEqual(tokenStore.deleteCount, 1)
        XCTAssertNil(viewModel.accessToken)
        XCTAssertEqual(viewModel.sessionState, .unauthenticated)
        XCTAssertEqual(viewModel.rootScreen, .login)
    }

    func testStoredTokenStartsInRestoringSessionState() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = StubAPIClient(responses: Self.restoreResponses)
        let tokenStore = MockSecureTokenStore(token: "restored-token")

        let viewModel = AppViewModel(
            apiClient: client,
            tokenStore: tokenStore,
            dataMode: .api,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: true
        )

        XCTAssertEqual(viewModel.sessionState, .restoringSession)
    }

    func testNoStoredTokenStartsUnauthenticated() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = StubAPIClient(responses: Self.restoreResponses)
        let tokenStore = MockSecureTokenStore()

        let viewModel = AppViewModel(
            apiClient: client,
            tokenStore: tokenStore,
            dataMode: .api,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: true
        )

        XCTAssertEqual(viewModel.sessionState, .unauthenticated)
        XCTAssertNil(viewModel.accessToken)
        XCTAssertEqual(tokenStore.loadCount, 1)
    }

    func testStoredTokenAutomaticallyRestoresSessionAndFamilyData() async throws {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = StubAPIClient(responses: Self.restoreResponses)
        let tokenStore = MockSecureTokenStore(token: "restored-token")
        let viewModel = AppViewModel(
            apiClient: client,
            tokenStore: tokenStore,
            dataMode: .api,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: true
        )

        XCTAssertEqual(viewModel.sessionState, .restoringSession)
        try await waitUntil { viewModel.rootScreen == .home && !viewModel.isLoading }

        XCTAssertEqual(viewModel.accessToken, "restored-token")
        XCTAssertEqual(viewModel.currentUser?.displayName, "用户123456")
        XCTAssertEqual(viewModel.currentFamily?.id, "family-1")
        XCTAssertEqual(viewModel.sessionState, .authenticated)
        XCTAssertEqual(viewModel.rootScreen, .home)
        XCTAssertEqual(tokenStore.loadCount, 1)
        let didSetToken = await client.didSetToken("restored-token")
        let requestPaths = await client.requestPaths
        XCTAssertTrue(didSetToken)
        XCTAssertTrue(requestPaths.contains("GET /families/me"))
        XCTAssertTrue(requestPaths.contains("GET /families/family-1/activity?range=day"))
    }

    func testUnauthorizedRestoreClearsSessionAndStoredToken() async {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = StubAPIClient(
            responses: [:],
            errors: ["GET /families/me": APIError.requestFailed(statusCode: 401, message: "Unauthorized")]
        )
        let tokenStore = MockSecureTokenStore(token: "expired-token")
        let viewModel = AppViewModel(
            apiClient: client,
            tokenStore: tokenStore,
            dataMode: .api,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: false
        )

        await viewModel.restoreSessionIfNeeded()

        XCTAssertNil(viewModel.accessToken)
        XCTAssertNil(tokenStore.token)
        XCTAssertEqual(tokenStore.deleteCount, 1)
        XCTAssertEqual(viewModel.sessionState, .unauthenticated)
        XCTAssertEqual(viewModel.rootScreen, .login)
        XCTAssertEqual(viewModel.errorMessage, "登录已失效，请重新登录。")
    }

    private func makeViewModel(defaults: UserDefaults) -> AppViewModel {
        AppViewModel(dataMode: .mock, userDefaults: defaults)
    }

    private func makeDefaultsFixture() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "WhatDidYouDoTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func makeChore(
        id: String = "test-chore",
        minutes: Int,
        points: Int
    ) -> ChoreItem {
        ChoreItem(
            id: id,
            name: "测试家务",
            category: "测试类",
            minutes: minutes,
            points: points,
            icon: "checkmark.circle",
            color: DSColor.yellow
        )
    }

    private func waitUntil(
        timeoutIterations: Int = 100,
        condition: @escaping @MainActor () async -> Bool
    ) async throws {
        for _ in 0..<timeoutIterations {
            if await condition() {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for asynchronous state")
    }

    private static let loginResponses: [String: Data] = [
        "POST /auth/mock-login": Data(
            #"{"user":{"id":"user-1","phoneNumber":"123456","displayName":"用户123456"},"accessToken":"api-token"}"#.utf8
        ),
        "GET /chores": Data("[]".utf8),
        "GET /families/me": Data("[]".utf8),
    ]

    private static let restoreResponses: [String: Data] = [
        "GET /families/me": Data(
            #"[{"id":"family-1","name":"测试家庭","requirePhotoProof":false,"timezone":"Asia/Shanghai","inviteCode":"ABC12345","memberRole":"OWNER","status":"ACTIVE","myMembership":{"id":"member-1","userId":"user-1","familyId":"family-1","identityLabel":"男主人","avatarKey":"avatar_01","memberRole":"OWNER","status":"ACTIVE","user":{"id":"user-1","phoneNumber":"123456","displayName":"用户123456"}}}]"#.utf8
        ),
        "GET /chores": Data("[]".utf8),
        "GET /families/family-1/activity?range=day": Data("[]".utf8),
        "GET /families/family-1/activity?range=recent": Data("[]".utf8),
        "GET /families/family-1/leaderboard?range=month": Data("[]".utf8),
        "GET /families/family-1/monthly-report": Data(
            #"{"familyId":"family-1","month":"2026-06","totalPoints":0,"totalRecords":0,"headline":"暂无记录","leaderboard":[],"categoryStats":[],"recentRecords":[]}"#.utf8
        ),
    ]
}

private actor SpyAPIClient: APIClientProtocol {
    private(set) var requestPaths: [String] = []

    var requestCount: Int {
        requestPaths.count
    }

    func setAccessToken(_ token: String?) {}

    func currentDebugSnapshot() -> APIDebugSnapshot {
        APIDebugSnapshot(lastRequestPath: requestPaths.last)
    }

    func get<Response: Decodable & Sendable>(
        _ path: String,
        queryItems: [URLQueryItem]
    ) async throws -> Response {
        requestPaths.append("GET /\(path)")
        throw SpyError.expectedRequest
    }

    func post<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody
    ) async throws -> Response {
        requestPaths.append("POST /\(path)")
        throw SpyError.expectedRequest
    }

    func post<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        requestPaths.append("POST /\(path)")
        throw SpyError.expectedRequest
    }

    func patch<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody
    ) async throws -> Response {
        requestPaths.append("PATCH /\(path)")
        throw SpyError.expectedRequest
    }

    func delete<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        requestPaths.append("DELETE /\(path)")
        throw SpyError.expectedRequest
    }
}

private final class MockSecureTokenStore: SecureTokenStore {
    var token: String?
    private(set) var saveCount = 0
    private(set) var loadCount = 0
    private(set) var deleteCount = 0

    init(token: String? = nil) {
        self.token = token
    }

    func saveAccessToken(_ token: String) throws {
        saveCount += 1
        self.token = token
    }

    func loadAccessToken() throws -> String? {
        loadCount += 1
        return token
    }

    func deleteAccessToken() throws {
        deleteCount += 1
        token = nil
    }
}

private actor StubAPIClient: APIClientProtocol {
    private let responses: [String: Data]
    private let errors: [String: Error]
    private(set) var requestPaths: [String] = []
    private var accessToken: String?

    init(responses: [String: Data], errors: [String: Error] = [:]) {
        self.responses = responses
        self.errors = errors
    }

    func setAccessToken(_ token: String?) {
        accessToken = token
    }

    func didSetToken(_ token: String) -> Bool {
        accessToken == token
    }

    func currentDebugSnapshot() -> APIDebugSnapshot {
        APIDebugSnapshot(lastRequestPath: requestPaths.last)
    }

    func get<Response: Decodable & Sendable>(
        _ path: String,
        queryItems: [URLQueryItem]
    ) async throws -> Response {
        try response(method: "GET", path: path, queryItems: queryItems)
    }

    func post<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody
    ) async throws -> Response {
        try response(method: "POST", path: path)
    }

    func post<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        try response(method: "POST", path: path)
    }

    func patch<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody
    ) async throws -> Response {
        try response(method: "PATCH", path: path)
    }

    func delete<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        try response(method: "DELETE", path: path)
    }

    private func response<Response: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = []
    ) throws -> Response {
        let requestKey = Self.requestKey(method: method, path: path, queryItems: queryItems)
        requestPaths.append(requestKey)

        if let error = errors[requestKey] ?? errors["\(method) /\(path)"] {
            throw error
        }

        let baseKey = "\(method) /\(path)"
        guard let data = responses[requestKey] ?? responses[baseKey] else {
            throw SpyError.expectedRequest
        }
        return try APIClient.decoder.decode(Response.self, from: data)
    }

    private static func requestKey(
        method: String,
        path: String,
        queryItems: [URLQueryItem]
    ) -> String {
        guard !queryItems.isEmpty else {
            return "\(method) /\(path)"
        }

        var components = URLComponents()
        components.queryItems = queryItems
        return "\(method) /\(path)?\(components.percentEncodedQuery ?? "")"
    }
}

private enum SpyError: LocalizedError {
    case expectedRequest

    var errorDescription: String? {
        "Expected test request"
    }
}
