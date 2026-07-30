import SwiftUI

enum AppDataMode {
    case configured
    case mock
    case api
}

enum AppSessionState: Equatable {
    case restoringSession
    case authenticated
    case unauthenticated
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var sessionState: AppSessionState = .restoringSession
    @Published var rootScreen: AppScreen = .login
    @Published var selectedTab: MainTab = .today
    @Published var phoneNumber = ""
    @Published var familyName = MockData.family.name
    @Published var requiresPhotoProof = false
    @Published var selectedIdentityLabel = "男主人"
    @Published var customIdentity = ""
    @Published var selectedAvatarKey = "avatar_01"
    @Published var joinInviteCode = ""
    @Published private(set) var joinRequestSubmitted = false
    @Published private(set) var accessToken: String?
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var currentFamily: FamilySpace?
    @Published private(set) var currentMembership: FamilyMembership?
    @Published private(set) var joinRequests: [JoinRequestItem] = []
    @Published private(set) var chores = MockData.chores
    @Published private(set) var choreOrder: [String] = []
    @Published private(set) var pinnedChoreIDs: Set<String> = []
    @Published private(set) var todayRecords = MockData.todayRecords
    @Published private(set) var recentRecords = MockData.todayRecords
    @Published private(set) var monthlyRanking = MockData.members
    @Published private(set) var monthlyReport: MonthlyReport? = MockData.monthlyReport
    @Published private(set) var isLoading = false
    @Published private(set) var loadingMessage: String?
    @Published var errorMessage: String?
    @Published private(set) var lastRequestPath: String?
    @Published private(set) var lastStatusCode: Int?
    @Published private(set) var lastAPIErrorMessage: String?
    @Published private(set) var lastSecureStorageErrorMessage: String?
    @Published var selectedChore: ChoreItem?

    private let apiClient: any APIClientProtocol
    private let tokenStore: any SecureTokenStore
    private let forceMockData: Bool
    private let dataMode: AppDataMode
    private let userDefaults: UserDefaults

    init(
        apiClient: any APIClientProtocol = APIClient(),
        tokenStore: any SecureTokenStore = KeychainStore(),
        forceMockData: Bool = false,
        dataMode: AppDataMode = .configured,
        userDefaults: UserDefaults = .standard,
        automaticallyRestoreSession: Bool = true
    ) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
        self.forceMockData = forceMockData
        self.dataMode = dataMode
        self.userDefaults = userDefaults

        if !forceMockData {
            choreOrder = userDefaults.stringArray(forKey: Self.choreOrderDefaultsKey) ?? []
            pinnedChoreIDs = Set(userDefaults.stringArray(forKey: Self.pinnedChoresDefaultsKey) ?? [])
        }

        synchronizeChoreLayout()

        if !automaticallyRestoreSession || usesMockData {
            sessionState = .unauthenticated
        } else {
            do {
                if let storedToken = try tokenStore.loadAccessToken() {
                    accessToken = storedToken
                    Task { [weak self] in
                        await self?.restoreSessionIfNeeded()
                    }
                } else {
                    sessionState = .unauthenticated
                }
            } catch {
                lastSecureStorageErrorMessage = error.localizedDescription
                sessionState = .unauthenticated
            }
        }
    }

    var familyDisplayName: String {
        currentFamily?.name ?? familyName
    }

    var currentUserName: String {
        currentUser?.displayName ?? MockData.currentUser.displayName
    }

    var currentIdentityDisplayName: String {
        currentMembership?.displayIdentity ?? selectedIdentityLabel
    }

    var todayPoints: Int {
        todayRecords.reduce(0) { $0 + $1.points }
    }

    var todayRecordCount: Int {
        todayRecords.count
    }

    var leader: FamilyMember? {
        monthlyRanking.max { $0.monthlyPoints < $1.monthlyPoints }
    }

    var modeLabel: String {
        usesMockData ? "Mock 模式" : "API 模式"
    }

    var debugBaseURL: String {
        APIConfig.baseURL.absoluteString
    }

    var debugAPIEnvironment: String {
        APIConfig.environmentLabel
    }

    var debugFamilyTimezone: String {
        currentFamily?.timezone ?? TimeZone.current.identifier
    }

    var hasAccessToken: Bool {
        !(accessToken?.isEmpty ?? true)
    }

    var isCurrentUserOwner: Bool {
        currentMembership?.memberRole == .owner && currentMembership?.status == .active
    }

    var displayedChores: [ChoreItem] {
        let unlockedByID = Dictionary(uniqueKeysWithValues: chores.filter { !$0.isLocked }.map { ($0.id, $0) })
        let savedUnlocked = choreOrder.compactMap { unlockedByID[$0] }
        let savedIDs = Set(savedUnlocked.map(\.id))
        let newUnlocked = chores.filter { !$0.isLocked && !savedIDs.contains($0.id) }
        let orderedUnlocked = savedUnlocked + newUnlocked
        let pinned = orderedUnlocked.filter { pinnedChoreIDs.contains($0.id) }
        let unpinned = orderedUnlocked.filter { !pinnedChoreIDs.contains($0.id) }
        let locked = chores.filter(\.isLocked)

        return pinned + unpinned + locked
    }

    func mockLogin() {
        clearError()

        guard !normalizedPhoneNumber.isEmpty else {
            errorMessage = AppStateError.missingPhoneNumber.localizedDescription
            return
        }

        guard !usesMockData else {
            loginWithMock()
            return
        }

        Task {
            await loginWithAPI()
        }
    }

    func restoreSessionIfNeeded() async {
        guard !usesMockData else {
            return
        }

        do {
            if accessToken == nil {
                accessToken = try tokenStore.loadAccessToken()
            }
        } catch {
            let storageError = error.localizedDescription
            await clearInvalidSession()
            lastSecureStorageErrorMessage = storageError
            return
        }

        guard let accessToken, !accessToken.isEmpty else {
            resetSessionState()
            return
        }

        sessionState = .restoringSession
        await apiClient.setAccessToken(accessToken)
        await performLoading("正在恢复登录状态") {
            let families = try await loadMyFamiliesFromAPI()
            restoreCurrentUser(from: families)
            try await loadChoresFromAPI()

            if families.isEmpty {
                rootScreen = .createFamily
            } else {
                selectedTab = .today
                rootScreen = .home
                try await refreshHomeDataFromAPI(includeChores: false)
            }

            sessionState = .authenticated
        }

        if sessionState == .restoringSession {
            await clearInvalidSession()
            errorMessage = "登录状态恢复失败，请重新登录。"
        }
    }

    func showCreateFamily() {
        joinRequestSubmitted = false
        clearError()
        rootScreen = .createFamily
    }

    func showJoinFamily() {
        joinRequestSubmitted = false
        clearError()
        rootScreen = .joinFamily
    }

    func createFamily() {
        clearError()

        guard validateIdentitySelection() else {
            return
        }

        guard !usesMockData else {
            createFamilyWithMock()
            return
        }

        Task {
            await createFamilyWithAPI()
        }
    }

    func submitJoinRequest() {
        clearError()

        guard !joinInviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = AppStateError.missingFamilyIdentifier.localizedDescription
            return
        }

        guard validateIdentitySelection() else {
            return
        }

        guard !usesMockData else {
            joinRequestSubmitted = true
            return
        }

        Task {
            await submitJoinRequestWithAPI()
        }
    }

    func loadJoinRequests() {
        clearError()

        guard isCurrentUserOwner else {
            errorMessage = AppStateError.ownerRequired.localizedDescription
            return
        }

        guard !usesMockData else {
            joinRequests = MockData.joinRequests
            return
        }

        Task {
            await performLoading("正在获取待审核成员") {
                try await loadJoinRequestsFromAPI()
            }
        }
    }

    func reviewJoinRequest(_ request: JoinRequestItem, approve: Bool) {
        clearError()

        guard isCurrentUserOwner else {
            errorMessage = AppStateError.ownerRequired.localizedDescription
            return
        }

        guard !usesMockData else {
            joinRequests.removeAll { $0.id == request.id }
            return
        }

        Task {
            await performLoading(approve ? "正在通过加入申请" : "正在拒绝加入申请") {
                guard let familyId = currentFamily?.id else {
                    throw AppStateError.missingFamily
                }

                let _: JoinRequestDTO = try await apiClient.patch(
                    "families/\(familyId)/join-requests/\(request.id)",
                    body: ReviewJoinRequestRequest(action: approve ? "approve" : "reject")
                )
                try await loadJoinRequestsFromAPI()
            }
        }
    }

    func showChoreSelection() {
        selectedTab = .record
    }

    func isChorePinned(_ chore: ChoreItem) -> Bool {
        pinnedChoreIDs.contains(chore.id)
    }

    func toggleChorePinned(_ chore: ChoreItem) {
        guard !chore.isLocked else {
            return
        }

        var order = normalizedUnlockedOrder()
        order.removeAll { $0 == chore.id }
        order.insert(chore.id, at: 0)

        if pinnedChoreIDs.contains(chore.id) {
            pinnedChoreIDs.remove(chore.id)
        } else {
            pinnedChoreIDs.insert(chore.id)
        }

        choreOrder = order
        persistChoreLayout()
    }

    @discardableResult
    func moveUnlockedChore(_ sourceID: String, to targetID: String) -> Bool {
        guard sourceID != targetID,
              let source = chores.first(where: { $0.id == sourceID && !$0.isLocked }),
              let target = chores.first(where: { $0.id == targetID && !$0.isLocked }),
              isChorePinned(source) == isChorePinned(target)
        else {
            return false
        }

        var order = normalizedUnlockedOrder()
        guard let sourceIndex = order.firstIndex(of: sourceID),
              let targetIndex = order.firstIndex(of: targetID)
        else {
            return false
        }

        order.remove(at: sourceIndex)
        order.insert(sourceID, at: min(targetIndex, order.count))
        choreOrder = order
        persistChoreLayout()
        return true
    }

    func record(_ chore: ChoreItem, actualMinutes: Int? = nil, calculatedPoints: Int? = nil) {
        clearError()

        guard !chore.isLocked else {
            errorMessage = "这个家务需要 \(chore.requiredPlan) 套餐，MVP 先不记录它。"
            return
        }

        guard !usesMockData else {
            recordWithMock(chore, actualMinutes: actualMinutes, calculatedPoints: calculatedPoints)
            return
        }

        Task {
            await createRecordWithAPI(chore, actualMinutes: actualMinutes)
        }
    }

    func toggleLike(_ record: ChoreRecord) {
        clearError()

        guard !usesMockData else {
            let shouldLike = !record.likedByMe
            let liker = ActivityLiker(
                id: currentUser?.id ?? MockData.currentUser.id,
                displayName: currentUserName,
                avatarKey: currentMembership?.avatarKey
            )
            Self.updateMockLike(in: &todayRecords, recordID: record.id, shouldLike: shouldLike, liker: liker)
            Self.updateMockLike(in: &recentRecords, recordID: record.id, shouldLike: shouldLike, liker: liker)
            return
        }

        Task {
            await performLoading(record.likedByMe ? "正在取消点赞" : "正在点赞") {
                if record.likedByMe {
                    let _: LikeResponseDTO = try await apiClient.delete("chore-records/\(record.id)/like")
                } else {
                    let _: LikeResponseDTO = try await apiClient.post("chore-records/\(record.id)/like")
                }
                try await refreshActivityFromAPI()
            }
        }
    }

    func deleteRecord(_ record: ChoreRecord) {
        clearError()

        guard record.canDelete else {
            errorMessage = AppStateError.deleteForbidden.localizedDescription
            return
        }

        guard !usesMockData else {
            deleteRecordWithMock(record)
            return
        }

        Task {
            await performLoading("正在删除家务记录") {
                let _: DeleteRecordResponseDTO = try await apiClient.delete("chore-records/\(record.id)")
                try await refreshHomeDataFromAPI()
            }
        }
    }

    func refreshHomeDataIfNeeded() {
        guard !usesMockData, !isLoading, accessToken != nil, currentFamily != nil else {
            return
        }

        Task {
            await performLoading("正在同步家庭战况") {
                try await refreshHomeDataFromAPI()
            }
        }
    }

    static func estimatedPoints(for chore: ChoreItem, selectedMinutes: Int) -> Int {
        guard chore.minutes > 0 else {
            return chore.points
        }

        if selectedMinutes == chore.minutes {
            return chore.points
        }

        return max(1, Int((Double(chore.points) * Double(selectedMinutes) / Double(chore.minutes)).rounded()))
    }

    func getDefaultDuration(for chore: ChoreItem) -> Int {
        let standardMinutes = max(1, min(180, chore.minutes))
        guard let storedValue = userDefaults.object(
            forKey: Self.lastDurationKey(for: chore.id)
        ) as? NSNumber else {
            return standardMinutes
        }

        let storedMinutes = storedValue.intValue
        guard (1...180).contains(storedMinutes) else {
            return standardMinutes
        }

        return storedMinutes
    }

    func saveLastDuration(choreId: String, minutes: Int) {
        let normalizedMinutes = max(1, min(180, minutes))
        userDefaults.set(normalizedMinutes, forKey: Self.lastDurationKey(for: choreId))
    }

    func logout() {
        resetSessionState()

        do {
            try tokenStore.deleteAccessToken()
            lastSecureStorageErrorMessage = nil
        } catch {
            lastSecureStorageErrorMessage = error.localizedDescription
        }

        Task {
            await apiClient.setAccessToken(nil)
        }
    }

    private func resetSessionState() {
        accessToken = nil
        currentUser = nil
        currentFamily = nil
        currentMembership = nil
        joinRequests = []
        joinRequestSubmitted = false
        selectedChore = nil
        selectedTab = .today
        phoneNumber = ""
        familyName = MockData.family.name
        joinInviteCode = ""
        chores = usesMockData ? MockData.chores : []
        todayRecords = usesMockData ? MockData.todayRecords : []
        recentRecords = usesMockData ? MockData.todayRecords : []
        monthlyRanking = usesMockData ? MockData.members : []
        monthlyReport = usesMockData ? MockData.monthlyReport : nil
        rootScreen = .login
        sessionState = .unauthenticated
        clearError()
    }

    private var usesMockData: Bool {
        if forceMockData {
            return true
        }

        switch dataMode {
        case .configured:
            return APIConfig.useMockData
        case .mock:
            return true
        case .api:
            return false
        }
    }

    private var normalizedCustomIdentity: String? {
        guard selectedIdentityLabel == "自定义" else { return nil }
        let normalized = customIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func validateIdentitySelection() -> Bool {
        if selectedIdentityLabel == "自定义" && normalizedCustomIdentity == nil {
            errorMessage = AppStateError.missingCustomIdentity.localizedDescription
            return false
        }

        return true
    }

    private func loginWithMock() {
        accessToken = "mock-token"
        currentUser = MockData.currentUser
        currentFamily = nil
        currentMembership = nil
        replaceChores(MockData.chores)
        todayRecords = MockData.todayRecords
        recentRecords = MockData.todayRecords
        monthlyRanking = MockData.members
        monthlyReport = MockData.monthlyReport
        rootScreen = .createFamily
        sessionState = .authenticated
    }

    private func createFamilyWithMock() {
        currentFamily = FamilySpace(
            id: MockData.family.id,
            name: trimmedFamilyName,
            inviteCode: MockData.family.inviteCode,
            requiresPhotoProof: false,
            timezone: TimeZone.current.identifier
        )
        currentMembership = FamilyMembership(
            id: "mock-membership-\(UUID().uuidString)",
            userId: currentUser?.id ?? MockData.currentUser.id,
            familyId: MockData.family.id,
            identityLabel: selectedIdentityLabel,
            customIdentity: normalizedCustomIdentity,
            avatarKey: selectedAvatarKey,
            memberRole: .owner,
            status: .active
        )
        selectedTab = .today
        rootScreen = .home
        sessionState = .authenticated
    }

    private func recordWithMock(_ chore: ChoreItem, actualMinutes: Int? = nil, calculatedPoints: Int? = nil) {
        selectedChore = chore
        let minutes = max(1, min(180, actualMinutes ?? chore.minutes))
        let points = calculatedPoints ?? Self.estimatedPoints(for: chore, selectedMinutes: minutes)

        let record = ChoreRecord(
            id: "mock-record-\(UUID().uuidString)",
            memberName: currentUserName,
            choreName: chore.name,
            category: chore.category,
            standardMinutes: chore.minutes,
            actualMinutes: minutes,
            points: points,
            note: "\(chore.name)完成，家务宇宙记一笔",
            createdAt: Date(),
            icon: chore.icon,
            color: chore.color,
            creatorId: currentUser?.id,
            identityLabel: currentMembership?.identityLabel ?? selectedIdentityLabel,
            customIdentity: currentMembership?.customIdentity,
            avatarKey: currentMembership?.avatarKey ?? selectedAvatarKey,
            likeCount: 0,
            likedByMe: false,
            canDelete: true
        )

        todayRecords.insert(record, at: 0)
        recentRecords.insert(record, at: 0)
        addMonthlyPoints(points, to: currentUserName)
        updateMockMonthlyReport()
        selectedTab = .today
        rootScreen = .home
        sessionState = .authenticated
    }

    private func deleteRecordWithMock(_ record: ChoreRecord) {
        todayRecords.removeAll { $0.id == record.id }
        recentRecords.removeAll { $0.id == record.id }

        if let index = monthlyRanking.firstIndex(where: { $0.id == record.creatorId || $0.name == record.memberName }) {
            monthlyRanking[index].monthlyPoints = max(0, monthlyRanking[index].monthlyPoints - record.points)
            monthlyRanking.sort { $0.monthlyPoints > $1.monthlyPoints }
        }

        updateMockMonthlyReport()
    }

    private static func updateMockLike(
        in records: inout [ChoreRecord],
        recordID: String,
        shouldLike: Bool,
        liker: ActivityLiker
    ) {
        guard let index = records.firstIndex(where: { $0.id == recordID }) else { return }

        records[index].likedByMe = shouldLike
        if shouldLike {
            if !records[index].likedBy.contains(where: { $0.id == liker.id }) {
                records[index].likedBy.append(liker)
            }
        } else {
            records[index].likedBy.removeAll { $0.id == liker.id }
        }
        records[index].likeCount = records[index].likedBy.count
    }

    private func updateMockMonthlyReport() {
        monthlyReport = MonthlyReport(
            month: currentMonth,
            totalPoints: monthlyRanking.reduce(0) { $0 + $1.monthlyPoints },
            totalRecords: todayRecords.count,
            headline: "家庭互动已同步，功劳簿继续营业"
        )
    }

    private func loginWithAPI() async {
        await performLoading("正在连接本地后端") {
            let response: LoginResponse = try await apiClient.post(
                "auth/mock-login",
                body: MockLoginRequest(phoneNumber: normalizedPhoneNumber)
            )

            accessToken = response.accessToken
            currentUser = mapUser(response.user)
            await apiClient.setAccessToken(response.accessToken)

            do {
                try tokenStore.saveAccessToken(response.accessToken)
                lastSecureStorageErrorMessage = nil
            } catch {
                lastSecureStorageErrorMessage = error.localizedDescription
            }

            try await loadChoresFromAPI()
            let families = try await loadMyFamiliesFromAPI()

            if families.isEmpty {
                rootScreen = .createFamily
            } else {
                selectedTab = .today
                rootScreen = .home
                try await refreshHomeDataFromAPI()
            }

            sessionState = .authenticated
        }
    }

    private func createFamilyWithAPI() async {
        await performLoading("正在创建家庭空间") {
            let family: FamilyDTO = try await apiClient.post(
                "families",
                body: CreateFamilyRequest(
                    name: trimmedFamilyName,
                    requirePhotoProof: false,
                    identityLabel: selectedIdentityLabel,
                    customIdentity: normalizedCustomIdentity,
                    avatarKey: selectedAvatarKey,
                    timezone: TimeZone.current.identifier
                )
            )

            currentFamily = mapFamily(family)
            currentMembership = membership(from: family)
            _ = try await loadMyFamiliesFromAPI(preferredFamilyId: family.id)
            selectedTab = .today
            rootScreen = .home
            sessionState = .authenticated
            try await refreshHomeDataFromAPI()
        }
    }

    private func submitJoinRequestWithAPI() async {
        await performLoading("正在提交加入申请") {
            let inviteCode = joinInviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
            let _: JoinRequestDTO = try await apiClient.post(
                "families/join-requests",
                body: CreateJoinRequestRequest(
                    inviteCode: inviteCode,
                    identityLabel: selectedIdentityLabel,
                    customIdentity: normalizedCustomIdentity,
                    avatarKey: selectedAvatarKey
                )
            )
            joinRequestSubmitted = true
        }
    }

    private func loadJoinRequestsFromAPI() async throws {
        guard let familyId = currentFamily?.id else {
            throw AppStateError.missingFamily
        }

        let response: [JoinRequestDTO] = try await apiClient.get("families/\(familyId)/join-requests")
        joinRequests = response.map(mapJoinRequest)
    }

    private func createRecordWithAPI(_ chore: ChoreItem, actualMinutes: Int?) async {
        await performLoading("正在记录实际耗时") {
            guard let familyId = currentFamily?.id else {
                throw AppStateError.missingFamily
            }

            let minutes = max(1, min(180, actualMinutes ?? chore.minutes))
            let record: ChoreRecordDTO = try await apiClient.post(
                "chore-records",
                body: CreateChoreRecordRequest(
                    familyId: familyId,
                    choreId: chore.id,
                    actualMinutes: minutes,
                    note: "\(chore.name) · iOS 创建",
                    imageUrls: []
                )
            )

            todayRecords.insert(mapRecord(record), at: 0)
            recentRecords.insert(mapRecord(record), at: 0)
            selectedTab = .today
            try await refreshHomeDataFromAPI()
        }
    }

    private func loadChoresFromAPI() async throws {
        let response: [ChoreDTO] = try await apiClient.get("chores")
        replaceChores(response.map(mapChore))
    }

    private func replaceChores(_ newChores: [ChoreItem]) {
        chores = newChores
        synchronizeChoreLayout()
    }

    private func synchronizeChoreLayout() {
        let unlockedIDs = chores.filter { !$0.isLocked }.map(\.id)
        let availableIDs = Set(unlockedIDs)
        let saved = choreOrder.filter { availableIDs.contains($0) }
        let savedIDs = Set(saved)
        choreOrder = saved + unlockedIDs.filter { !savedIDs.contains($0) }
        pinnedChoreIDs = pinnedChoreIDs.intersection(availableIDs)
        persistChoreLayout()
    }

    private func normalizedUnlockedOrder() -> [String] {
        let unlockedIDs = chores.filter { !$0.isLocked }.map(\.id)
        let availableIDs = Set(unlockedIDs)
        let saved = choreOrder.filter { availableIDs.contains($0) }
        let savedIDs = Set(saved)
        return saved + unlockedIDs.filter { !savedIDs.contains($0) }
    }

    private func persistChoreLayout() {
        guard !forceMockData else {
            return
        }

        userDefaults.set(choreOrder, forKey: Self.choreOrderDefaultsKey)
        userDefaults.set(Array(pinnedChoreIDs), forKey: Self.pinnedChoresDefaultsKey)
    }

    @discardableResult
    private func loadMyFamiliesFromAPI(preferredFamilyId: String? = nil) async throws -> [FamilyDTO] {
        let families: [FamilyDTO] = try await apiClient.get("families/me")

        if let preferredFamilyId, let family = families.first(where: { $0.id == preferredFamilyId }) {
            applyCurrentFamily(family)
        } else if let family = families.first {
            applyCurrentFamily(family)
        } else {
            currentFamily = nil
            currentMembership = nil
        }

        return families
    }

    private func applyCurrentFamily(_ family: FamilyDTO) {
        currentFamily = mapFamily(family)
        currentMembership = membership(from: family)
        familyName = family.name
        requiresPhotoProof = family.requirePhotoProof
    }

    private func refreshHomeDataFromAPI(includeChores: Bool = true) async throws {
        guard let familyId = currentFamily?.id else {
            return
        }

        if includeChores {
            try await loadChoresFromAPI()
        }

        async let todayActivity: [ActivityItemDTO] = apiClient.get(
            "families/\(familyId)/activity",
            queryItems: [URLQueryItem(name: "range", value: "day")]
        )
        async let recentActivity: [ActivityItemDTO] = apiClient.get(
            "families/\(familyId)/activity",
            queryItems: [URLQueryItem(name: "range", value: "recent")]
        )
        async let leaderboard: [LeaderboardItemDTO] = apiClient.get(
            "families/\(familyId)/leaderboard",
            queryItems: [URLQueryItem(name: "range", value: "month")]
        )
        async let report: MonthlyReportDTO = apiClient.get(
            "families/\(familyId)/monthly-report",
            queryItems: [URLQueryItem(name: "month", value: currentMonth)]
        )

        let (todayItems, recentItems, leaderboardItems, monthlyReportDTO) = try await (
            todayActivity,
            recentActivity,
            leaderboard,
            report
        )

        todayRecords = todayItems.map(mapActivity)
        recentRecords = recentItems.map(mapActivity)
        monthlyRanking = leaderboardItems.enumerated().map { index, item in
            FamilyMember(
                id: item.userId,
                name: item.displayName,
                monthlyPoints: item.points,
                badge: "\(item.recordCount) 条记录",
                color: Self.palette[index % Self.palette.count]
            )
        }
        monthlyReport = mapMonthlyReport(monthlyReportDTO)
    }

    private func refreshActivityFromAPI() async throws {
        guard let familyId = currentFamily?.id else {
            throw AppStateError.missingFamily
        }

        async let todayActivity: [ActivityItemDTO] = apiClient.get(
            "families/\(familyId)/activity",
            queryItems: [URLQueryItem(name: "range", value: "day")]
        )
        async let recentActivity: [ActivityItemDTO] = apiClient.get(
            "families/\(familyId)/activity",
            queryItems: [URLQueryItem(name: "range", value: "recent")]
        )
        let (todayItems, recentItems) = try await (todayActivity, recentActivity)
        todayRecords = todayItems.map(mapActivity)
        recentRecords = recentItems.map(mapActivity)
    }

    private func performLoading(_ message: String, operation: () async throws -> Void) async {
        isLoading = true
        loadingMessage = message
        errorMessage = nil

        do {
            try await operation()
        } catch {
            if let apiError = error as? APIError, apiError.isUnauthorized {
                await clearInvalidSession()
                errorMessage = "登录已失效，请重新登录。"
            } else {
                errorMessage = error.localizedDescription
            }
        }

        await syncAPIDebugSnapshot()
        isLoading = false
        loadingMessage = nil
    }

    private func clearInvalidSession() async {
        resetSessionState()
        await apiClient.setAccessToken(nil)

        do {
            try tokenStore.deleteAccessToken()
            lastSecureStorageErrorMessage = nil
        } catch {
            lastSecureStorageErrorMessage = error.localizedDescription
        }
    }

    private func syncAPIDebugSnapshot() async {
        let snapshot = await apiClient.currentDebugSnapshot()
        lastRequestPath = snapshot.lastRequestPath
        lastStatusCode = snapshot.lastStatusCode
        lastAPIErrorMessage = snapshot.lastErrorMessage
    }

    private func clearError() {
        errorMessage = nil
    }

    private var normalizedPhoneNumber: String {
        phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedFamilyName: String {
        let trimmed = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? MockData.family.name : trimmed
    }

    private var currentMonth: String {
        Self.monthFormatter.string(from: Date())
    }

    private func addMonthlyPoints(_ points: Int, to memberName: String) {
        if let index = monthlyRanking.firstIndex(where: { $0.id == currentUser?.id || $0.name == memberName }) {
            monthlyRanking[index].monthlyPoints += points
        } else {
            monthlyRanking.insert(
                FamilyMember(id: currentUser?.id ?? "mock-user-\(UUID().uuidString)", name: memberName, monthlyPoints: points, badge: "新晋家务选手", color: DSColor.yellow),
                at: 0
            )
        }

        monthlyRanking.sort { $0.monthlyPoints > $1.monthlyPoints }
    }

    private func mapUser(_ dto: UserDTO) -> AppUser {
        AppUser(
            id: dto.id,
            displayName: dto.displayName,
            avatarInitial: String(dto.displayName.prefix(1)),
            badge: usesMockData ? "今日值班观察员" : "API 联调用户"
        )
    }

    private func restoreCurrentUser(from families: [FamilyDTO]) {
        let user = families.lazy.compactMap { family in
            family.myMembership?.user
                ?? family.members?.first(where: { $0.id == family.myMembership?.id })?.user
        }.first

        if let user {
            currentUser = mapUser(user)
        }
    }

    private func mapFamily(_ dto: FamilyDTO) -> FamilySpace {
        FamilySpace(
            id: dto.id,
            name: dto.name,
            inviteCode: dto.inviteCode,
            requiresPhotoProof: dto.requirePhotoProof,
            timezone: dto.timezone
        )
    }

    private func membership(from family: FamilyDTO) -> FamilyMembership? {
        if let membership = family.myMembership {
            return mapMembership(membership)
        }

        if let currentUserId = currentUser?.id,
           let membership = family.members?.first(where: { $0.userId == currentUserId }) {
            return mapMembership(membership)
        }

        guard let userId = currentUser?.id,
              let memberRole = family.memberRole ?? family.myRole?.uppercased(),
              let role = FamilyMemberRole(rawValue: memberRole),
              let status = FamilyMemberStatus(rawValue: family.status ?? "ACTIVE") else {
            return nil
        }

        return FamilyMembership(
            id: "membership-\(family.id)-\(userId)",
            userId: userId,
            familyId: family.id,
            identityLabel: family.identityLabel ?? "家庭成员",
            customIdentity: family.customIdentity,
            avatarKey: family.avatarKey,
            memberRole: role,
            status: status
        )
    }

    private func mapMembership(_ dto: FamilyMemberDTO) -> FamilyMembership? {
        let roleValue = dto.memberRole ?? dto.role?.uppercased() ?? "MEMBER"
        let statusValue = dto.status ?? "ACTIVE"

        guard let role = FamilyMemberRole(rawValue: roleValue),
              let status = FamilyMemberStatus(rawValue: statusValue) else {
            return nil
        }

        return FamilyMembership(
            id: dto.id,
            userId: dto.userId,
            familyId: dto.familyId,
            identityLabel: dto.identityLabel ?? "家庭成员",
            customIdentity: dto.customIdentity,
            avatarKey: dto.avatarKey,
            memberRole: role,
            status: status
        )
    }

    private func mapJoinRequest(_ dto: JoinRequestDTO) -> JoinRequestItem {
        JoinRequestItem(
            id: dto.id,
            userId: dto.userId,
            displayName: dto.user?.displayName ?? "待审核成员",
            identityLabel: dto.identityLabel,
            customIdentity: dto.customIdentity,
            avatarKey: dto.avatarKey,
            status: FamilyMemberStatus(rawValue: dto.status) ?? .pending
        )
    }

    private func mapChore(_ dto: ChoreDTO) -> ChoreItem {
        ChoreItem(
            id: dto.id,
            name: dto.name,
            category: dto.category,
            minutes: dto.minutes,
            points: dto.points,
            icon: Self.icon(forName: dto.name, category: dto.category),
            color: Self.color(forCategory: dto.category),
            isLocked: dto.isLocked,
            requiredPlan: dto.requiredPlan
        )
    }

    private func mapRecord(_ dto: ChoreRecordDTO) -> ChoreRecord {
        let creator = dto.createdBy ?? dto.user
        return ChoreRecord(
            id: dto.recordId ?? dto.id,
            memberName: creator.displayName,
            choreName: dto.choreName ?? dto.chore.name,
            category: dto.chore.category,
            standardMinutes: dto.minutes,
            actualMinutes: dto.actualMinutes ?? dto.minutes,
            points: dto.points,
            note: dto.note ?? "",
            createdAt: dto.createdAt,
            icon: dto.chore.icon ?? Self.icon(forName: dto.chore.name, category: dto.chore.category),
            color: Self.color(forCategory: dto.chore.category),
            creatorId: creator.id,
            identityLabel: creator.identityLabel ?? "家庭成员",
            customIdentity: creator.customIdentity,
            avatarKey: creator.avatarKey,
            likeCount: dto.likeCount ?? 0,
            likedBy: mapLikers(dto.likedBy),
            likedByMe: dto.likedByMe ?? false,
            canDelete: dto.canDelete ?? true
        )
    }

    private func mapActivity(_ dto: ActivityItemDTO) -> ChoreRecord {
        let creator = dto.createdBy ?? dto.user
        return ChoreRecord(
            id: dto.recordId ?? dto.id,
            memberName: creator.displayName,
            choreName: dto.choreName ?? dto.chore.name,
            category: dto.chore.category,
            standardMinutes: dto.minutes,
            actualMinutes: dto.actualMinutes ?? dto.minutes,
            points: dto.points,
            note: dto.note ?? "",
            createdAt: dto.createdAt,
            icon: dto.chore.icon ?? Self.icon(forName: dto.chore.name, category: dto.chore.category),
            color: Self.color(forCategory: dto.chore.category),
            creatorId: creator.id,
            identityLabel: creator.identityLabel ?? "家庭成员",
            customIdentity: creator.customIdentity,
            avatarKey: creator.avatarKey,
            likeCount: dto.likeCount ?? 0,
            likedBy: mapLikers(dto.likedBy),
            likedByMe: dto.likedByMe ?? false,
            canDelete: dto.canDelete ?? false
        )
    }

    private func mapMonthlyReport(_ dto: MonthlyReportDTO) -> MonthlyReport {
        MonthlyReport(
            month: dto.month,
            totalPoints: dto.totalPoints,
            totalRecords: dto.totalRecords,
            headline: dto.headline
        )
    }

    private func mapLikers(_ users: [RecordUserDTO]?) -> [ActivityLiker] {
        (users ?? []).map { user in
            ActivityLiker(id: user.id, displayName: user.displayName, avatarKey: user.avatarKey)
        }
    }

    private static func icon(forName name: String, category: String) -> String {
        switch name {
        case "做饭", "做饭 / 备餐":
            return "flame.fill"
        case "洗碗", "饭后收拾 / 洗碗":
            return "fork.knife"
        case "洗衣服":
            return "washer.fill"
        case "晾衣服":
            return "wind"
        case "叠衣服", "收衣 / 叠衣", "收衣 / 叠衣 / 放回衣柜":
            return "square.stack.3d.up.fill"
        case "扫地", "扫地 / 吸尘":
            return "sparkles"
        case "拖地", "拖地 / 地面湿清洁":
            return "drop.fill"
        case "整理收纳":
            return "shippingbox.fill"
        case "清理卫生间", "卫生间清洁":
            return "shower.fill"
        case "倒垃圾", "倒垃圾 / 垃圾分类":
            return "trash.fill"
        case "采购补货 / 家庭物资管理":
            return "cart.fill"
        case "换床单":
            return "bed.double.fill"
        case "清理灶台":
            return "flame.fill"
        case "搬重物":
            return "shippingbox.fill"
        case "遛狗", "清理猫砂":
            return "pawprint.fill"
        case "陪孩子写作业":
            return "book.fill"
        case "预约维修":
            return "wrench.and.screwdriver.fill"
        case "喂奶":
            return "waterbottle.fill"
        case "遛娃":
            return "figure.walk"
        case "接送孩子":
            return "car.fill"
        case "浇花":
            return "leaf.fill"
        default:
            if category.contains("厨房") { return "fork.knife" }
            if category.contains("洗护") { return "washer.fill" }
            if category.contains("照顾") { return "leaf.fill" }
            if category.contains("宠物") { return "pawprint.fill" }
            if category.contains("管理") { return "calendar.badge.clock" }
            return "checkmark.circle.fill"
        }
    }

    private static func color(forCategory category: String) -> Color {
        if category.contains("厨房") { return DSColor.yellow }
        if category.contains("清洁") { return DSColor.sky }
        if category.contains("洗护") { return DSColor.mint }
        if category.contains("照顾") { return DSColor.lavender }
        if category.contains("宠物") { return DSColor.clay }
        if category.contains("管理") { return DSColor.coral }
        return DSColor.surface
    }

    private static let palette = [
        DSColor.yellow,
        DSColor.mint,
        DSColor.sky,
        DSColor.lavender,
        DSColor.clay,
        DSColor.coral,
    ]

    private static let choreOrderDefaultsKey = "chore-card-order-v1"
    private static let pinnedChoresDefaultsKey = "chore-card-pinned-v1"

    private static func lastDurationKey(for choreId: String) -> String {
        "chore_last_duration_\(choreId)"
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    static func previewLoggedIn() -> AppViewModel {
        let viewModel = AppViewModel(forceMockData: true)
        viewModel.currentUser = MockData.currentUser
        viewModel.currentFamily = MockData.family
        viewModel.currentMembership = MockData.currentMembership
        viewModel.joinRequests = MockData.joinRequests
        viewModel.accessToken = "mock-token"
        return viewModel
    }

    static func previewHomeAfterNewRecord() -> AppViewModel {
        let viewModel = previewLoggedIn()
        viewModel.recordWithMock(MockData.chores[1])
        return viewModel
    }
}

private enum AppStateError: LocalizedError {
    case missingPhoneNumber
    case missingFamily
    case missingFamilyIdentifier
    case missingCustomIdentity
    case ownerRequired
    case deleteForbidden

    var errorDescription: String? {
        switch self {
        case .missingPhoneNumber:
            return "请输入手机号。联调账号不限制手机号长度。"
        case .missingFamily:
            return "还没有当前家庭，请先创建家庭"
        case .missingFamilyIdentifier:
            return "请输入家庭邀请码。"
        case .missingCustomIdentity:
            return "选择自定义身份后，请填写身份名称"
        case .ownerRequired:
            return "只有一家之主可以审核加入申请"
        case .deleteForbidden:
            return "你没有权限删除这条家务记录"
        }
    }
}
