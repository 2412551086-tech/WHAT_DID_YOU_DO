import Foundation
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
              "inviteCode": "ABC12345",
              "memberRole": "OWNER",
              "status": "ACTIVE"
            }
            """#.utf8
        )

        let dto = try APIClient.decoder.decode(FamilyDTO.self, from: data)

        XCTAssertEqual(dto.inviteCode, "ABC12345")
        XCTAssertEqual(dto.memberRole, "OWNER")
        XCTAssertEqual(dto.status, "ACTIVE")
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
    }

    func testAPIModeUsesInjectedAPIClient() async throws {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = SpyAPIClient()
        let viewModel = AppViewModel(
            apiClient: client,
            dataMode: .api,
            userDefaults: fixture.defaults
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

private enum SpyError: LocalizedError {
    case expectedRequest

    var errorDescription: String? {
        "Expected test request"
    }
}
