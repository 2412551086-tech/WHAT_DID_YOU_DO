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

private struct PendingChoreRecordUpload: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let familyId: String
    let choreId: String
    let choreName: String
    let category: String
    let standardMinutes: Int
    let defaultPoints: Int
    let icon: String
    let actualMinutes: Int
    let calculatedPoints: Int
    let pointsMultiplier: Double?
    let note: String
    let createdAt: Date
    let memberName: String
    let identityLabel: String
    let customIdentity: String?
    let avatarKey: String?

    var localRecordID: String { "offline-\(id)" }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var sessionState: AppSessionState = .restoringSession
    @Published var rootScreen: AppScreen = .onboarding
    @Published var selectedTab: MainTab = .today
    @Published var developmentIdentifier = "dev-local-user"
    @Published var displayName = ""
    @Published var familyName = MockData.family.name
    @Published var requiresPhotoProof = false
    @Published var selectedIdentityLabel = "家庭成员"
    @Published var customIdentity = ""
    @Published var selectedAvatarKey = "avatar_07"
    @Published var joinInviteCode = ""
    @Published private(set) var joinRequestSubmitted = false
    @Published private(set) var inviteValidationState: InviteValidationState = .idle
    @Published private(set) var currentJoinApplication: JoinApplication?
    @Published private(set) var reviewingRequestID: String?
    @Published private(set) var reviewErrors: [String: String] = [:]
    @Published private(set) var accessToken: String?
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var currentFamily: FamilySpace?
    @Published private(set) var currentMembership: FamilyMembership?
    @Published private(set) var familyMembers: [FamilyMemberProfile] = []
    @Published private(set) var memberActivityByMemberID: [String: [ChoreRecord]] = [:]
    @Published private(set) var joinRequests: [JoinRequestItem] = []
    @Published private(set) var chores = MockData.chores
    @Published private(set) var choreOrder: [String] = []
    @Published private(set) var pinnedChoreIDs: Set<String> = []
    @Published private(set) var commonChoreGridOrder: [String] = []
    @Published private(set) var choreLayoutConfigured = false
    @Published private(set) var choreLayoutCanEdit = true
    @Published private(set) var choreLayoutScope = "family"
    @Published private(set) var choreLayoutIsPersonalized = false
    @Published private(set) var followsFamilyChoreLayout = true
    @Published private(set) var serverCommonChoreSelectionLimit: Int? = 6
    @Published private(set) var serverCustomChoreLimit = 2
    @Published private(set) var weekRecords = MockData.todayRecords
    @Published private(set) var recentRecords = MockData.todayRecords
    @Published private(set) var weekRanking = MockData.members
    @Published private(set) var monthlyRanking = MockData.members
    @Published private(set) var monthlyReport: MonthlyReport? = MockData.monthlyReport
    @Published private(set) var selectedWeekOffset = 0
    @Published private(set) var selectedReportMonth: String
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMonthlyReport = false
    @Published private(set) var loadingMessage: String?
    @Published private(set) var isOffline = false
    @Published private(set) var lastSuccessfulSyncAt: Date?
    @Published private(set) var pendingUploadCount = 0
    @Published private(set) var isSyncingPendingRecords = false
    @Published var errorMessage: String?
    @Published private(set) var lastRequestPath: String?
    @Published private(set) var lastStatusCode: Int?
    @Published private(set) var lastAPIErrorMessage: String?
    @Published private(set) var lastSecureStorageErrorMessage: String?
    @Published private(set) var hasPremiumAccess = false
    @Published var selectedChore: ChoreItem?
    @Published private(set) var achievementSummary: AchievementSummary?
    @Published private(set) var achievementItems: [AchievementItem] = []
    @Published private(set) var showAchievementsToFamily = true
    @Published private(set) var achievementDataState: AchievementDataState = .idle
    @Published private(set) var achievementSyncState: AchievementSyncState = .idle
    @Published private(set) var achievementLastUpdatedAt: Date?
    @Published var pendingAchievementCelebration: AchievementCelebration?
    @Published private(set) var pendingRecordDeletion: PendingRecordDeletion?
    @Published private(set) var isRestoringDeletedRecord = false
    @Published private(set) var recordUndoErrorMessage: String?
    @Published private(set) var localDraftFamily: LocalDraftFamily?
    @Published private(set) var pendingAuthAction: PendingAuthAction?

    private let apiClient: any APIClientProtocol
    private let tokenStore: any SecureTokenStore
    private let forceMockData: Bool
    private let dataMode: AppDataMode
    private let userDefaults: UserDefaults
    private let localWorkspaceStore: any LocalWorkspaceStoreProtocol
    private var commonChoreGridScope: String?
    private var hiddenCommonCustomSlotIDs: Set<String> = []
    private var accountHasPremiumAccess = false
    private var achievementSyncTask: Task<Void, Never>?
    private var dismissedAchievementCelebrationIDs: Set<String> = []
    private var deletionUndoTask: Task<Void, Never>?
    private var pendingRecordUploads: [PendingChoreRecordUpload] = []

    init(
        apiClient: any APIClientProtocol = APIClient(),
        tokenStore: any SecureTokenStore = KeychainStore(),
        forceMockData: Bool = false,
        dataMode: AppDataMode = .configured,
        userDefaults: UserDefaults = .standard,
        localWorkspaceStore: any LocalWorkspaceStoreProtocol = FileLocalWorkspaceStore(),
        automaticallyRestoreSession: Bool = true
    ) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
        self.forceMockData = forceMockData
        self.dataMode = dataMode
        self.userDefaults = userDefaults
        self.localWorkspaceStore = localWorkspaceStore
        self.selectedReportMonth = Self.monthFormatter.string(from: Date())
        self.pendingRecordUploads = Self.loadPendingRecordUploads(from: userDefaults)
        self.pendingUploadCount = pendingRecordUploads.count

        if !forceMockData {
            choreOrder = userDefaults.stringArray(forKey: Self.choreOrderDefaultsKey) ?? []
            pinnedChoreIDs = Set(userDefaults.stringArray(forKey: Self.pinnedChoresDefaultsKey) ?? [])
        }

        if automaticallyRestoreSession && !usesMockData {
            do {
                localDraftFamily = try localWorkspaceStore.load()
            } catch {
                lastSecureStorageErrorMessage = error.localizedDescription
            }
        }

        if let localDraftFamily {
            applyLocalDraft(localDraftFamily)
        } else {
            synchronizeChoreLayout()
        }

        if !automaticallyRestoreSession || usesMockData {
            sessionState = .unauthenticated
            rootScreen = localDraftFamily == nil ? .onboarding : localDraftDestination
        } else {
            do {
                if let storedTokens = try tokenStore.loadTokens() {
                    userDefaults.set(true, forKey: Self.hasAuthenticatedBeforeDefaultsKey)
                    accessToken = storedTokens.accessToken
                    Task { [weak self] in
                        await self?.restoreSession(using: storedTokens)
                    }
                } else {
                    try? tokenStore.deleteAccessToken()
                    sessionState = .unauthenticated
                    rootScreen = unauthenticatedDestination
                }
            } catch {
                lastSecureStorageErrorMessage = error.localizedDescription
                sessionState = .unauthenticated
                rootScreen = unauthenticatedDestination
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

    var weekPoints: Int {
        weekRecords.reduce(0) { $0 + $1.points }
    }

    var weekRecordCount: Int {
        weekRecords.count
    }

    var leader: FamilyMember? {
        monthlyRanking.max { $0.monthlyPoints < $1.monthlyPoints }
    }

    var monthlyLeaderIllustrationAsset: String {
        let leadingMember = monthlyRanking
            .filter { $0.monthlyPoints > 0 }
            .sorted {
                if $0.monthlyPoints == $1.monthlyPoints {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return $0.monthlyPoints > $1.monthlyPoints
            }
            .first

        let avatarKey: String
        if let leadingMember,
           let member = familyMembers.first(where: { $0.userId == leadingMember.id }),
           let memberAvatarKey = member.avatarKey {
            avatarKey = memberAvatarKey
        } else if leadingMember?.id == currentUser?.id,
                  let currentAvatarKey = currentMembership?.avatarKey {
            avatarKey = currentAvatarKey
        } else {
            avatarKey = FamilyIdentityOptions.avatarKeys[0]
        }

        return FamilyIdentityOptions.actionAsset(for: avatarKey)
    }

    var modeLabel: String {
        isGuestWorkspace ? "本机体验" : (usesMockData ? "Mock 模式" : "API 模式")
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

    var distributionRegion: DistributionRegion { .configured }

    var availableAuthProviders: [ClientAuthProvider] {
        distributionRegion.providers
    }

    var nextAchievement: AchievementItem? {
        upcomingAchievements.first
    }

    var upcomingAchievements: [AchievementItem] {
        Array(
            achievementItems
                .filter { !$0.isUnlocked }
                .sorted { left, right in
                    if left.clampedProgress != right.clampedProgress {
                        return left.clampedProgress > right.clampedProgress
                    }
                    if (left.reward != nil) != (right.reward != nil) {
                        return left.reward != nil
                    }
                    return left.name.localizedStandardCompare(right.name) == .orderedAscending
                }
                .prefix(3)
        )
    }

    var unlockedAchievements: [AchievementItem] {
        achievementItems
            .filter(\.isUnlocked)
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
    }

    var orderedAchievements: [AchievementItem] {
        unlockedAchievements + achievementItems
            .filter { !$0.isUnlocked }
            .sorted(by: achievementPriority)
    }

    private func achievementPriority(_ left: AchievementItem, _ right: AchievementItem) -> Bool {
        if (left.reward != nil) != (right.reward != nil) {
            return left.reward != nil
        }
        if left.clampedProgress != right.clampedProgress {
            return left.clampedProgress > right.clampedProgress
        }
        return left.name.localizedStandardCompare(right.name) == .orderedAscending
    }

    var isCurrentUserOwner: Bool {
        currentMembership?.memberRole == .owner && currentMembership?.status == .active
    }

    var transferableFamilyMembers: [FamilyMemberProfile] {
        familyMembers.filter {
            $0.status == .active && $0.memberRole == .member && $0.userId != currentUser?.id
        }
    }

    var orderedActiveFamilyMembers: [FamilyMemberProfile] {
        familyMembers
            .filter { $0.status == .active }
            .sorted { left, right in
                if left.memberRole != right.memberRole {
                    return left.memberRole == .owner
                }
                if left.joinedAt != right.joinedAt {
                    return left.joinedAt < right.joinedAt
                }
                return left.id < right.id
            }
    }

    var canSelectNextReportMonth: Bool {
        selectedReportMonth < currentMonth
    }

    var canSelectNextWeek: Bool {
        selectedWeekOffset < 0
    }

    var selectedWeekLabel: String {
        switch selectedWeekOffset {
        case 0:
            return "本周"
        case -1:
            return "上周"
        case -2:
            return "上上周"
        default:
            let calendar = Self.weekCalendar
            let anchor = calendar.date(byAdding: .weekOfYear, value: selectedWeekOffset, to: Date()) ?? Date()
            let month = calendar.component(.month, from: anchor)
            let weekOfMonth = calendar.component(.weekOfMonth, from: anchor)
            return "\(month)月第\(weekOfMonth)周"
        }
    }

    var selectedWeekAccessibilityLabel: String {
        let calendar = Self.weekCalendar
        let anchor = calendar.date(byAdding: .weekOfYear, value: selectedWeekOffset, to: Date()) ?? Date()
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: anchor) else {
            return selectedWeekLabel
        }

        let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        return "\(selectedWeekLabel)，\(Self.weekDateFormatter.string(from: interval.start))至\(Self.weekDateFormatter.string(from: end))"
    }

    var selectedReportMonthLabel: String {
        guard let date = Self.monthFormatter.date(from: selectedReportMonth) else {
            return selectedReportMonth
        }
        return Self.monthDisplayFormatter.string(from: date)
    }

    var displayedChores: [ChoreItem] {
        let choresByID = Dictionary(uniqueKeysWithValues: chores.map { ($0.id, $0) })
        let selected = choreOrder.compactMap { choresByID[$0] }
        let pinned = selected.filter { pinnedChoreIDs.contains($0.id) }
        let unpinned = selected.filter { !pinnedChoreIDs.contains($0.id) }
        return pinned + unpinned
    }

    var allAvailableChores: [ChoreItem] {
        chores.filter { !$0.isLocked }
    }

    var routineCatalogChores: [ChoreItem] {
        chores.filter { !$0.isLocked && !$0.isCustom }
    }

    var commonChoreGridItemIDs: [String] {
        normalizedCommonChoreGridOrder(from: commonChoreGridOrder)
    }

    var customChores: [ChoreItem] {
        chores
            .filter { $0.isCustom && !$0.isLocked }
            .sorted { ($0.customSlot ?? .max) < ($1.customSlot ?? .max) }
    }

    var availableCustomChoreSlots: Int {
        max(0, customChoreLimit - customChores.count)
    }

    var customChoreLimit: Int {
        isGuestWorkspace ? 2 : (usesMockData ? (hasPremiumAccess ? 100 : 2) : serverCustomChoreLimit)
    }

    var commonChoreSelectionLimit: Int? {
        if isGuestWorkspace {
            return max(0, 6 - customChores.count)
        }
        return usesMockData ? (hasPremiumAccess ? nil : 6) : serverCommonChoreSelectionLimit
    }

    var isGuestWorkspace: Bool {
        localDraftFamily != nil && accessToken == nil && currentFamily?.id.hasPrefix("local-family-") == true
    }

    var localOnboardingSelectionCount: Int {
        choreOrder.count + customChores.count
    }

    var canEditCommonChoreLayout: Bool {
        if currentFamily == nil {
            return true
        }
        return choreLayoutCanEdit && !(canChooseChoreLayoutMode && followsFamilyChoreLayout)
    }

    var canChooseChoreLayoutMode: Bool {
        hasPremiumAccess && currentFamily != nil && !isCurrentUserOwner
    }

    var usesSharedFamilyChoreLayout: Bool {
        guard currentFamily != nil else { return false }
        return isCurrentUserOwner || !hasPremiumAccess || followsFamilyChoreLayout
    }

    func customChore(forSlot slot: Int) -> ChoreItem? {
        customChores.first { $0.customSlot == slot }
    }

    func customChoreSlot(forGridItemID itemID: String) -> Int? {
        guard itemID.hasPrefix(Self.customChoreSlotPrefix) else { return nil }
        return Int(itemID.dropFirst(Self.customChoreSlotPrefix.count))
    }

    func prepareCommonChoreGrid() {
        synchronizeCommonChoreGridOrder()
    }

    func setFollowsFamilyChoreLayout(_ follows: Bool) {
        guard canChooseChoreLayoutMode, follows != followsFamilyChoreLayout else { return }
        clearError()

        let orderedRoutineIDs = commonChoreGridItemIDs.filter { itemID in
            routineCatalogChores.contains { $0.id == itemID }
        }
        let fallbackIDs = orderedRoutineIDs.isEmpty ? choreOrder : orderedRoutineIDs
        guard !fallbackIDs.isEmpty else {
            errorMessage = "请先选择至少 1 项常用家务。"
            return
        }
        let pinnedIDs = pinnedChoreIDs.intersection(Set(fallbackIDs))

        if usesMockData {
            followsFamilyChoreLayout = follows
            choreLayoutIsPersonalized = !follows
            choreLayoutScope = follows ? "family" : "member"
            choreLayoutCanEdit = true
            synchronizeCommonChoreGridOrder()
            return
        }

        Task {
            await performLoading(follows ? "正在同步家庭布局" : "正在建立个人布局") {
                guard let familyId = currentFamily?.id else {
                    throw AppStateError.missingFamily
                }

                let response: ChoreLayoutDTO = try await apiClient.patch(
                    "families/\(familyId)/chore-layout",
                    body: UpdateChoreLayoutRequest(
                        choreIds: fallbackIDs,
                        pinnedChoreIds: fallbackIDs.filter(pinnedIDs.contains),
                        followFamilyLayout: follows
                    )
                )
                applyChoreLayout(response)
            }
        }
    }

    @discardableResult
    func moveCommonChoreGridItem(
        _ sourceID: String,
        to targetID: String,
        persist: Bool = true
    ) -> Bool {
        guard sourceID != targetID else { return false }

        var order = commonChoreGridItemIDs
        guard let sourceIndex = order.firstIndex(of: sourceID),
              let targetIndex = order.firstIndex(of: targetID)
        else {
            return false
        }

        order.remove(at: sourceIndex)
        order.insert(sourceID, at: min(targetIndex, order.count))
        commonChoreGridOrder = order
        if persist {
            persistCommonChoreGridOrder()
        }
        return true
    }

    @discardableResult
    func removeCommonChoreGridItem(_ itemID: String) async -> Bool {
        clearError()

        guard canEditCommonChoreLayout else {
            errorMessage = "高级版成员可以定制自己的常用家务；免费版由一家之主统一设置。"
            return false
        }

        if let slot = customChoreSlot(forGridItemID: itemID) {
            guard customChore(forSlot: slot) == nil else {
                errorMessage = "已创建的自定义家务请进入家务库删除。"
                return false
            }
            hiddenCommonCustomSlotIDs.insert(itemID)
            commonChoreGridOrder.removeAll { $0 == itemID }
            persistCommonChoreGridOrder()
            return true
        }

        let routineIDs = displayedChores.map(\.id)
        guard routineIDs.contains(itemID) else {
            return false
        }

        let previousGridOrder = commonChoreGridOrder
        let previousChoreOrder = choreOrder
        let remainingGridOrder = commonChoreGridItemIDs.filter { $0 != itemID }
        let remainingIDs = remainingGridOrder.filter { routineIDs.contains($0) }
        guard !remainingIDs.isEmpty else {
            errorMessage = "常用家务至少保留 1 项。"
            return false
        }

        commonChoreGridOrder = remainingGridOrder
        choreOrder = remainingIDs
        pinnedChoreIDs = pinnedChoreIDs.intersection(Set(remainingIDs))
        persistCommonChoreGridOrder()
        let saved = await persistCommonChoreGridLayout()
        if !saved {
            commonChoreGridOrder = previousGridOrder
            choreOrder = previousChoreOrder
            persistCommonChoreGridOrder()
            persistChoreLayout()
        }
        return saved
    }

    @discardableResult
    func persistCommonChoreGridLayout() async -> Bool {
        let routineIDs = Set(routineCatalogChores.map(\.id))
        let orderedRoutineIDs = commonChoreGridItemIDs.filter(routineIDs.contains)
        persistCommonChoreGridOrder()
        guard !orderedRoutineIDs.isEmpty else { return false }

        if usesMockData {
            choreOrder = orderedRoutineIDs
            choreLayoutConfigured = true
            persistChoreLayout()
            return true
        }

        var succeeded = false
        await performLoading("正在保存常用家务") {
            guard let familyId = currentFamily?.id else {
                throw AppStateError.missingFamily
            }
            let response: ChoreLayoutDTO = try await apiClient.patch(
                "families/\(familyId)/chore-layout",
                body: UpdateChoreLayoutRequest(
                    choreIds: orderedRoutineIDs,
                    pinnedChoreIds: orderedRoutineIDs.filter(pinnedChoreIDs.contains),
                    followFamilyLayout: isCurrentUserOwner ? true : followsFamilyChoreLayout
                )
            )
            applyChoreLayout(response)
            succeeded = true
        }
        return succeeded
    }

    func restoreCommonChoreGridOrder(_ order: [String]) {
        commonChoreGridOrder = normalizedCommonChoreGridOrder(from: order)
        persistCommonChoreGridOrder()
    }

    func mockLogin() {
        clearError()

        guard !normalizedDevelopmentIdentifier.isEmpty else {
            errorMessage = "请输入开发登录标识。"
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

    func developmentLogin() {
        #if DEBUG
        developmentIdentifier = developmentIdentifier.isEmpty ? "dev-local-user" : developmentIdentifier
        if usesMockData {
            loginWithMock()
        } else {
            Task { await loginWithAPI() }
        }
        #endif
    }

    func restoreSessionIfNeeded() async {
        guard !usesMockData else {
            return
        }

        let storedTokens: AuthTokens?
        do {
            storedTokens = try tokenStore.loadTokens()
            accessToken = storedTokens?.accessToken
        } catch {
            let storageError = error.localizedDescription
            await clearInvalidSession()
            lastSecureStorageErrorMessage = storageError
            return
        }

        await restoreSession(using: storedTokens)
    }

    private func restoreSession(using storedTokens: AuthTokens?) async {
        guard !usesMockData else { return }

        guard let storedTokens, !storedTokens.accessToken.isEmpty else {
            restoreUnauthenticatedWorkspace()
            return
        }

        sessionState = .restoringSession
        await apiClient.setAuthTokens(storedTokens)
        await apiClient.setPreferCachedResponses(true)
        await performLoading("正在恢复登录状态") {
            let user: UserDTO = try await apiClient.get("auth/me")
            currentUser = mapUser(user)
            accountHasPremiumAccess = user.plan == "premium"
            hasPremiumAccess = accountHasPremiumAccess
            var preferredFamilyId: String?
            if localDraftFamily?.claimState == .claiming {
                preferredFamilyId = try await claimLocalDraftWithAPI()
                localDraftFamily = nil
                try localWorkspaceStore.delete()
            }
            let families = try await loadMyFamiliesFromAPI(preferredFamilyId: preferredFamilyId)
            restoreCurrentUser(from: families)
            try await loadChoresFromAPI()

            if families.isEmpty {
                let application = try await loadMyJoinApplicationFromAPI()
                if application != nil {
                    rootScreen = .joinStatus
                } else {
                    rootScreen = .createFamily
                }
            } else {
                selectedTab = .today
                rootScreen = .home
                try await refreshHomeDataFromAPI(includeChores: false)
                mergePendingRecordsIntoVisibleActivity()
            }

            sessionState = .authenticated
        }
        await apiClient.setPreferCachedResponses(false)

        if sessionState == .restoringSession {
            if isOffline, currentUser != nil {
                sessionState = .authenticated
                rootScreen = currentFamily == nil ? .createFamily : .home
                mergePendingRecordsIntoVisibleActivity()
                errorMessage = "当前处于离线模式，记录会在联网后自动同步。"
            } else if isOffline {
                sessionState = .unauthenticated
                rootScreen = .onboarding
                errorMessage = "本机还没有可用的家庭数据，请联网打开一次后再离线使用。"
            } else {
                await clearInvalidSession()
                errorMessage = "登录状态恢复失败，请重新登录。"
            }
        } else if sessionState == .authenticated {
            await syncPendingRecordsIfPossible()
            if isOffline {
                Task { [weak self] in
                    await self?.refreshHomeData()
                }
            }
        }
    }

    func beginLocalFamilyOnboarding() {
        clearError()
        let draft = LocalDraftFamily(
            name: "",
            displayName: "",
            identityLabel: "家庭成员",
            avatarKey: FamilyIdentityOptions.avatarKeys[0],
            profileConfigured: false
        )
        selectedIdentityLabel = "家庭成员"
        customIdentity = ""
        selectedAvatarKey = FamilyIdentityOptions.avatarKeys[0]
        localDraftFamily = draft
        persistLocalDraft(draft)
        applyLocalDraft(draft)
        rootScreen = .createFamily
        sessionState = .unauthenticated
    }

    func beginExistingAccountLogin() {
        clearError()
        pendingAuthAction = nil
        rootScreen = .login
        sessionState = .unauthenticated
    }

    func cancelLocalFamilyOnboarding() {
        guard isGuestWorkspace else {
            returnToOnboarding()
            return
        }
        localDraftFamily = nil
        try? localWorkspaceStore.delete()
        resetSessionState()
        rootScreen = .onboarding
        sessionState = .unauthenticated
    }

    func beginJoinFamilyOnboarding() {
        clearError()
        joinInviteCode = ""
        inviteValidationState = .idle
        rootScreen = .joinFamily
        sessionState = .unauthenticated
    }

    func requireAuthenticationForJoin() {
        guard case .valid = inviteValidationState else {
            errorMessage = "请先输入有效的家庭邀请码。"
            return
        }
        guard validateIdentitySelection(), validatedDisplayNameForFamilyFlow() != nil else {
            return
        }
        pendingAuthAction = .joinFamily(inviteCode: normalizedJoinInviteCode)
        rootScreen = .login
    }

    func requireAuthenticationForLocalFamily() {
        guard localDraftFamily != nil else { return }
        pendingAuthAction = .claimLocalDraft
        rootScreen = .login
    }

    func cancelAuthentication() {
        clearError()
        switch pendingAuthAction {
        case let .joinFamily(inviteCode):
            joinInviteCode = inviteCode
            rootScreen = .joinFamily
        case .claimLocalDraft, .enableCloudSync, .inviteMembers:
            rootScreen = localDraftDestination
        case nil:
            rootScreen = localDraftFamily == nil ? .onboarding : localDraftDestination
        }
        pendingAuthAction = nil
    }

    func selectAuthProvider(_ provider: ClientAuthProvider) {
        clearError()
        errorMessage = switch provider {
        case .apple: "Apple 登录接口正在接入，当前开发包可使用开发登录验证流程。"
        case .wechat: "微信登录接口正在接入。"
        case .email: nil
        case .google: "Google 登录接口正在接入。"
        }
    }

    func requestEmailLoginCode(_ email: String) async -> EmailLoginChallengeResponse? {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.looksLikeEmail(normalizedEmail) else {
            errorMessage = "请输入有效的邮箱地址。"
            return nil
        }

        var challenge: EmailLoginChallengeResponse?
        await performLoading("正在发送验证码") {
            challenge = try await apiClient.post(
                "auth/email/send-code",
                body: SendEmailCodeRequest(email: normalizedEmail)
            )
        }
        return challenge
    }

    func verifyEmailLoginCode(
        email: String,
        challengeId: String,
        code: String
    ) async -> Bool {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedCode.count == 6, normalizedCode.allSatisfy(\.isNumber) else {
            errorMessage = "请输入 6 位验证码。"
            return false
        }

        var succeeded = false
        await performLoading("正在登录") {
            let response: LoginResponse = try await apiClient.post(
                "auth/email/verify-code",
                body: VerifyEmailCodeRequest(
                    email: normalizedEmail,
                    challengeId: challengeId,
                    code: normalizedCode,
                    displayName: normalizedDisplayName,
                    deviceId: UIDevice.current.identifierForVendor?.uuidString,
                    deviceName: UIDevice.current.name,
                    platform: "iOS",
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                )
            )
            try await completeAPILogin(response)
            succeeded = true
        }
        return succeeded
    }

    func returnToOnboarding() {
        clearError()
        rootScreen = localDraftFamily == nil ? .onboarding : localDraftDestination
    }

    func showCreateFamily() {
        if accessToken == nil {
            beginLocalFamilyOnboarding()
            return
        }
        joinRequestSubmitted = false
        currentJoinApplication = nil
        serverCommonChoreSelectionLimit = 6
        serverCustomChoreLimit = 2
        inviteValidationState = .idle
        clearError()
        rootScreen = .createFamily
    }

    func showJoinFamily() {
        joinRequestSubmitted = false
        currentJoinApplication = nil
        inviteValidationState = .idle
        clearError()
        rootScreen = .joinFamily
    }

    func validateJoinInviteCode() {
        let inviteCode = normalizedJoinInviteCode

        guard inviteCode.count == 8 else {
            inviteValidationState = .idle
            return
        }

        guard !usesMockData else {
            inviteValidationState = inviteCode == MockData.invitePreview.inviteCode
                ? .valid(MockData.invitePreview)
                : .invalid("没有找到这个家庭，请检查邀请码")
            return
        }

        inviteValidationState = .validating
        Task {
            do {
                let response: FamilyInvitePreviewDTO = try await apiClient.get(
                    accessToken == nil
                        ? "family-invitations/\(inviteCode)"
                        : "families/invitations/\(inviteCode)"
                )
                guard normalizedJoinInviteCode == inviteCode else { return }
                inviteValidationState = .valid(mapInvitePreview(response))
            } catch {
                guard normalizedJoinInviteCode == inviteCode else { return }
                if accessToken != nil, let apiError = error as? APIError, apiError.isUnauthorized {
                    await clearInvalidSession()
                    errorMessage = "登录已失效，请重新登录。"
                } else {
                    inviteValidationState = .invalid(inviteValidationMessage(for: error))
                }
            }
            await syncAPIDebugSnapshot()
        }
    }

    func enterCreatedFamily() {
        guard currentFamily != nil else {
            errorMessage = AppStateError.missingFamily.localizedDescription
            return
        }

        guard !usesMockData else {
            selectedTab = .today
            rootScreen = .home
            return
        }

        Task {
            await performLoading("正在进入家庭战况") {
                _ = try await loadMyFamiliesFromAPI(preferredFamilyId: currentFamily?.id)
                try await refreshHomeDataFromAPI()
                selectedTab = .today
                rootScreen = .home
            }
        }
    }

    func refreshJoinStatus() {
        clearError()

        guard !usesMockData else {
            currentJoinApplication = currentJoinApplication ?? MockData.pendingJoinApplication
            return
        }

        Task {
            await performLoading("正在刷新审核状态") {
                guard try await loadMyJoinApplicationFromAPI() != nil else {
                    throw AppStateError.missingJoinApplication
                }
            }
        }
    }

    func retryRejectedJoinRequest() {
        guard let application = currentJoinApplication else {
            showJoinFamily()
            return
        }

        joinInviteCode = application.family.inviteCode
        inviteValidationState = .valid(
            FamilyInvitePreview(
                id: application.family.id,
                name: application.family.name,
                inviteCode: application.family.inviteCode,
                memberCount: application.family.memberCount,
                owner: application.family.owner,
                currentStatus: nil
            )
        )
        currentJoinApplication = nil
        joinRequestSubmitted = false
        clearError()
        rootScreen = .joinFamily
    }

    func enterApprovedFamily() {
        guard let application = currentJoinApplication, application.status == .active else {
            errorMessage = "申请还没有通过，请刷新状态后再试。"
            return
        }

        guard !usesMockData else {
            currentFamily = MockData.family
            currentMembership = MockData.currentMembership
            familyMembers = MockData.familyMemberProfiles
            selectedTab = .today
            rootScreen = .home
            return
        }

        Task {
            await performLoading("正在进入家庭战况") {
                _ = try await loadMyFamiliesFromAPI(preferredFamilyId: application.family.id)
                try await refreshHomeDataFromAPI()
                selectedTab = .today
                rootScreen = .home
            }
        }
    }

    func createFamily() {
        clearError()

        guard validateIdentitySelection(),
              let nickname = validatedDisplayNameForFamilyFlow()
        else {
            return
        }

        if isGuestWorkspace {
            let normalizedFamilyName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedFamilyName.isEmpty, normalizedFamilyName.count <= 30 else {
                errorMessage = "家庭名称需要填写，且不能超过 30 个字。"
                return
            }
            guard var draft = localDraftFamily else { return }
            draft.name = normalizedFamilyName
            draft.displayName = nickname
            draft.identityLabel = selectedIdentityLabel
            draft.customIdentity = normalizedCustomIdentity
            draft.avatarKey = selectedAvatarKey
            draft.profileConfigured = true
            draft.updatedAt = Date()
            localDraftFamily = draft
            persistLocalDraft(draft)
            applyLocalDraft(draft)
            prepareInitialChoreSetup()
            rootScreen = .choreSetup
            return
        }

        guard !usesMockData else {
            applyMockDisplayName(nickname)
            createFamilyWithMock()
            return
        }

        Task {
            guard await saveDisplayNameIfNeeded(nickname) else { return }
            await createFamilyWithAPI()
        }
    }

    func submitJoinRequest() {
        clearError()

        guard !joinInviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = AppStateError.missingFamilyIdentifier.localizedDescription
            return
        }

        guard validateIdentitySelection(),
              let nickname = validatedDisplayNameForFamilyFlow()
        else {
            return
        }

        guard case .valid = inviteValidationState else {
            errorMessage = "请先输入有效的家庭邀请码。"
            return
        }

        guard !usesMockData else {
            applyMockDisplayName(nickname)
            joinRequestSubmitted = true
            currentJoinApplication = JoinApplication(
                id: MockData.pendingJoinApplication.id,
                userId: currentUser?.id ?? MockData.currentUser.id,
                identityLabel: selectedIdentityLabel,
                customIdentity: normalizedCustomIdentity,
                avatarKey: selectedAvatarKey,
                status: .pending,
                createdAt: Date(),
                family: MockData.invitePreview
            )
            rootScreen = .joinStatus
            return
        }

        Task {
            guard await saveDisplayNameIfNeeded(nickname) else { return }
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
            await performJoinReview(request, approve: approve)
        }
    }

    func showChoreSelection() {
        selectedTab = .record
    }

    @discardableResult
    func saveChoreLayout(choreIDs: [String], pinnedIDs: Set<String>) async -> Bool {
        clearError()
        guard canEditCommonChoreLayout else {
            errorMessage = "高级版成员可以定制自己的常用家务；免费版由一家之主统一设置。"
            return false
        }

        let selectedChoreCount = choreIDs.count + (isGuestWorkspace ? customChores.count : 0)
        guard selectedChoreCount > 0, Set(choreIDs).count == choreIDs.count else {
            errorMessage = "请至少选择 1 项常用家务。"
            return false
        }

        guard commonChoreSelectionLimit.map({ choreIDs.count <= $0 }) ?? true else {
            errorMessage = "免费版最多选择 6 项常用家务。"
            return false
        }

        let availableIDs = Set(routineCatalogChores.map(\.id))
        guard choreIDs.allSatisfy(availableIDs.contains) else {
            errorMessage = "常用家务中包含已失效项目，请重新选择。"
            return false
        }

        let normalizedPinned = pinnedIDs.intersection(Set(choreIDs))
        if isGuestWorkspace {
            guard choreIDs.count + customChores.count <= 6 else {
                errorMessage = "免费体验最多启用 6 项家务。"
                return false
            }
            choreOrder = choreIDs
            pinnedChoreIDs = normalizedPinned
            choreLayoutConfigured = true
            choreLayoutCanEdit = true
            choreLayoutIsPersonalized = false
            choreLayoutScope = "local"
            followsFamilyChoreLayout = true
            persistLocalWorkspaceSelection()
            synchronizeCommonChoreGridOrder()
            selectedTab = .record
            rootScreen = .home
            sessionState = .unauthenticated
            return true
        }

        if usesMockData {
            choreOrder = choreIDs
            pinnedChoreIDs = normalizedPinned
            choreLayoutConfigured = true
            choreLayoutCanEdit = true
            choreLayoutIsPersonalized = hasPremiumAccess && !isCurrentUserOwner
            choreLayoutScope = choreLayoutIsPersonalized ? "member" : "family"
            followsFamilyChoreLayout = !choreLayoutIsPersonalized
            persistChoreLayout()
            synchronizeCommonChoreGridOrder()
            selectedTab = .record
            rootScreen = .home
            return true
        }

        var succeeded = false
        await performLoading("正在保存常用家务") {
            guard let familyId = currentFamily?.id else {
                throw AppStateError.missingFamily
            }
            let response: ChoreLayoutDTO = try await apiClient.patch(
                "families/\(familyId)/chore-layout",
                body: UpdateChoreLayoutRequest(
                    choreIds: choreIDs,
                    pinnedChoreIds: choreIDs.filter(normalizedPinned.contains),
                    followFamilyLayout: isCurrentUserOwner ? true : followsFamilyChoreLayout
                )
            )
            applyChoreLayout(response)
            selectedTab = .record
            rootScreen = .home
            succeeded = true
        }
        return succeeded
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

    func record(
        _ chore: ChoreItem,
        actualMinutes: Int? = nil,
        calculatedPoints: Int? = nil,
        pointsMultiplier: Double? = nil
    ) {
        clearError()

        if isGuestWorkspace {
            recordWithMock(
                chore,
                actualMinutes: actualMinutes,
                calculatedPoints: calculatedPoints,
                pointsMultiplier: pointsMultiplier
            )
            persistLatestLocalRecord(chore: chore, pointsMultiplier: pointsMultiplier)
            sessionState = .unauthenticated
            return
        }

        guard !usesMockData else {
            recordWithMock(
                chore,
                actualMinutes: actualMinutes,
                calculatedPoints: calculatedPoints,
                pointsMultiplier: pointsMultiplier
            )
            return
        }

        Task {
            await createRecordWithAPI(
                chore,
                actualMinutes: actualMinutes,
                calculatedPoints: calculatedPoints,
                pointsMultiplier: pointsMultiplier
            )
        }
    }

    func toggleLike(_ record: ChoreRecord) {
        clearError()

        let hasReaction = record.myReaction != nil || record.likedByMe

        guard !usesMockData else {
            let liker = ActivityLiker(
                id: currentUser?.id ?? MockData.currentUser.id,
                displayName: currentUserName,
                avatarKey: currentMembership?.avatarKey
            )
            let reaction: ChoreReaction? = hasReaction ? nil : .like
            Self.updateMockReaction(in: &weekRecords, recordID: record.id, reaction: reaction, liker: liker)
            Self.updateMockReaction(in: &recentRecords, recordID: record.id, reaction: reaction, liker: liker)
            return
        }

        Task {
            await performLoading(hasReaction ? "正在取消回应" : "正在点赞") {
                if hasReaction {
                    let _: LikeResponseDTO = try await apiClient.delete("chore-records/\(record.id)/like")
                } else {
                    let _: LikeResponseDTO = try await apiClient.post("chore-records/\(record.id)/like")
                }
                try await refreshActivityFromAPI()
            }
        }
    }

    func react(to record: ChoreRecord, with reaction: ChoreReaction) {
        clearError()

        guard !usesMockData else {
            let liker = ActivityLiker(
                id: currentUser?.id ?? MockData.currentUser.id,
                displayName: currentUserName,
                avatarKey: currentMembership?.avatarKey,
                reaction: reaction
            )
            Self.updateMockReaction(in: &weekRecords, recordID: record.id, reaction: reaction, liker: liker)
            Self.updateMockReaction(in: &recentRecords, recordID: record.id, reaction: reaction, liker: liker)
            return
        }

        Task {
            await performLoading("正在送出\(reaction.title)") {
                let request = ReactionRequestDTO(reactionKey: reaction.rawValue)
                let _: LikeResponseDTO = try await apiClient.post(
                    "chore-records/\(record.id)/like",
                    body: request
                )
                try await refreshActivityFromAPI()
            }
        }
    }

    func deleteRecord(_ record: ChoreRecord) {
        clearError()
        recordUndoErrorMessage = nil

        guard record.canDelete else {
            errorMessage = AppStateError.deleteForbidden.localizedDescription
            return
        }

        if record.syncState == .pending {
            pendingRecordUploads.removeAll { $0.localRecordID == record.id }
            persistPendingRecordUploads()
            removeRecordLocally(record)
            return
        }

        if isGuestWorkspace || usesMockData {
            deleteRecordWithMock(record)
            if isGuestWorkspace {
                removeLocalDraftRecord(record)
            }
            beginRecordDeletionUndo(record: record, expiresAt: Date().addingTimeInterval(10))
            return
        }

        Task {
            do {
                let response: DeleteRecordResponseDTO = try await apiClient.delete("chore-records/\(record.id)")
                removeRecordLocally(record)
                beginRecordDeletionUndo(
                    record: record,
                    expiresAt: Self.localRecordDeletionUndoExpiration(
                        deletedAt: response.deletedAt,
                        undoExpiresAt: response.undoExpiresAt
                    )
                )

                do {
                    try await refreshHomeDataFromAPI(includeChores: false)
                    isOffline = false
                    lastSuccessfulSyncAt = Date()
                } catch {
                    // Deletion already succeeded. Preserve the local state and let
                    // the next normal refresh reconcile secondary statistics.
                    if APIError.isConnectivityError(error) {
                        isOffline = true
                    }
                }

                if let evaluation = response.achievementEvaluation {
                    beginAchievementSync(evaluation)
                }
            } catch {
                if let apiError = error as? APIError, apiError.isUnauthorized {
                    await clearInvalidSession()
                    errorMessage = "登录已失效，请重新登录。"
                } else {
                    errorMessage = error.localizedDescription
                }
            }
            await syncAPIDebugSnapshot()
        }
    }

    func undoLastRecordDeletion() {
        guard let pending = pendingRecordDeletion else { return }

        guard !pending.isExpired else {
            clearRecordDeletionUndo()
            recordUndoErrorMessage = "撤销时间已结束"
            return
        }

        recordUndoErrorMessage = nil

        if isGuestWorkspace || usesMockData {
            restoreRecordLocally(pending.record)
            if isGuestWorkspace {
                restoreLocalDraftRecord(pending.record)
            }
            clearRecordDeletionUndo()
            return
        }

        guard !isRestoringDeletedRecord else { return }
        isRestoringDeletedRecord = true

        Task {
            defer { isRestoringDeletedRecord = false }
            do {
                let response: RestoreRecordResponseDTO = try await apiClient.post(
                    "chore-records/\(pending.record.id)/restore"
                )
                guard response.restored else {
                    throw APIError.invalidResponse
                }

                restoreRecordLocally(pending.record)
                clearRecordDeletionUndo()

                do {
                    try await refreshHomeDataFromAPI(includeChores: false)
                    isOffline = false
                    lastSuccessfulSyncAt = Date()
                } catch {
                    if APIError.isConnectivityError(error) {
                        isOffline = true
                    }
                }

                if let evaluation = response.achievementEvaluation {
                    beginAchievementSync(evaluation)
                }
            } catch {
                if let apiError = error as? APIError, apiError.isUnauthorized {
                    await clearInvalidSession()
                    errorMessage = "登录已失效，请重新登录。"
                } else if case let APIError.requestFailed(statusCode, _) = error,
                          statusCode == 409 {
                    clearRecordDeletionUndo()
                    recordUndoErrorMessage = "撤销时间已结束"
                } else {
                    recordUndoErrorMessage = APIError.isConnectivityError(error)
                        ? "网络开了个小差，请尽快再试一次"
                        : error.localizedDescription
                }
            }
            await syncAPIDebugSnapshot()
        }
    }

    func choreItem(for record: ChoreRecord) -> ChoreItem {
        if let choreId = record.choreId,
           let chore = chores.first(where: { $0.id == choreId }) {
            return chore
        }
        if let chore = chores.first(where: { $0.name == record.choreName }) {
            return chore
        }

        let standardMinutes = max(1, record.standardMinutes)
        let inferredDefaultPoints = record.defaultPoints ?? max(
            1,
            Int((Double(record.points) * Double(standardMinutes) / Double(max(1, record.actualMinutes))).rounded())
        )
        return ChoreItem(
            id: record.choreId ?? record.id,
            name: record.choreName,
            category: record.category,
            minutes: standardMinutes,
            points: inferredDefaultPoints,
            icon: record.icon,
            color: record.color
        )
    }

    func updateRecord(
        _ record: ChoreRecord,
        actualMinutes: Int,
        pointsMultiplier: Double?
    ) {
        clearError()
        guard record.canEdit else {
            errorMessage = "只能编辑自己创建的家务记录。"
            return
        }

        let minutes = max(1, min(180, actualMinutes))
        if isGuestWorkspace || usesMockData {
            let chore = choreItem(for: record)
            let points = pointsMultiplier.map {
                Self.estimatedPoints(for: chore, selectedMinutes: minutes, pointsMultiplier: $0)
            } ?? Self.estimatedPoints(for: chore, selectedMinutes: minutes)
            let updated = record.updating(
                actualMinutes: minutes,
                points: points,
                pointsMultiplier: pointsMultiplier
            )
            weekRecords = weekRecords.map { $0.id == record.id ? updated : $0 }
            recentRecords = recentRecords.map { $0.id == record.id ? updated : $0 }
            let delta = points - record.points
            addWeekPoints(delta, to: record.memberName)
            addMonthlyPoints(delta, to: record.memberName)
            updateMockMonthlyReport()
            if isGuestWorkspace {
                updateLocalDraftRecord(updated)
            }
            return
        }

        Task {
            var evaluation: AchievementEvaluationDTO?
            await performLoading("正在保存家务记录") {
                let response: ChoreRecordDTO = try await apiClient.patch(
                    "chore-records/\(record.id)",
                    body: UpdateChoreRecordRequest(
                        actualMinutes: minutes,
                        pointsMultiplier: pointsMultiplier
                    )
                )
                evaluation = response.achievementEvaluation
                try await refreshHomeDataFromAPI()
            }
            if let evaluation {
                beginAchievementSync(evaluation)
            } else {
                Task { await refreshAchievements() }
            }
        }
    }

    func refreshHomeDataIfNeeded() {
        Task {
            await refreshHomeData()
        }
    }

    func retryHomeData() {
        refreshHomeDataIfNeeded()
    }

    func refreshHomeData() async {
        guard !usesMockData, !isLoading, accessToken != nil, currentFamily != nil else {
            return
        }

        await syncPendingRecordsIfPossible(refreshAfterSync: false)
        await performLoading("正在同步家庭战况") {
            try await refreshHomeDataFromAPI()
            mergePendingRecordsIntoVisibleActivity()
        }
    }

    func refreshAchievementSummaryIfNeeded() {
        guard achievementDataState == .idle || achievementDataState == .cached else { return }
        Task { await refreshAchievements() }
    }

    func refreshAchievements() async {
        guard achievementDataState != .loading else { return }

        if usesMockData {
            achievementSummary = MockData.achievementSummary
            achievementItems = MockData.achievementCollection.achievements
            showAchievementsToFamily = MockData.achievementCollection.showAchievementsToFamily
            achievementLastUpdatedAt = MockData.achievementCollection.updatedAt
            achievementDataState = .loaded
            return
        }

        guard accessToken != nil, currentFamily != nil else {
            achievementDataState = .idle
            return
        }

        achievementDataState = .loading
        do {
            try await loadAchievementsFromAPI()
            achievementDataState = .loaded
            isOffline = false
        } catch {
            if let apiError = error as? APIError, apiError.isUnauthorized {
                await clearInvalidSession()
                errorMessage = "登录已失效，请重新登录。"
                achievementDataState = .failed("登录已失效，请重新登录。")
            } else if APIError.isConnectivityError(error), loadAchievementCache() {
                isOffline = true
                achievementDataState = .cached
            } else {
                achievementDataState = .failed(error.localizedDescription)
            }
        }
        await syncAPIDebugSnapshot()
    }

    func updateAchievementSharing(showToFamily: Bool) async {
        if usesMockData {
            applyAchievementSharing(showToFamily)
            return
        }

        guard let familyId = currentFamily?.id else { return }
        do {
            let response: AchievementSharingResponseDTO = try await apiClient.patch(
                "families/\(familyId)/achievements/visibility",
                body: UpdateAchievementSharingRequest(showToFamily: showToFamily)
            )
            applyAchievementSharing(response.showToFamily)
            saveAchievementCache()
        } catch {
            if let apiError = error as? APIError, apiError.isUnauthorized {
                await clearInvalidSession()
                errorMessage = "登录已失效，请重新登录。"
            } else {
                achievementDataState = .failed(error.localizedDescription)
            }
        }
        await syncAPIDebugSnapshot()
    }

    func dismissAchievementCelebration() {
        if let id = pendingAchievementCelebration?.id {
            dismissedAchievementCelebrationIDs.insert(id)
        }
        pendingAchievementCelebration = nil
    }

    func selectPreviousWeek() {
        selectedWeekOffset = max(-52, selectedWeekOffset - 1)
        refreshSelectedWeek()
    }

    func selectNextWeek() {
        guard canSelectNextWeek else { return }
        selectedWeekOffset = min(0, selectedWeekOffset + 1)
        refreshSelectedWeek()
    }

    private func refreshSelectedWeek() {
        if usesMockData {
            weekRecords = selectedWeekOffset == 0 ? MockData.todayRecords : []
            weekRanking = selectedWeekOffset == 0 ? MockData.members : []
            return
        }

        Task {
            await performLoading("正在切换家庭周报") {
                try await refreshSelectedWeekFromAPI()
            }
        }
    }

    func selectPreviousReportMonth() {
        changeReportMonth(by: -1)
    }

    func selectNextReportMonth() {
        guard canSelectNextReportMonth else { return }
        changeReportMonth(by: 1)
    }

    func refreshCurrentFamilyMembership() async {
        guard !usesMockData,
              sessionState == .authenticated,
              !isLoading,
              let familyId = currentFamily?.id
        else {
            return
        }

        do {
            let previouslyHadPremiumAccess = hasPremiumAccess
            let families = try await loadMyFamiliesFromAPI(preferredFamilyId: familyId)
            if families.isEmpty {
                resetFamilyContextAfterLeaving()
                try await loadChoresFromAPI()
                rootScreen = .createFamily
            } else if let refreshedFamilyId = currentFamily?.id {
                if selectedTab == .record {
                    // Keep the family layout and family-scoped custom chores in
                    // sync while this screen is active. Personal premium layouts
                    // are returned by the same endpoint and remain independent.
                    try await loadChoresFromAPI()
                } else if previouslyHadPremiumAccess != hasPremiumAccess {
                    try await loadChoreLayoutFromAPI(familyId: refreshedFamilyId)
                }
            }
            isOffline = false
            lastSuccessfulSyncAt = Date()
        } catch {
            if let apiError = error as? APIError, apiError.isUnauthorized {
                await clearInvalidSession()
                errorMessage = "登录已失效，请重新登录。"
            } else if APIError.isConnectivityError(error) {
                isOffline = true
            } else {
                errorMessage = error.localizedDescription
            }
        }
        await syncAPIDebugSnapshot()
    }

    func transferOwnership(to member: FamilyMemberProfile) async -> Bool {
        clearError()

        guard isCurrentUserOwner else {
            errorMessage = AppStateError.ownerRequired.localizedDescription
            return false
        }
        guard transferableFamilyMembers.contains(where: { $0.id == member.id }) else {
            errorMessage = "请选择一位已加入家庭的普通成员。"
            return false
        }

        if usesMockData {
            applyMockOwnershipTransfer(to: member)
            return true
        }

        await performLoading("正在转让一家之主") {
            guard let familyId = currentFamily?.id else {
                throw AppStateError.missingFamily
            }
            let _: TransferOwnershipResponseDTO = try await apiClient.patch(
                "families/\(familyId)/owner",
                body: TransferOwnershipRequest(memberId: member.id)
            )
            _ = try await loadMyFamiliesFromAPI(preferredFamilyId: familyId)
        }

        return errorMessage == nil && !isCurrentUserOwner
    }

    func leaveCurrentFamily() async -> Bool {
        clearError()

        guard currentFamily != nil, currentMembership?.status == .active else {
            errorMessage = AppStateError.missingFamily.localizedDescription
            return false
        }
        guard !isCurrentUserOwner else {
            errorMessage = "请先将一家之主转让给其他家庭成员，再退出当前家庭。"
            return false
        }

        if usesMockData {
            resetFamilyContextAfterLeaving()
            rootScreen = .createFamily
            return true
        }

        await performLoading("正在退出当前家庭") {
            guard let familyId = currentFamily?.id else {
                throw AppStateError.missingFamily
            }

            let response: LeaveFamilyResponseDTO = try await apiClient.delete(
                "families/\(familyId)/members/me"
            )
            guard response.left else {
                throw APIError.invalidResponse
            }

            let families = try await loadMyFamiliesFromAPI()
            if families.isEmpty {
                resetFamilyContextAfterLeaving()
                try await loadChoresFromAPI()
                rootScreen = .createFamily
            } else {
                try await loadChoresFromAPI()
                try await refreshHomeDataFromAPI(includeChores: false)
                selectedTab = .today
                rootScreen = .home
            }
        }

        return errorMessage == nil && (currentFamily != nil || rootScreen == .createFamily)
    }

    func updateFamilyName(_ rawName: String) async -> Bool {
        clearError()
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isCurrentUserOwner else {
            errorMessage = AppStateError.ownerRequired.localizedDescription
            return false
        }
        guard !name.isEmpty, name.count <= 30 else {
            errorMessage = "家庭名称需要填写，且不能超过 30 个字。"
            return false
        }

        if usesMockData {
            replaceCurrentFamilyName(name)
            return true
        }

        await performLoading("正在修改家庭名称") {
            guard let familyId = currentFamily?.id else {
                throw AppStateError.missingFamily
            }
            let family: FamilyDTO = try await apiClient.patch(
                "families/\(familyId)",
                body: UpdateFamilyRequest(name: name)
            )
            replaceCurrentFamilyName(family.name)
        }

        return errorMessage == nil && currentFamily?.name == name
    }

    @discardableResult
    func updateDisplayName(_ rawName: String) async -> Bool {
        clearError()
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, name.count <= 30 else {
            errorMessage = "昵称需要填写，且不能超过 30 个字。"
            return false
        }

        if usesMockData {
            guard currentUser != nil else {
                errorMessage = AppStateError.missingUser.localizedDescription
                return false
            }
            applyMockDisplayName(name)
            return true
        }

        await performLoading("正在修改昵称") {
            let user: UserDTO = try await apiClient.patch(
                "auth/me",
                body: UpdateCurrentUserRequest(displayName: name)
            )
            currentUser = mapUser(user)
            displayName = user.displayName

            if let familyId = currentFamily?.id {
                _ = try await loadMyFamiliesFromAPI(preferredFamilyId: familyId)
                try await refreshActivityFromAPI()
            }
        }

        return errorMessage == nil && currentUser?.displayName == name
    }

    func memberActivity(for member: FamilyMemberProfile) -> [ChoreRecord] {
        memberActivityByMemberID[member.id] ?? []
    }

    func loadMemberActivity(for member: FamilyMemberProfile) async {
        clearError()

        if usesMockData {
            let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            memberActivityByMemberID[member.id] = recentRecords.filter {
                $0.creatorId == member.userId && $0.createdAt >= cutoff
            }
            return
        }

        await performLoading("正在读取近一个月动态") {
            guard let familyId = currentFamily?.id else {
                throw AppStateError.missingFamily
            }
            let records: [ActivityItemDTO] = try await apiClient.get(
                "families/\(familyId)/members/\(member.id)/activity"
            )
            memberActivityByMemberID[member.id] = records.map(mapActivity)
        }
    }

    func updateAppearance(avatarKey: String) async -> Bool {
        clearError()

        guard FamilyIdentityOptions.avatarKeys.contains(avatarKey) else {
            errorMessage = "请选择有效的家庭形象。"
            return false
        }
        guard currentFamily != nil, currentMembership?.status == .active else {
            errorMessage = AppStateError.missingFamily.localizedDescription
            return false
        }

        if usesMockData {
            applyMockAppearance(avatarKey)
            return true
        }

        await performLoading("正在保存家庭形象") {
            guard let familyId = currentFamily?.id else {
                throw AppStateError.missingFamily
            }
            let _: FamilyMemberDTO = try await apiClient.patch(
                "families/\(familyId)/members/me/appearance",
                body: UpdateMemberAppearanceRequest(avatarKey: avatarKey)
            )
            _ = try await loadMyFamiliesFromAPI(preferredFamilyId: familyId)
            try await refreshActivityFromAPI()
        }

        return errorMessage == nil && currentMembership?.avatarKey == avatarKey
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

    static func defaultPointsMultiplier(for chore: ChoreItem) -> Double {
        guard chore.minutes > 0 else { return 1 }
        let derived = Double(chore.points) / Double(chore.minutes)
        return min(2, max(0.5, (derived * 10).rounded() / 10))
    }

    static func estimatedPoints(
        for chore: ChoreItem,
        selectedMinutes: Int,
        pointsMultiplier: Double
    ) -> Int {
        let minutes = max(1, min(180, selectedMinutes))
        let multiplier = min(2, max(0.5, (pointsMultiplier * 10).rounded() / 10))
        return max(1, Int((Double(minutes) * multiplier).rounded()))
    }

    @discardableResult
    func saveCustomChore(_ draft: CustomChoreDraft, editing chore: ChoreItem? = nil) async -> Bool {
        clearError()
        if isGuestWorkspace, chore == nil, localOnboardingSelectionCount >= 6 {
            errorMessage = "免费体验最多启用 6 项家务。"
            return false
        }
        guard chore != nil || availableCustomChoreSlots > 0 else {
            errorMessage = "免费版最多可以创建 2 个自定义家务。"
            return false
        }
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "请给这个家务起个名字。"
            return false
        }
        guard name.count <= 5 else {
            errorMessage = "家务名称最多 5 个字。"
            return false
        }

        let normalizedDraft = CustomChoreDraft(
            name: name,
            iconKey: draft.iconKey,
            category: draft.category,
            standardMinutes: max(1, min(180, draft.standardMinutes)),
            difficultyMultiplier: max(0.5, min(2.0, (draft.difficultyMultiplier * 10).rounded() / 10))
        )

        if isGuestWorkspace {
            saveMockCustomChore(normalizedDraft, editing: chore)
            persistLocalWorkspaceSelection()
            return true
        }

        if usesMockData {
            saveMockCustomChore(normalizedDraft, editing: chore)
            return true
        }

        await performLoading(chore == nil ? "正在添加自定义家务" : "正在保存自定义家务") {
            guard let familyId = currentFamily?.id else {
                throw AppStateError.missingFamily
            }

            let request = SaveCustomChoreRequest(
                name: normalizedDraft.name,
                iconKey: normalizedDraft.iconKey,
                category: normalizedDraft.category.rawValue,
                standardMinutes: normalizedDraft.standardMinutes,
                difficultyMultiplier: normalizedDraft.difficultyMultiplier
            )
            if let chore {
                let _: ChoreDTO = try await apiClient.patch(
                    "families/\(familyId)/custom-chores/\(chore.id)",
                    body: request
                )
            } else {
                let _: ChoreDTO = try await apiClient.post(
                    "families/\(familyId)/custom-chores",
                    body: request
                )
            }
            try await loadChoresFromAPI()
        }

        return errorMessage == nil
    }

    @discardableResult
    func archiveCustomChore(_ chore: ChoreItem) async -> Bool {
        guard chore.isCustom else {
            return false
        }
        clearError()

        if isGuestWorkspace {
            replaceChores(chores.filter { $0.id != chore.id })
            persistLocalWorkspaceSelection()
            return true
        }

        if usesMockData {
            replaceChores(chores.filter { $0.id != chore.id })
            return true
        }

        await performLoading("正在移除自定义家务") {
            guard let familyId = currentFamily?.id else {
                throw AppStateError.missingFamily
            }
            let _: ArchiveCustomChoreResponseDTO = try await apiClient.delete(
                "families/\(familyId)/custom-chores/\(chore.id)"
            )
            try await loadChoresFromAPI()
        }

        return errorMessage == nil
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

    func redeemPremium(code: String) async -> Bool {
        clearError()
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedCode.isEmpty else {
            errorMessage = "请输入兑换码"
            return false
        }

        if usesMockData {
            guard normalizedCode == Self.mockPremiumRedemptionCode else {
                errorMessage = "兑换码不正确，请重新输入"
                return false
            }

            hasPremiumAccess = true
            choreLayoutCanEdit = true
            choreLayoutScope = "member"
            choreLayoutIsPersonalized = true
            persistMockPremiumAccess()
            return true
        }

        var succeeded = false
        await performLoading("正在兑换高级会员") {
            let response: PremiumRedemptionResponseDTO = try await apiClient.post(
                "auth/redeem-premium",
                body: PremiumRedemptionRequest(code: normalizedCode)
            )
            accountHasPremiumAccess = response.plan == "premium"
            hasPremiumAccess = accountHasPremiumAccess
            if hasPremiumAccess, let familyId = currentFamily?.id {
                try await loadChoreLayoutFromAPI(familyId: familyId)
            }
            succeeded = hasPremiumAccess
        }
        return succeeded
    }

    func logout(allDevices: Bool = false) {
        Task {
            if !usesMockData {
                do {
                    let _: LogoutResponseDTO = try await apiClient.post(
                        allDevices ? "auth/logout-all" : "auth/logout"
                    )
                } catch {
                    // Local logout still completes if the network is unavailable.
                }
            }
            await clearLocalSession()
        }
    }

    func deleteAccount() async -> Bool {
        clearError()
        isLoading = true
        loadingMessage = "正在永久注销账户"
        defer {
            isLoading = false
            loadingMessage = nil
        }

        do {
            if !usesMockData {
                let response: DeleteAccountResponseDTO = try await apiClient.delete("auth/me")
                guard response.deleted else {
                    throw APIError.invalidResponse
                }
            }

            await clearLocalAccountData()
            return true
        } catch {
            if let apiError = error as? APIError, apiError.isUnauthorized {
                await clearLocalAccountData()
                errorMessage = "账号登录状态已失效，本机登录信息已清除。"
                return true
            }
            if APIError.isConnectivityError(error) {
                isOffline = true
                errorMessage = "永久注销需要连接服务器，请联网后重试。"
            } else {
                errorMessage = error.localizedDescription
            }
            await syncAPIDebugSnapshot()
            return false
        }
    }

    private func clearLocalAccountData() async {
        achievementSyncTask?.cancel()
        achievementSyncTask = nil
        deletionUndoTask?.cancel()
        deletionUndoTask = nil
        pendingRecordUploads.removeAll()
        pendingUploadCount = 0
        localDraftFamily = nil
        try? localWorkspaceStore.delete()
        userDefaults.removeObject(forKey: Self.hasAuthenticatedBeforeDefaultsKey)

        let accountScopedPrefixes = [
            Self.commonChoreGridDefaultsKeyPrefix,
            Self.achievementCacheKeyPrefix,
            "test-premium-access-",
            "chore_last_duration_",
        ]
        let exactKeys = [
            Self.choreOrderDefaultsKey,
            Self.pinnedChoresDefaultsKey,
            Self.pendingRecordUploadsDefaultsKey,
        ]
        for key in userDefaults.dictionaryRepresentation().keys where
            exactKeys.contains(key) || accountScopedPrefixes.contains(where: { key.hasPrefix($0) }) {
            userDefaults.removeObject(forKey: key)
        }

        await apiClient.clearCachedResponses()
        await clearLocalSession()
    }

    private func clearLocalSession() async {
        resetSessionState()
        await apiClient.setAuthTokens(nil)
        do {
            try tokenStore.deleteTokens()
            lastSecureStorageErrorMessage = nil
        } catch {
            lastSecureStorageErrorMessage = error.localizedDescription
        }
    }

    private func resetSessionState() {
        achievementSyncTask?.cancel()
        achievementSyncTask = nil
        deletionUndoTask?.cancel()
        deletionUndoTask = nil
        accessToken = nil
        currentUser = nil
        accountHasPremiumAccess = false
        hasPremiumAccess = false
        currentFamily = nil
        currentMembership = nil
        familyMembers = []
        memberActivityByMemberID = [:]
        joinRequests = []
        joinRequestSubmitted = false
        selectedChore = nil
        selectedTab = .today
        selectedWeekOffset = 0
        developmentIdentifier = "dev-local-user"
        displayName = ""
        familyName = MockData.family.name
        selectedIdentityLabel = "家庭成员"
        customIdentity = ""
        selectedAvatarKey = "avatar_07"
        joinInviteCode = ""
        inviteValidationState = .idle
        currentJoinApplication = nil
        reviewingRequestID = nil
        reviewErrors = [:]
        chores = usesMockData ? MockData.chores : []
        choreOrder = []
        pinnedChoreIDs = []
        commonChoreGridOrder = []
        commonChoreGridScope = nil
        choreLayoutConfigured = false
        choreLayoutCanEdit = true
        choreLayoutScope = "family"
        choreLayoutIsPersonalized = false
        followsFamilyChoreLayout = true
        weekRecords = usesMockData ? MockData.todayRecords : []
        recentRecords = usesMockData ? MockData.todayRecords : []
        monthlyRanking = usesMockData ? MockData.members : []
        weekRanking = usesMockData ? MockData.members : []
        monthlyReport = usesMockData ? MockData.monthlyReport : nil
        achievementSummary = nil
        achievementItems = []
        showAchievementsToFamily = true
        achievementDataState = .idle
        achievementSyncState = .idle
        achievementLastUpdatedAt = nil
        pendingAchievementCelebration = nil
        pendingRecordDeletion = nil
        isRestoringDeletedRecord = false
        recordUndoErrorMessage = nil
        selectedReportMonth = currentMonth
        isOffline = false
        lastSuccessfulSyncAt = nil
        if let localDraftFamily {
            applyLocalDraft(localDraftFamily)
            rootScreen = localDraftDestination
        } else {
            rootScreen = unauthenticatedDestination
        }
        sessionState = .unauthenticated
        clearError()
    }

    private func resetFamilyContextAfterLeaving() {
        achievementSyncTask?.cancel()
        achievementSyncTask = nil
        currentFamily = nil
        currentMembership = nil
        familyMembers = []
        memberActivityByMemberID = [:]
        joinRequests = []
        joinRequestSubmitted = false
        currentJoinApplication = nil
        selectedChore = nil
        selectedTab = .today
        selectedWeekOffset = 0
        familyName = MockData.family.name
        choreOrder = []
        pinnedChoreIDs = []
        commonChoreGridOrder = []
        commonChoreGridScope = nil
        choreLayoutConfigured = false
        choreLayoutCanEdit = true
        choreLayoutScope = "family"
        choreLayoutIsPersonalized = false
        followsFamilyChoreLayout = true
        weekRecords = []
        recentRecords = []
        weekRanking = []
        monthlyRanking = []
        monthlyReport = nil
        achievementSummary = nil
        achievementItems = []
        showAchievementsToFamily = true
        achievementDataState = .idle
        achievementSyncState = .idle
        achievementLastUpdatedAt = nil
        pendingAchievementCelebration = nil
    }

    private var localDraftDestination: AppScreen {
        guard let localDraftFamily else { return .onboarding }
        if localDraftFamily.profileConfigured == false
            || (localDraftFamily.profileConfigured == nil && localDraftFamily.selectedChores.isEmpty) {
            return .createFamily
        }
        return localDraftFamily.selectedChores.isEmpty ? .choreSetup : .home
    }

    private func restoreUnauthenticatedWorkspace() {
        accessToken = nil
        if let localDraftFamily {
            applyLocalDraft(localDraftFamily)
            rootScreen = localDraftDestination
        } else {
            currentUser = nil
            currentFamily = nil
            currentMembership = nil
            familyMembers = []
            rootScreen = unauthenticatedDestination
        }
        sessionState = .unauthenticated
    }

    private var unauthenticatedDestination: AppScreen {
        if localDraftFamily != nil {
            return localDraftDestination
        }
        return userDefaults.bool(forKey: Self.hasAuthenticatedBeforeDefaultsKey) ? .login : .onboarding
    }

    private func applyLocalDraft(_ draft: LocalDraftFamily) {
        let localUserID = "local-user-\(draft.id.uuidString.lowercased())"
        let localFamilyID = "local-family-\(draft.id.uuidString.lowercased())"
        let localDisplayName = draft.displayName ?? "我"
        selectedIdentityLabel = draft.identityLabel ?? selectedIdentityLabel
        customIdentity = draft.customIdentity ?? ""
        selectedAvatarKey = draft.avatarKey ?? selectedAvatarKey
        currentUser = AppUser(
            id: localUserID,
            displayName: localDisplayName,
            avatarInitial: String(localDisplayName.prefix(1)),
            badge: "本机体验"
        )
        currentFamily = FamilySpace(
            id: localFamilyID,
            name: draft.name,
            inviteCode: "",
            requiresPhotoProof: false,
            timezone: TimeZone.current.identifier
        )
        currentMembership = FamilyMembership(
            id: "local-membership-\(draft.id.uuidString.lowercased())",
            userId: localUserID,
            familyId: localFamilyID,
            identityLabel: selectedIdentityLabel,
            customIdentity: draft.customIdentity,
            avatarKey: selectedAvatarKey,
            memberRole: .owner,
            status: .active
        )
        familyMembers = [
            FamilyMemberProfile(
                id: currentMembership?.id ?? "local-membership",
                userId: localUserID,
                name: localDisplayName,
                identityLabel: selectedIdentityLabel,
                customIdentity: draft.customIdentity,
                avatarKey: selectedAvatarKey,
                memberRole: .owner,
                status: .active,
                joinedAt: draft.createdAt
            ),
        ]

        var available = MockData.chores
        let customItems = draft.selectedChores
            .filter { $0.source == .custom }
            .map(localChoreItem)
        available.removeAll { $0.isCustom }
        available.append(contentsOf: customItems)
        chores = available
        choreOrder = draft.selectedChores
            .filter { $0.source == .catalog }
            .map(\.id)
        pinnedChoreIDs = []
        choreLayoutConfigured = !draft.selectedChores.isEmpty
        choreLayoutCanEdit = true
        choreLayoutScope = "local"
        choreLayoutIsPersonalized = false
        followsFamilyChoreLayout = true
        serverCommonChoreSelectionLimit = 6
        serverCustomChoreLimit = 2

        let mappedRecords = draft.records
            .sorted { $0.occurredAt > $1.occurredAt }
            .map { localRecord in
                ChoreRecord(
                    id: "local-record-\(localRecord.id.uuidString.lowercased())",
                    memberName: localDisplayName,
                    choreName: localRecord.choreName,
                    category: localRecord.category,
                    standardMinutes: localRecord.standardMinutes,
                    actualMinutes: localRecord.actualMinutes,
                    points: localRecord.points,
                    note: localRecord.note,
                    createdAt: localRecord.occurredAt,
                    icon: localRecord.icon,
                    color: localChoreColor(themeKey: "", icon: localRecord.icon),
                    creatorId: localUserID,
                    identityLabel: selectedIdentityLabel,
                    customIdentity: draft.customIdentity,
                    avatarKey: selectedAvatarKey,
                    canDelete: true,
                    canEdit: true,
                    choreId: localRecord.choreID,
                    defaultPoints: localRecord.defaultPoints,
                    pointsMultiplier: localRecord.pointsMultiplier
                )
            }
        weekRecords = mappedRecords.filter { Calendar.current.isDate($0.createdAt, equalTo: Date(), toGranularity: .weekOfYear) }
        recentRecords = mappedRecords
        weekRanking = [
            FamilyMember(
                id: localUserID,
                name: localDisplayName,
                monthlyPoints: weekRecords.reduce(0) { $0 + $1.points },
                badge: "本机体验",
                color: DSColor.yellow
            ),
        ]
        monthlyRanking = weekRanking
        familyName = draft.name
        displayName = localDisplayName
        synchronizeCommonChoreGridOrder()
    }

    private func localChoreItem(_ local: LocalDraftChore) -> ChoreItem {
        ChoreItem(
            id: local.id,
            catalogKey: local.catalogKey,
            name: local.name,
            category: local.category,
            minutes: local.minutes,
            points: local.points,
            icon: local.icon,
            color: localChoreColor(themeKey: local.themeKey, icon: local.icon),
            themeKey: local.themeKey,
            difficultyMultiplier: local.difficultyMultiplier,
            isCustom: local.source == .custom,
            customSlot: local.customSlot
        )
    }

    private func localChoreColor(themeKey: String, icon: String) -> Color {
        if let option = CustomChoreCatalog.option(for: icon) {
            return option.color
        }
        return switch ChoreTheme(rawValue: themeKey) {
        case .love: DSColor.coral
        case .childcare: DSColor.sky
        case .pet: DSColor.mint
        default: DSColor.yellow
        }
    }

    private func persistLocalWorkspaceSelection() {
        guard var draft = localDraftFamily else { return }
        let selectedIDs = Set(choreOrder)
        let selectedCatalog = chores
            .filter { !$0.isCustom && selectedIDs.contains($0.id) }
            .map(LocalDraftChore.init)
        let selectedCustom = customChores.map(LocalDraftChore.init)
        draft.selectedChores = selectedCatalog + selectedCustom
        draft.updatedAt = Date()
        draft.claimState = .local
        localDraftFamily = draft
        persistLocalDraft(draft)
    }

    private func persistLatestLocalRecord(chore: ChoreItem, pointsMultiplier: Double?) {
        guard var draft = localDraftFamily, let record = recentRecords.first else { return }
        guard let recordID = localDraftRecordID(from: record.id) else { return }
        draft.records.insert(
            LocalDraftChoreRecord(
                id: recordID,
                choreID: chore.id,
                choreName: record.choreName,
                category: record.category,
                standardMinutes: record.standardMinutes,
                defaultPoints: record.defaultPoints ?? chore.points,
                icon: record.icon,
                actualMinutes: record.actualMinutes,
                points: record.points,
                pointsMultiplier: pointsMultiplier,
                note: record.note,
                occurredAt: record.createdAt
            ),
            at: 0
        )
        draft.updatedAt = Date()
        localDraftFamily = draft
        persistLocalDraft(draft)
    }

    private func removeLocalDraftRecord(_ record: ChoreRecord) {
        guard var draft = localDraftFamily,
              let id = localDraftRecordID(from: record.id)
        else { return }
        draft.records.removeAll { $0.id == id }
        draft.updatedAt = Date()
        localDraftFamily = draft
        persistLocalDraft(draft)
    }

    private func restoreLocalDraftRecord(_ record: ChoreRecord) {
        guard var draft = localDraftFamily,
              let id = localDraftRecordID(from: record.id),
              !draft.records.contains(where: { $0.id == id })
        else { return }
        draft.records.append(localDraftRecord(from: record, id: id))
        draft.records.sort { $0.occurredAt > $1.occurredAt }
        draft.updatedAt = Date()
        localDraftFamily = draft
        persistLocalDraft(draft)
    }

    private func updateLocalDraftRecord(_ record: ChoreRecord) {
        guard var draft = localDraftFamily,
              let id = localDraftRecordID(from: record.id),
              let index = draft.records.firstIndex(where: { $0.id == id })
        else { return }
        draft.records[index] = localDraftRecord(from: record, id: id)
        draft.updatedAt = Date()
        localDraftFamily = draft
        persistLocalDraft(draft)
    }

    private func localDraftRecord(from record: ChoreRecord, id: UUID) -> LocalDraftChoreRecord {
        LocalDraftChoreRecord(
            id: id,
            choreID: record.choreId ?? record.id,
            choreName: record.choreName,
            category: record.category,
            standardMinutes: record.standardMinutes,
            defaultPoints: record.defaultPoints ?? max(1, record.points),
            icon: record.icon,
            actualMinutes: record.actualMinutes,
            points: record.points,
            pointsMultiplier: record.pointsMultiplier,
            note: record.note,
            occurredAt: record.createdAt
        )
    }

    private func localDraftRecordID(from recordID: String) -> UUID? {
        let prefix = "local-record-"
        guard recordID.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(recordID.dropFirst(prefix.count)))
    }

    private func persistLocalDraft(_ draft: LocalDraftFamily) {
        do {
            try localWorkspaceStore.save(draft)
        } catch {
            errorMessage = "本机体验数据保存失败：\(error.localizedDescription)"
        }
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

    private func validatedDisplayNameForFamilyFlow() -> String? {
        let nickname = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nickname.isEmpty, nickname.count <= 30 else {
            errorMessage = "昵称需要填写，且不能超过 30 个字。"
            return nil
        }
        return nickname
    }

    private func saveDisplayNameIfNeeded(_ nickname: String) async -> Bool {
        if currentUser?.displayName == nickname {
            displayName = nickname
            return true
        }
        return await updateDisplayName(nickname)
    }

    private func applyMockDisplayName(_ nickname: String) {
        guard let user = currentUser else { return }

        currentUser = AppUser(
            id: user.id,
            displayName: nickname,
            avatarInitial: String(nickname.prefix(1)),
            badge: user.badge
        )
        displayName = nickname
        familyMembers = familyMembers.map { member in
            guard member.userId == user.id else { return member }
            return FamilyMemberProfile(
                id: member.id,
                userId: member.userId,
                name: nickname,
                identityLabel: member.identityLabel,
                customIdentity: member.customIdentity,
                avatarKey: member.avatarKey,
                memberRole: member.memberRole,
                status: member.status,
                joinedAt: member.joinedAt
            )
        }
    }

    private func loginWithMock() {
        accessToken = "mock-token"
        let nickname = normalizedDisplayName ?? "开发用户"
        currentUser = AppUser(
            id: MockData.currentUser.id,
            displayName: nickname,
            avatarInitial: String(nickname.prefix(1)),
            badge: MockData.currentUser.badge
        )
        displayName = nickname
        restoreMockPremiumAccess()
        currentFamily = nil
        currentMembership = nil
        familyMembers = []
        replaceChores(MockData.chores)
        weekRecords = MockData.todayRecords
        recentRecords = MockData.todayRecords
        monthlyRanking = MockData.members
        weekRanking = MockData.members
        loadMockMonthlyReport(for: selectedReportMonth)
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
        if let membership = currentMembership {
            familyMembers = [
                FamilyMemberProfile(
                    id: membership.id,
                    userId: membership.userId,
                    name: currentUserName,
                    identityLabel: membership.identityLabel,
                    customIdentity: membership.customIdentity,
                    avatarKey: membership.avatarKey,
                    memberRole: membership.memberRole,
                    status: membership.status,
                    joinedAt: Date()
                ),
            ]
        }
        prepareInitialChoreSetup()
        rootScreen = .choreSetup
        sessionState = .authenticated
    }

    private func recordWithMock(
        _ chore: ChoreItem,
        actualMinutes: Int? = nil,
        calculatedPoints: Int? = nil,
        pointsMultiplier: Double? = nil
    ) {
        selectedChore = chore
        if selectedReportMonth != currentMonth {
            selectedReportMonth = currentMonth
            monthlyRanking = MockData.members
        }
        let minutes = max(1, min(180, actualMinutes ?? chore.minutes))
        let points = calculatedPoints ?? pointsMultiplier.map {
            Self.estimatedPoints(for: chore, selectedMinutes: minutes, pointsMultiplier: $0)
        } ?? Self.estimatedPoints(for: chore, selectedMinutes: minutes)

        let recordID = isGuestWorkspace
            ? "local-record-\(UUID().uuidString.lowercased())"
            : "mock-record-\(UUID().uuidString)"
        let record = ChoreRecord(
            id: recordID,
            memberName: currentUserName,
            choreName: chore.name,
            category: chore.category,
            standardMinutes: chore.minutes,
            actualMinutes: minutes,
            points: points,
            note: recordSuccessNote(for: chore.name),
            createdAt: Date(),
            icon: chore.icon,
            color: chore.color,
            creatorId: currentUser?.id,
            identityLabel: currentMembership?.identityLabel ?? selectedIdentityLabel,
            customIdentity: currentMembership?.customIdentity,
            avatarKey: currentMembership?.avatarKey ?? selectedAvatarKey,
            likeCount: 0,
            likedByMe: false,
            canDelete: true,
            canEdit: true,
            choreId: chore.id,
            defaultPoints: chore.points,
            pointsMultiplier: pointsMultiplier
        )

        weekRecords.insert(record, at: 0)
        recentRecords.insert(record, at: 0)
        addMonthlyPoints(points, to: currentUserName)
        addWeekPoints(points, to: currentUserName)
        updateMockMonthlyReport()
        selectedTab = .today
        rootScreen = .home
        sessionState = .authenticated
    }

    private func enqueueOfflineRecord(
        _ chore: ChoreItem,
        actualMinutes: Int?,
        calculatedPoints: Int?,
        pointsMultiplier: Double?,
        requestID: String
    ) {
        guard let userId = currentUser?.id,
              let familyId = currentFamily?.id
        else {
            errorMessage = AppStateError.missingFamily.localizedDescription
            return
        }

        selectedWeekOffset = 0
        let minutes = max(1, min(180, actualMinutes ?? chore.minutes))
        let points = calculatedPoints ?? pointsMultiplier.map {
            Self.estimatedPoints(for: chore, selectedMinutes: minutes, pointsMultiplier: $0)
        } ?? Self.estimatedPoints(for: chore, selectedMinutes: minutes)
        let note = recordSuccessNote(for: chore.name)
        let pending = PendingChoreRecordUpload(
            id: requestID,
            userId: userId,
            familyId: familyId,
            choreId: chore.id,
            choreName: chore.name,
            category: chore.category,
            standardMinutes: chore.minutes,
            defaultPoints: chore.points,
            icon: chore.icon,
            actualMinutes: minutes,
            calculatedPoints: points,
            pointsMultiplier: pointsMultiplier,
            note: note,
            createdAt: Date(),
            memberName: currentUserName,
            identityLabel: currentMembership?.identityLabel ?? selectedIdentityLabel,
            customIdentity: currentMembership?.customIdentity,
            avatarKey: currentMembership?.avatarKey ?? selectedAvatarKey
        )

        pendingRecordUploads.append(pending)
        persistPendingRecordUploads()
        let record = makePendingRecord(from: pending)
        weekRecords.removeAll { $0.id == record.id }
        recentRecords.removeAll { $0.id == record.id }
        weekRecords.insert(record, at: 0)
        recentRecords.insert(record, at: 0)
    }

    func syncPendingRecordsIfPossible() async {
        await syncPendingRecordsIfPossible(refreshAfterSync: true)
    }

    private func syncPendingRecordsIfPossible(refreshAfterSync: Bool) async {
        guard !usesMockData,
              !isSyncingPendingRecords,
              accessToken != nil,
              let userId = currentUser?.id,
              let familyId = currentFamily?.id
        else { return }

        let queued = pendingRecordUploads.filter {
            $0.userId == userId && $0.familyId == familyId
        }.sorted { $0.createdAt < $1.createdAt }
        guard !queued.isEmpty else { return }

        isSyncingPendingRecords = true
        defer { isSyncingPendingRecords = false }
        var uploadedAny = false
        var latestEvaluation: AchievementEvaluationDTO?

        for pending in queued {
            do {
                let response: ChoreRecordDTO = try await apiClient.post(
                    "chore-records",
                    body: CreateChoreRecordRequest(
                        familyId: pending.familyId,
                        choreId: pending.choreId,
                        actualMinutes: pending.actualMinutes,
                        pointsMultiplier: pending.pointsMultiplier,
                        note: pending.note,
                        imageUrls: []
                    ),
                    headers: ["Idempotency-Key": pending.id]
                )
                pendingRecordUploads.removeAll { $0.id == pending.id }
                weekRecords.removeAll { $0.id == pending.localRecordID }
                recentRecords.removeAll { $0.id == pending.localRecordID }
                let synced = mapRecord(response)
                weekRecords.insert(synced, at: 0)
                recentRecords.insert(synced, at: 0)
                latestEvaluation = response.achievementEvaluation ?? latestEvaluation
                uploadedAny = true
                persistPendingRecordUploads()
            } catch {
                if APIError.isConnectivityError(error) {
                    isOffline = true
                    break
                }
                if let apiError = error as? APIError, apiError.isUnauthorized {
                    await clearInvalidSession()
                    errorMessage = "登录已失效，请重新登录。"
                    break
                }
                errorMessage = "有一条离线记录同步失败：\(error.localizedDescription)"
                break
            }
        }

        if uploadedAny {
            isOffline = false
            lastSuccessfulSyncAt = Date()
            if refreshAfterSync {
                do {
                    try await refreshHomeDataFromAPI(includeChores: false)
                    mergePendingRecordsIntoVisibleActivity()
                } catch {
                    if APIError.isConnectivityError(error) {
                        isOffline = true
                    }
                }
            }
            if let latestEvaluation {
                beginAchievementSync(latestEvaluation)
            } else {
                Task { await refreshAchievements() }
            }
        }
        await syncAPIDebugSnapshot()
    }

    private func mergePendingRecordsIntoVisibleActivity() {
        guard let userId = currentUser?.id,
              let familyId = currentFamily?.id
        else { return }

        let pendingRecords = pendingRecordUploads
            .filter { $0.userId == userId && $0.familyId == familyId }
            .sorted { $0.createdAt > $1.createdAt }
            .map(makePendingRecord)

        let pendingIDs = Set(pendingRecords.map(\.id))
        recentRecords.removeAll { pendingIDs.contains($0.id) }
        recentRecords.insert(contentsOf: pendingRecords, at: 0)

        if selectedWeekOffset == 0 {
            weekRecords.removeAll { pendingIDs.contains($0.id) }
            weekRecords.insert(contentsOf: pendingRecords, at: 0)
        }
    }

    private func makePendingRecord(from pending: PendingChoreRecordUpload) -> ChoreRecord {
        ChoreRecord(
            id: pending.localRecordID,
            memberName: pending.memberName,
            choreName: pending.choreName,
            category: pending.category,
            standardMinutes: pending.standardMinutes,
            actualMinutes: pending.actualMinutes,
            points: pending.calculatedPoints,
            note: pending.note,
            createdAt: pending.createdAt,
            icon: pending.icon,
            color: Self.color(forCategory: pending.category),
            creatorId: pending.userId,
            identityLabel: pending.identityLabel,
            customIdentity: pending.customIdentity,
            avatarKey: pending.avatarKey,
            likeCount: 0,
            likedByMe: false,
            canDelete: true,
            canEdit: false,
            choreId: pending.choreId,
            defaultPoints: pending.defaultPoints,
            pointsMultiplier: pending.pointsMultiplier,
            syncState: .pending
        )
    }

    private func persistPendingRecordUploads() {
        pendingUploadCount = pendingRecordUploads.count
        guard let data = try? JSONEncoder().encode(pendingRecordUploads) else { return }
        userDefaults.set(data, forKey: Self.pendingRecordUploadsDefaultsKey)
    }

    private static func loadPendingRecordUploads(from defaults: UserDefaults) -> [PendingChoreRecordUpload] {
        guard let data = defaults.data(forKey: pendingRecordUploadsDefaultsKey) else { return [] }
        return (try? JSONDecoder().decode([PendingChoreRecordUpload].self, from: data)) ?? []
    }

    private func deleteRecordWithMock(_ record: ChoreRecord) {
        removeRecordLocally(record)
        updateMockMonthlyReport()
    }

    private func removeRecordLocally(_ record: ChoreRecord) {
        weekRecords.removeAll { $0.id == record.id }
        recentRecords.removeAll { $0.id == record.id }

        if let index = monthlyRanking.firstIndex(where: { $0.id == record.creatorId || $0.name == record.memberName }) {
            monthlyRanking[index].monthlyPoints = max(0, monthlyRanking[index].monthlyPoints - record.points)
            monthlyRanking.sort { $0.monthlyPoints > $1.monthlyPoints }
        }

        if let index = weekRanking.firstIndex(where: { $0.id == record.creatorId || $0.name == record.memberName }) {
            weekRanking[index].monthlyPoints = max(0, weekRanking[index].monthlyPoints - record.points)
            weekRanking.sort { $0.monthlyPoints > $1.monthlyPoints }
        }

    }

    private func restoreRecordLocally(_ record: ChoreRecord) {
        if !weekRecords.contains(where: { $0.id == record.id }) {
            weekRecords.append(record)
            weekRecords.sort { $0.createdAt > $1.createdAt }
        }
        if !recentRecords.contains(where: { $0.id == record.id }) {
            recentRecords.append(record)
            recentRecords.sort { $0.createdAt > $1.createdAt }
        }

        if let index = monthlyRanking.firstIndex(where: { $0.id == record.creatorId || $0.name == record.memberName }) {
            monthlyRanking[index].monthlyPoints += record.points
            monthlyRanking.sort { $0.monthlyPoints > $1.monthlyPoints }
        }
        if let index = weekRanking.firstIndex(where: { $0.id == record.creatorId || $0.name == record.memberName }) {
            weekRanking[index].monthlyPoints += record.points
            weekRanking.sort { $0.monthlyPoints > $1.monthlyPoints }
        }

        if usesMockData {
            updateMockMonthlyReport()
        }
    }

    private func beginRecordDeletionUndo(record: ChoreRecord, expiresAt: Date) {
        deletionUndoTask?.cancel()
        pendingRecordDeletion = PendingRecordDeletion(record: record, expiresAt: expiresAt)
        recordUndoErrorMessage = nil

        let delay = max(0, expiresAt.timeIntervalSinceNow)
        deletionUndoTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.clearRecordDeletionUndo()
        }
    }

    static func localRecordDeletionUndoExpiration(
        deletedAt: Date?,
        undoExpiresAt: Date?,
        now: Date = Date()
    ) -> Date {
        let fallbackWindow: TimeInterval = 10
        let serverWindow = deletedAt.flatMap { deletedAt in
            undoExpiresAt.map { $0.timeIntervalSince(deletedAt) }
        }
        let validServerWindow = serverWindow.flatMap { window in
            (window > 0 && window <= 60) ? min(window, fallbackWindow) : nil
        }

        // Rebuild the deadline from the duration instead of comparing clocks
        // across the device and server. Keep a small margin for the restore call.
        let localWindow = max(1, (validServerWindow ?? fallbackWindow) - 0.25)
        return now.addingTimeInterval(localWindow)
    }

    private func clearRecordDeletionUndo() {
        deletionUndoTask?.cancel()
        deletionUndoTask = nil
        pendingRecordDeletion = nil
    }

    private static func updateMockReaction(
        in records: inout [ChoreRecord],
        recordID: String,
        reaction: ChoreReaction?,
        liker: ActivityLiker
    ) {
        guard let index = records.firstIndex(where: { $0.id == recordID }) else { return }

        records[index].likedByMe = reaction != nil
        records[index].myReaction = reaction
        records[index].likedBy.removeAll { $0.id == liker.id }
        if let reaction {
            records[index].likedBy.append(
                ActivityLiker(
                    id: liker.id,
                    displayName: liker.displayName,
                    avatarKey: liker.avatarKey,
                    reaction: reaction
                )
            )
        }
        records[index].likeCount = records[index].likedBy.count
        records[index].reactionCounts = Self.reactionCounts(for: records[index].likedBy)
    }

    private static func reactionCounts(for likers: [ActivityLiker]) -> [ChoreReaction: Int] {
        Dictionary(grouping: likers, by: \.reaction).mapValues(\.count)
    }

    private func updateMockMonthlyReport() {
        monthlyReport = MonthlyReport(
            month: selectedReportMonth,
            totalPoints: monthlyRanking.reduce(0) { $0 + $1.monthlyPoints },
            totalRecords: weekRecords.count,
            totalMinutes: weekRecords.reduce(0) { $0 + $1.actualMinutes },
            headline: "家庭互动已同步，功劳簿继续营业",
            comparison: monthlyReport?.comparison,
            monthlyTrend: monthlyReport?.monthlyTrend ?? [],
            weeklyTrend: monthlyReport?.weeklyTrend ?? [],
            memberContributions: monthlyRanking.map { member in
                let memberRecords = weekRecords.filter { $0.creatorId == member.id || $0.memberName == member.name }
                return MonthlyMemberContribution(
                    userId: member.id,
                    displayName: member.name,
                    points: member.monthlyPoints,
                    recordCount: memberRecords.count,
                    totalMinutes: memberRecords.reduce(0) { $0 + $1.actualMinutes }
                )
            },
            themeStats: Dictionary(grouping: weekRecords) { record in
                chores.first(where: { $0.name == record.choreName })?.themeKey ?? ChoreTheme.daily.rawValue
            }
                .map { themeKey, records in
                    MonthlyReportTheme(
                        themeKey: themeKey,
                        points: records.reduce(0) { $0 + $1.points },
                        recordCount: records.count
                    )
                }
                .sorted { $0.points > $1.points },
            categoryStats: Dictionary(grouping: weekRecords, by: \.category)
                .map { category, records in
                    MonthlyReportCategory(
                        category: category,
                        points: records.reduce(0) { $0 + $1.points },
                        recordCount: records.count,
                        memberContributions: monthlyContributions(for: records)
                    )
                }
                .sorted { $0.points > $1.points }
        )
    }

    private func changeReportMonth(by offset: Int) {
        guard !isLoadingMonthlyReport else { return }

        let previousMonth = selectedReportMonth
        guard let currentDate = Self.monthFormatter.date(from: selectedReportMonth),
              let targetDate = Calendar(identifier: .gregorian).date(byAdding: .month, value: offset, to: currentDate)
        else {
            return
        }

        let targetMonth = Self.monthFormatter.string(from: targetDate)
        guard targetMonth <= currentMonth else { return }
        selectedReportMonth = targetMonth

        if usesMockData {
            loadMockMonthlyReport(for: targetMonth)
            return
        }

        isLoadingMonthlyReport = true
        Task {
            await performLoading("正在切换月度战报") {
                try await loadMonthlyReportFromAPI()
            }
            if errorMessage != nil {
                selectedReportMonth = previousMonth
            }
            isLoadingMonthlyReport = false
        }
    }

    private func loadMockMonthlyReport(for month: String) {
        let currentDate = Self.monthFormatter.date(from: currentMonth) ?? Date()
        let selectedDate = Self.monthFormatter.date(from: month) ?? currentDate
        let distance = max(
            0,
            -(Calendar(identifier: .gregorian).dateComponents([.month], from: currentDate, to: selectedDate).month ?? 0)
        )

        monthlyRanking = MockData.members.enumerated().map { index, member in
            var adjusted = member
            adjusted.monthlyPoints = max(0, member.monthlyPoints - distance * (index + 1) * 13)
            return adjusted
        }
        .sorted { $0.monthlyPoints > $1.monthlyPoints }

        let totalPoints = monthlyRanking.reduce(0) { $0 + $1.monthlyPoints }
        monthlyReport = MonthlyReport(
            month: month,
            totalPoints: totalPoints,
            totalRecords: max(0, MockData.monthlyReport.totalRecords - distance),
            totalMinutes: max(0, MockData.monthlyReport.totalMinutes - distance * 18),
            headline: distance == 0 ? "本月家庭战况持续更新" : "翻到旧功劳簿，看看当月谁最能打",
            comparison: MonthlyReportComparison(
                previousMonth: Self.monthFormatter.string(
                    from: Calendar(identifier: .gregorian).date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                ),
                totalPoints: max(0, totalPoints - 52),
                totalRecords: max(0, MockData.monthlyReport.totalRecords - distance - 2),
                totalMinutes: max(0, MockData.monthlyReport.totalMinutes - distance * 18 - 45)
            ),
            monthlyTrend: (0..<6).map { index in
                let offset = index - 5
                let date = Calendar(identifier: .gregorian).date(
                    byAdding: .month,
                    value: offset,
                    to: selectedDate
                ) ?? selectedDate
                let monthKey = Self.monthFormatter.string(from: date)
                let age = 5 - index + distance
                return MonthlyReportMonth(
                    month: monthKey,
                    points: max(0, totalPoints - age * 22 + (index.isMultiple(of: 2) ? 8 : 0)),
                    recordCount: max(0, MockData.monthlyReport.totalRecords - age),
                    totalMinutes: max(0, MockData.monthlyReport.totalMinutes - age * 16)
                )
            },
            weeklyTrend: MockData.monthlyReport.weeklyTrend.map { week in
                MonthlyReportWeek(
                    weekStart: week.weekStart,
                    weekEnd: week.weekEnd,
                    label: week.label,
                    points: max(0, week.points - distance * 5),
                    recordCount: max(0, week.recordCount - distance),
                    totalMinutes: max(0, week.totalMinutes - distance * 6)
                )
            },
            memberContributions: monthlyRanking.map { member in
                MonthlyMemberContribution(
                    userId: member.id,
                    displayName: member.name,
                    points: member.monthlyPoints,
                    recordCount: max(0, member.monthlyPoints / 20),
                    totalMinutes: max(0, member.monthlyPoints)
                )
            },
            themeStats: MockData.monthlyReport.themeStats.map { theme in
                MonthlyReportTheme(
                    themeKey: theme.themeKey,
                    points: max(0, theme.points - distance * 11),
                    recordCount: max(0, theme.recordCount - distance)
                )
            },
            categoryStats: MockData.monthlyReport.categoryStats.map { category in
                MonthlyReportCategory(
                    category: category.category,
                    points: max(0, category.points - distance * 9),
                    recordCount: max(0, category.recordCount - distance),
                    memberContributions: category.memberContributions
                )
            }
        )
    }

    private func applyMockOwnershipTransfer(to member: FamilyMemberProfile) {
        familyMembers = familyMembers.map { profile in
            FamilyMemberProfile(
                id: profile.id,
                userId: profile.userId,
                name: profile.name,
                identityLabel: profile.identityLabel,
                customIdentity: profile.customIdentity,
                avatarKey: profile.avatarKey,
                memberRole: profile.id == member.id ? .owner : .member,
                status: profile.status,
                joinedAt: profile.joinedAt
            )
        }

        if let membership = currentMembership {
            currentMembership = FamilyMembership(
                id: membership.id,
                userId: membership.userId,
                familyId: membership.familyId,
                identityLabel: membership.identityLabel,
                customIdentity: membership.customIdentity,
                avatarKey: membership.avatarKey,
                memberRole: .member,
                status: membership.status
            )
        }
    }

    private func applyMockAppearance(_ avatarKey: String) {
        guard let membership = currentMembership else { return }
        selectedAvatarKey = avatarKey
        currentMembership = FamilyMembership(
            id: membership.id,
            userId: membership.userId,
            familyId: membership.familyId,
            identityLabel: membership.identityLabel,
            customIdentity: membership.customIdentity,
            avatarKey: avatarKey,
            memberRole: membership.memberRole,
            status: membership.status
        )
        familyMembers = familyMembers.map { profile in
            guard profile.userId == membership.userId else { return profile }
            return FamilyMemberProfile(
                id: profile.id,
                userId: profile.userId,
                name: profile.name,
                identityLabel: profile.identityLabel,
                customIdentity: profile.customIdentity,
                avatarKey: avatarKey,
                memberRole: profile.memberRole,
                status: profile.status,
                joinedAt: profile.joinedAt
            )
        }
        weekRecords = weekRecords.map {
            $0.updatingAvatar(for: membership.userId, avatarKey: avatarKey)
        }
        recentRecords = recentRecords.map {
            $0.updatingAvatar(for: membership.userId, avatarKey: avatarKey)
        }
        memberActivityByMemberID = memberActivityByMemberID.mapValues { records in
            records.map { $0.updatingAvatar(for: membership.userId, avatarKey: avatarKey) }
        }
    }

    private func loginWithAPI() async {
        await performLoading("正在连接本地后端") {
            let response: LoginResponse = try await apiClient.post(
                "auth/mock-login",
                body: MockLoginRequest(
                    devIdentifier: normalizedDevelopmentIdentifier,
                    displayName: nil,
                    deviceId: UIDevice.current.identifierForVendor?.uuidString,
                    deviceName: UIDevice.current.name,
                    platform: "iOS",
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                )
            )

            try await completeAPILogin(response)
        }
    }

    private func completeAPILogin(_ response: LoginResponse) async throws {
        let pendingNickname = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try tokenStore.saveTokens(response.tokens)
            lastSecureStorageErrorMessage = nil
        } catch {
            lastSecureStorageErrorMessage = error.localizedDescription
            throw AppStateError.secureSessionStorageFailed
        }

        accessToken = response.accessToken
        currentUser = mapUser(response.user)
        accountHasPremiumAccess = response.user.plan == "premium"
        hasPremiumAccess = accountHasPremiumAccess
        displayName = response.user.displayName
        userDefaults.set(true, forKey: Self.hasAuthenticatedBeforeDefaultsKey)
        await apiClient.setAuthTokens(response.tokens)

        if case let .joinFamily(inviteCode) = pendingAuthAction {
            displayName = pendingNickname
            joinInviteCode = inviteCode
            pendingAuthAction = nil
            rootScreen = .joinFamily
            sessionState = .authenticated
            validateJoinInviteCode()
            return
        }
        if pendingAuthAction == .claimLocalDraft {
            if let draftName = localDraftFamily?.displayName,
               draftName != response.user.displayName {
                let user: UserDTO = try await apiClient.patch(
                    "auth/me",
                    body: UpdateCurrentUserRequest(displayName: draftName)
                )
                currentUser = mapUser(user)
                displayName = user.displayName
            }
            let familyId = try await claimLocalDraftWithAPI()
            pendingAuthAction = nil
            localDraftFamily = nil
            try localWorkspaceStore.delete()
            let families = try await loadMyFamiliesFromAPI(preferredFamilyId: familyId)
            guard !families.isEmpty else {
                throw AppStateError.missingFamily
            }
            try await loadChoresFromAPI()
            selectedTab = .today
            rootScreen = .home
            try await refreshHomeDataFromAPI(includeChores: false)
            sessionState = .authenticated
            return
        }

        let families = try await loadMyFamiliesFromAPI()
        try await loadChoresFromAPI()
        if families.isEmpty {
            if try await loadMyJoinApplicationFromAPI() != nil {
                rootScreen = .joinStatus
            } else {
                rootScreen = .createFamily
            }
        } else {
            selectedTab = .today
            rootScreen = .home
            try await refreshHomeDataFromAPI()
        }
        sessionState = .authenticated
    }

    private func claimLocalDraftWithAPI() async throws -> String {
        guard var draft = localDraftFamily else {
            throw AppStateError.missingFamily
        }
        draft.claimState = .claiming
        localDraftFamily = draft
        persistLocalDraft(draft)

        let response: ClaimLocalDraftResponse = try await apiClient.post(
            "families/claim-local-draft",
            body: ClaimLocalDraftRequest(
                draftId: draft.id.uuidString.lowercased(),
                draftCreatedAt: draft.createdAt,
                familyName: draft.name,
                identityLabel: selectedIdentityLabel,
                customIdentity: normalizedCustomIdentity,
                avatarKey: selectedAvatarKey,
                timezone: TimeZone.current.identifier,
                chores: draft.selectedChores.map { chore in
                    ClaimLocalDraftChoreRequest(
                        localId: chore.id,
                        source: chore.source == .catalog ? "CATALOG" : "CUSTOM",
                        catalogKey: chore.catalogKey,
                        name: chore.name,
                        category: chore.category,
                        standardMinutes: chore.minutes,
                        difficultyMultiplier: chore.difficultyMultiplier,
                        icon: chore.icon
                    )
                },
                records: draft.records.map { record in
                    ClaimLocalDraftRecordRequest(
                        id: record.id.uuidString.lowercased(),
                        choreLocalId: record.choreID,
                        actualMinutes: record.actualMinutes,
                        note: record.note,
                        occurredAt: record.occurredAt
                    )
                }
            )
        )
        return response.familyId
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

            applyCurrentFamily(family)
            try await loadChoresFromAPI()
            prepareInitialChoreSetup()
            rootScreen = .choreSetup
            sessionState = .authenticated
        }
    }

    private func submitJoinRequestWithAPI() async {
        await performLoading("正在提交加入申请") {
            let inviteCode = joinInviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
            let response: JoinRequestDTO = try await apiClient.post(
                "families/join-requests",
                body: CreateJoinRequestRequest(
                    inviteCode: inviteCode,
                    identityLabel: selectedIdentityLabel,
                    customIdentity: normalizedCustomIdentity,
                    avatarKey: selectedAvatarKey
                )
            )
            joinRequestSubmitted = true
            let family: FamilyInvitePreview
            if let validInvitePreview {
                family = validInvitePreview
            } else {
                let previewDTO: FamilyInvitePreviewDTO = try await apiClient.get(
                    "families/invitations/\(normalizedJoinInviteCode)"
                )
                family = mapInvitePreview(previewDTO)
            }
            currentJoinApplication = mapJoinApplication(response, family: family)
            rootScreen = .joinStatus
        }
    }

    private func loadJoinRequestsFromAPI() async throws {
        guard let familyId = currentFamily?.id else {
            throw AppStateError.missingFamily
        }

        let response: [JoinRequestDTO] = try await apiClient.get("families/\(familyId)/join-requests")
        joinRequests = response.map(mapJoinRequest)
    }

    @discardableResult
    private func loadMyJoinApplicationFromAPI() async throws -> JoinApplication? {
        let response: JoinApplicationDTO? = try await apiClient.get("families/join-requests/me")

        guard let response else {
            currentJoinApplication = nil
            return nil
        }

        if let user = response.user {
            currentUser = mapUser(user)
        }

        let application = mapJoinApplication(response)
        currentJoinApplication = application
        joinRequestSubmitted = true
        return application
    }

    private func performJoinReview(_ request: JoinRequestItem, approve: Bool) async {
        reviewingRequestID = request.id
        reviewErrors[request.id] = nil

        do {
            guard let familyId = currentFamily?.id else {
                throw AppStateError.missingFamily
            }

            let _: JoinRequestDTO = try await apiClient.patch(
                "families/\(familyId)/join-requests/\(request.id)",
                body: ReviewJoinRequestRequest(action: approve ? "approve" : "reject")
            )
            joinRequests.removeAll { $0.id == request.id }
            if approve {
                _ = try await loadMyFamiliesFromAPI(preferredFamilyId: familyId)
            }
        } catch {
            if let apiError = error as? APIError, apiError.isUnauthorized, accessToken != nil {
                await clearInvalidSession()
                errorMessage = "登录已失效，请重新登录。"
            } else {
                reviewErrors[request.id] = error.localizedDescription
            }
        }

        await syncAPIDebugSnapshot()
        reviewingRequestID = nil
    }

    private func createRecordWithAPI(
        _ chore: ChoreItem,
        actualMinutes: Int?,
        calculatedPoints: Int?,
        pointsMultiplier: Double?
    ) async {
        var evaluation: AchievementEvaluationDTO?
        let requestID = UUID().uuidString
        isLoading = true
        loadingMessage = "正在记录实际耗时"
        errorMessage = nil

        do {
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
                    pointsMultiplier: pointsMultiplier,
                    note: recordSuccessNote(for: chore.name),
                    imageUrls: []
                ),
                headers: ["Idempotency-Key": requestID]
            )

            weekRecords.insert(mapRecord(record), at: 0)
            recentRecords.insert(mapRecord(record), at: 0)
            evaluation = record.achievementEvaluation
            selectedTab = .today
            try await refreshHomeDataFromAPI()
            mergePendingRecordsIntoVisibleActivity()
            isOffline = false
            lastSuccessfulSyncAt = Date()
        } catch {
            if APIError.isConnectivityError(error) {
                enqueueOfflineRecord(
                    chore,
                    actualMinutes: actualMinutes,
                    calculatedPoints: calculatedPoints,
                    pointsMultiplier: pointsMultiplier,
                    requestID: requestID
                )
                isOffline = true
                errorMessage = nil
                selectedTab = .today
                rootScreen = .home
                sessionState = .authenticated
            } else if let apiError = error as? APIError, apiError.isUnauthorized {
                await clearInvalidSession()
                errorMessage = "登录已失效，请重新登录。"
            } else {
                errorMessage = error.localizedDescription
            }
        }
        await syncAPIDebugSnapshot()
        isLoading = false
        loadingMessage = nil

        if let evaluation {
            beginAchievementSync(evaluation)
        } else if !isOffline {
            Task { await refreshAchievements() }
        }
    }

    private func beginAchievementSync(_ evaluation: AchievementEvaluationDTO) {
        guard let familyId = currentFamily?.id else { return }
        achievementSyncTask?.cancel()
        achievementSyncState = .pending

        achievementSyncTask = Task { [weak self] in
            guard let self else { return }
            var retryDelay = max(250, min(1_500, evaluation.retryAfterMs ?? 500))

            for _ in 0..<12 {
                do {
                    try await Task.sleep(for: .milliseconds(retryDelay))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }

                do {
                    let sync: AchievementSyncDTO = try await apiClient.get(
                        "families/\(familyId)/achievement-sync/\(evaluation.eventId)"
                    )
                    switch sync.state {
                    case "SUCCEEDED":
                        try await loadAchievementsFromAPI()
                        achievementDataState = .loaded
                        achievementSyncState = .idle

                        let unlocks = sync.unlockBatch?.unlocks ?? []
                        let unlocked = unlocks.compactMap { unlock in
                            achievementItems.first {
                                $0.key == unlock.achievementKey && $0.tier == unlock.tier
                            }
                        }
                        let rewards = sync.unlockBatch?.rewards.map {
                            AchievementReward(type: $0.rewardType, value: $0.rewardValue)
                        } ?? []
                        if !unlocked.isEmpty || !rewards.isEmpty {
                            let celebrationID = sync.unlockBatch?.id ?? evaluation.eventId
                            if !dismissedAchievementCelebrationIDs.contains(celebrationID) {
                                pendingAchievementCelebration = AchievementCelebration(
                                    id: celebrationID,
                                    achievements: unlocked,
                                    rewards: rewards
                                )
                            }
                        }
                        await syncAPIDebugSnapshot()
                        return
                    case "FAILED":
                        achievementSyncState = .failed
                        await syncAPIDebugSnapshot()
                        return
                    default:
                        retryDelay = max(250, min(1_500, sync.retryAfterMs ?? 500))
                    }
                } catch {
                    if let apiError = error as? APIError, apiError.isUnauthorized {
                        await clearInvalidSession()
                        errorMessage = "登录已失效，请重新登录。"
                        return
                    }
                    if !APIError.isConnectivityError(error) {
                        achievementSyncState = .failed
                        await syncAPIDebugSnapshot()
                        return
                    }
                }
            }

            achievementSyncState = .failed
            await syncAPIDebugSnapshot()
        }
    }

    private func recordSuccessNote(for choreName: String) -> String {
        "\(choreName)：" + RotatingCopy.value(
            from: RotatingCopy.recordSuccess,
            seed: Int.random(in: 0..<10_000)
        )
    }

    private func loadChoresFromAPI() async throws {
        let baseResponse: [ChoreDTO] = try await apiClient.get("chores")
        guard let familyId = currentFamily?.id else {
            replaceChores(baseResponse.map(mapChore))
            return
        }

        let customResponse: [ChoreDTO] = try await apiClient.get(
            "families/\(familyId)/custom-chores"
        )
        replaceChores((baseResponse + customResponse).map(mapChore))
        try await loadChoreLayoutFromAPI(familyId: familyId)
    }

    private func loadChoreLayoutFromAPI(familyId: String) async throws {
        let response: ChoreLayoutDTO = try await apiClient.get("families/\(familyId)/chore-layout")
        applyChoreLayout(response)
    }

    private func applyChoreLayout(_ response: ChoreLayoutDTO) {
        choreOrder = response.choreIds
        pinnedChoreIDs = Set(response.pinnedChoreIds)
        choreLayoutConfigured = response.isConfigured
        choreLayoutCanEdit = response.canEdit ?? (hasPremiumAccess || isCurrentUserOwner)
        choreLayoutScope = response.scope ?? (hasPremiumAccess ? "member" : "family")
        choreLayoutIsPersonalized = response.isPersonalized ?? false
        followsFamilyChoreLayout = response.followFamilyLayout ?? !choreLayoutIsPersonalized
        serverCommonChoreSelectionLimit = response.selectionLimit
        serverCustomChoreLimit = response.customChoreLimit ?? (hasPremiumAccess ? 100 : 2)
        synchronizeChoreLayout()
    }

    private func prepareInitialChoreSetup() {
        choreOrder = []
        pinnedChoreIDs = []
        choreLayoutConfigured = false
        choreLayoutCanEdit = true
        choreLayoutScope = hasPremiumAccess ? "member" : "family"
        choreLayoutIsPersonalized = false
        followsFamilyChoreLayout = true
        persistChoreLayout()
        synchronizeCommonChoreGridOrder()
    }

    private func saveMockCustomChore(_ draft: CustomChoreDraft, editing chore: ChoreItem?) {
        let option = CustomChoreCatalog.option(for: draft.iconKey) ?? CustomChoreCatalog.options[0]
        let item = ChoreItem(
            id: chore?.id ?? "mock-custom-chore-\(UUID().uuidString)",
            name: draft.name,
            category: draft.category.rawValue,
            minutes: draft.standardMinutes,
            points: draft.defaultPoints,
            icon: draft.iconKey,
            color: chore?.color ?? option.color,
            themeKey: "custom",
            difficultyMultiplier: draft.difficultyMultiplier,
            suggestedFrequency: nil,
            isCustom: true,
            customSlot: chore?.customSlot ?? (Array(1...customChoreLimit).first { slot in
                !customChores.contains { $0.customSlot == slot }
            })
        )

        var updated = chores
        if let chore, let index = updated.firstIndex(where: { $0.id == chore.id }) {
            updated[index] = item
        } else if availableCustomChoreSlots > 0 {
            let insertionIndex = updated.firstIndex(where: \.isLocked) ?? updated.endIndex
            updated.insert(item, at: insertionIndex)
        }
        replaceChores(updated)
    }

    private func replaceChores(_ newChores: [ChoreItem]) {
        chores = newChores
        synchronizeChoreLayout()
    }

    private func synchronizeChoreLayout() {
        let unlockedIDs = routineCatalogChores.map(\.id)
        let availableIDs = Set(unlockedIDs)
        choreOrder = choreOrder.filter { availableIDs.contains($0) }
        pinnedChoreIDs = pinnedChoreIDs.intersection(availableIDs)
        persistChoreLayout()
        synchronizeCommonChoreGridOrder()
    }

    private func normalizedUnlockedOrder() -> [String] {
        let unlockedIDs = routineCatalogChores.map(\.id)
        let availableIDs = Set(unlockedIDs)
        return choreOrder.filter { availableIDs.contains($0) }
    }

    private func normalizedCommonChoreGridOrder(from savedOrder: [String]) -> [String] {
        let occupiedSlots = customChores.compactMap(\.customSlot)
        let occupiedSet = Set(occupiedSlots)
        let placeholderUpperBound = min(customChoreLimit, customChores.count + 2)
        let emptySlots = (1...placeholderUpperBound)
            .filter { !occupiedSet.contains($0) }
            .filter { !hiddenCommonCustomSlotIDs.contains(Self.customChoreSlotID($0)) }
        let visibleCustomSlots = Array(occupiedSet.union(emptySlots)).sorted()
        let availableIDs = displayedChores.map(\.id) + visibleCustomSlots.map(Self.customChoreSlotID)
        let availableSet = Set(availableIDs)
        let saved = savedOrder.filter { availableSet.contains($0) }
        let savedSet = Set(saved)
        return saved + availableIDs.filter { !savedSet.contains($0) }
    }

    private func synchronizeCommonChoreGridOrder() {
        loadCommonChoreGridOrderIfNeeded()
        let normalized = normalizedCommonChoreGridOrder(from: commonChoreGridOrder)
        if usesSharedFamilyChoreLayout {
            commonChoreGridOrder = mergingFamilyRoutineOrder(
                into: normalized,
                routineIDs: displayedChores.filter { !$0.isCustom }.map(\.id)
            )
        } else {
            commonChoreGridOrder = normalized
        }
        persistCommonChoreGridOrder()
    }

    private func mergingFamilyRoutineOrder(
        into savedOrder: [String],
        routineIDs: [String]
    ) -> [String] {
        let routineSet = Set(routineCatalogChores.map(\.id))
        var remainingRoutineIDs = ArraySlice(routineIDs)
        var merged: [String] = []

        for itemID in savedOrder {
            if customChoreSlot(forGridItemID: itemID) != nil {
                merged.append(itemID)
            } else if routineSet.contains(itemID), let nextRoutineID = remainingRoutineIDs.popFirst() {
                merged.append(nextRoutineID)
            }
        }

        merged.append(contentsOf: remainingRoutineIDs)
        let mergedSet = Set(merged)
        merged.append(contentsOf: savedOrder.filter { !mergedSet.contains($0) })
        return merged
    }

    private func loadCommonChoreGridOrderIfNeeded() {
        let scope = commonChoreGridDefaultsKey
        guard commonChoreGridScope != scope else { return }
        commonChoreGridScope = scope
        commonChoreGridOrder = userDefaults.stringArray(forKey: scope) ?? []
        hiddenCommonCustomSlotIDs = Set(
            userDefaults.stringArray(forKey: commonChoreHiddenSlotsDefaultsKey) ?? []
        )
    }

    private func persistCommonChoreGridOrder() {
        commonChoreGridScope = commonChoreGridDefaultsKey
        userDefaults.set(commonChoreGridOrder, forKey: commonChoreGridDefaultsKey)
        userDefaults.set(
            Array(hiddenCommonCustomSlotIDs).sorted(),
            forKey: commonChoreHiddenSlotsDefaultsKey
        )
    }

    private var commonChoreGridDefaultsKey: String {
        let userID = currentUser?.id ?? "anonymous"
        let familyID = currentFamily?.id ?? "no-family"
        if usesSharedFamilyChoreLayout {
            return "\(Self.commonChoreGridDefaultsKeyPrefix)-family-\(familyID)"
        }
        return "\(Self.commonChoreGridDefaultsKeyPrefix)-member-\(userID)-\(familyID)"
    }

    private var commonChoreHiddenSlotsDefaultsKey: String {
        "\(commonChoreGridDefaultsKey)-hidden-custom-slots"
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
            familyMembers = []
            hasPremiumAccess = accountHasPremiumAccess
        }

        return families
    }

    private func applyCurrentFamily(_ family: FamilyDTO) {
        let shouldChangeAchievementScope = achievementSummary?.familyId != family.id
        currentFamily = mapFamily(family)
        currentMembership = membership(from: family)
        hasPremiumAccess = family.hasPremiumAccess ?? accountHasPremiumAccess
        if let avatarKey = currentMembership?.avatarKey {
            selectedAvatarKey = avatarKey
        }
        familyMembers = (family.members ?? []).compactMap(mapFamilyMemberProfile)
        familyName = family.name
        requiresPhotoProof = family.requirePhotoProof

        if shouldChangeAchievementScope {
            achievementSummary = nil
            achievementItems = []
            showAchievementsToFamily = true
            achievementLastUpdatedAt = nil
            achievementDataState = loadAchievementCache() ? .cached : .idle
        }
    }

    private func replaceCurrentFamilyName(_ name: String) {
        guard let family = currentFamily else { return }
        currentFamily = FamilySpace(
            id: family.id,
            name: name,
            inviteCode: family.inviteCode,
            requiresPhotoProof: family.requiresPhotoProof,
            timezone: family.timezone
        )
        familyName = name
    }

    private func refreshHomeDataFromAPI(includeChores: Bool = true) async throws {
        guard let familyId = currentFamily?.id else {
            return
        }

        if includeChores {
            try await loadChoresFromAPI()
        }

        async let weekActivity: [ActivityItemDTO] = apiClient.get(
            "families/\(familyId)/activity",
            queryItems: selectedWeekQueryItems
        )
        async let recentActivity: [ActivityItemDTO] = apiClient.get(
            "families/\(familyId)/activity",
            queryItems: [URLQueryItem(name: "range", value: "recent")]
        )
        async let weekLeaderboard: [LeaderboardItemDTO] = apiClient.get(
            "families/\(familyId)/leaderboard",
            queryItems: selectedWeekQueryItems
        )
        async let report: MonthlyReportDTO = apiClient.get(
            "families/\(familyId)/monthly-report",
            queryItems: [URLQueryItem(name: "month", value: selectedReportMonth)]
        )

        let (weekItems, recentItems, weekLeaderboardItems, monthlyReportDTO) = try await (
            weekActivity,
            recentActivity,
            weekLeaderboard,
            report
        )

        weekRecords = weekItems.map(mapActivity)
        recentRecords = recentItems.map(mapActivity)
        weekRanking = mapRanking(weekLeaderboardItems)
        applyMonthlyReport(monthlyReportDTO)
    }

    private func loadAchievementsFromAPI() async throws {
        guard let familyId = currentFamily?.id else {
            throw AppStateError.missingFamily
        }

        async let summaryResponse: AchievementSummaryDTO = apiClient.get(
            "families/\(familyId)/achievements/summary"
        )
        async let collectionResponse: AchievementCollectionDTO = apiClient.get(
            "families/\(familyId)/achievements/me"
        )
        let (summaryDTO, collectionDTO) = try await (summaryResponse, collectionResponse)

        achievementSummary = mapAchievementSummary(summaryDTO)
        achievementItems = collectionDTO.achievements.map(mapAchievement)
        showAchievementsToFamily = collectionDTO.showAchievementsToFamily
        achievementLastUpdatedAt = collectionDTO.updatedAt
        saveAchievementCache()
    }

    private func loadAchievementCache() -> Bool {
        guard let key = achievementCacheKey,
              let data = userDefaults.data(forKey: key),
              let envelope = try? JSONDecoder().decode(AchievementCacheEnvelope.self, from: data)
        else {
            return false
        }

        achievementSummary = envelope.summary
        achievementItems = envelope.collection.achievements
        showAchievementsToFamily = envelope.collection.showAchievementsToFamily
        achievementLastUpdatedAt = envelope.cachedAt
        return true
    }

    private func saveAchievementCache() {
        guard let key = achievementCacheKey,
              let summary = achievementSummary,
              let familyId = currentFamily?.id,
              let userId = currentUser?.id
        else {
            return
        }

        let cachedAt = Date()
        let envelope = AchievementCacheEnvelope(
            summary: summary,
            collection: AchievementCollection(
                familyId: familyId,
                userId: userId,
                showAchievementsToFamily: showAchievementsToFamily,
                achievements: achievementItems,
                capacity: summary.capacity,
                updatedAt: achievementLastUpdatedAt ?? cachedAt
            ),
            cachedAt: cachedAt
        )
        if let data = try? JSONEncoder().encode(envelope) {
            userDefaults.set(data, forKey: key)
        }
    }

    private var achievementCacheKey: String? {
        guard let familyId = currentFamily?.id, let userId = currentUser?.id else { return nil }
        return "\(Self.achievementCacheKeyPrefix)-\(userId)-\(familyId)"
    }

    private func applyAchievementSharing(_ showToFamily: Bool) {
        self.showAchievementsToFamily = showToFamily
        let visibility: AchievementVisibility = showToFamily ? .family : .privateOnly
        achievementItems = achievementItems.map { item in
            guard item.memberAchievementId != nil else { return item }
            var updated = item
            updated.visibility = visibility
            return updated
        }

        guard let summary = achievementSummary else { return }
        achievementSummary = AchievementSummary(
            familyId: summary.familyId,
            userId: summary.userId,
            showAchievementsToFamily: showToFamily,
            unlockedCount: summary.unlockedCount,
            totalCount: summary.totalCount,
            nextAchievement: summary.nextAchievement,
            recentUnlocks: summary.recentUnlocks.map { item in
                guard item.memberAchievementId != nil else { return item }
                var updated = item
                updated.visibility = visibility
                return updated
            },
            capacity: summary.capacity
        )
    }

    private func refreshSelectedWeekFromAPI() async throws {
        guard let familyId = currentFamily?.id else {
            throw AppStateError.missingFamily
        }

        async let activity: [ActivityItemDTO] = apiClient.get(
            "families/\(familyId)/activity",
            queryItems: selectedWeekQueryItems
        )
        async let leaderboard: [LeaderboardItemDTO] = apiClient.get(
            "families/\(familyId)/leaderboard",
            queryItems: selectedWeekQueryItems
        )

        let (activityItems, leaderboardItems) = try await (activity, leaderboard)
        weekRecords = activityItems.map(mapActivity)
        weekRanking = mapRanking(leaderboardItems)
    }

    private var selectedWeekQueryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "range", value: "week"),
            URLQueryItem(name: "weekOffset", value: String(selectedWeekOffset)),
        ]
    }

    private func loadMonthlyReportFromAPI() async throws {
        guard let familyId = currentFamily?.id else {
            throw AppStateError.missingFamily
        }

        let report: MonthlyReportDTO = try await apiClient.get(
            "families/\(familyId)/monthly-report",
            queryItems: [URLQueryItem(name: "month", value: selectedReportMonth)]
        )
        applyMonthlyReport(report)
    }

    private func applyMonthlyReport(_ report: MonthlyReportDTO) {
        monthlyRanking = report.leaderboard.enumerated().map { index, item in
            FamilyMember(
                id: item.userId,
                name: item.displayName,
                monthlyPoints: item.points,
                badge: "\(item.recordCount) 条记录",
                color: Self.palette[index % Self.palette.count]
            )
        }
        monthlyReport = mapMonthlyReport(report)
    }

    private func mapRanking(_ items: [LeaderboardItemDTO]) -> [FamilyMember] {
        items.enumerated().map { index, item in
            FamilyMember(
                id: item.userId,
                name: item.displayName,
                monthlyPoints: item.points,
                badge: "\(item.recordCount) 条记录",
                color: Self.palette[index % Self.palette.count]
            )
        }
    }

    private func refreshActivityFromAPI() async throws {
        guard let familyId = currentFamily?.id else {
            throw AppStateError.missingFamily
        }

        async let weekActivity: [ActivityItemDTO] = apiClient.get(
            "families/\(familyId)/activity",
            queryItems: selectedWeekQueryItems
        )
        async let recentActivity: [ActivityItemDTO] = apiClient.get(
            "families/\(familyId)/activity",
            queryItems: [URLQueryItem(name: "range", value: "recent")]
        )
        let (weekItems, recentItems) = try await (weekActivity, recentActivity)
        weekRecords = weekItems.map(mapActivity)
        recentRecords = recentItems.map(mapActivity)
    }

    private func performLoading(_ message: String, operation: () async throws -> Void) async {
        isLoading = true
        loadingMessage = message
        errorMessage = nil
        _ = await apiClient.consumeOfflineFallbackFlag()

        do {
            try await operation()
            let usedCachedResponse = await apiClient.consumeOfflineFallbackFlag()
            isOffline = usedCachedResponse
            if !usedCachedResponse {
                lastSuccessfulSyncAt = Date()
            }
        } catch {
            #if DEBUG
            print("[AppViewModel] \(message) failed: \(error.localizedDescription)")
            #endif
            if APIError.isConnectivityError(error) {
                isOffline = true
            }

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
        await apiClient.setAuthTokens(nil)

        do {
            try tokenStore.deleteTokens()
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
        if snapshot.usedCachedResponse {
            isOffline = true
            lastSuccessfulSyncAt = snapshot.cachedResponseDate ?? lastSuccessfulSyncAt
        }
    }

    private func clearError() {
        errorMessage = nil
    }

    private var normalizedDevelopmentIdentifier: String {
        developmentIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func looksLikeEmail(_ value: String) -> Bool {
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains(".") else { return false }
        return !value.contains(where: \.isWhitespace)
    }

    private var normalizedDisplayName: String? {
        let normalized = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : String(normalized.prefix(30))
    }

    private var normalizedJoinInviteCode: String {
        joinInviteCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private var validInvitePreview: FamilyInvitePreview? {
        guard case let .valid(preview) = inviteValidationState else {
            return nil
        }
        return preview
    }

    private func inviteValidationMessage(for error: Error) -> String {
        if case let APIError.requestFailed(statusCode, _) = error, statusCode == 404 {
            return "没有找到这个家庭，请检查邀请码"
        }
        return error.localizedDescription
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

    private func addWeekPoints(_ points: Int, to memberName: String) {
        if let index = weekRanking.firstIndex(where: { $0.id == currentUser?.id || $0.name == memberName }) {
            weekRanking[index].monthlyPoints += points
        } else {
            weekRanking.insert(
                FamilyMember(
                    id: currentUser?.id ?? "mock-user-\(UUID().uuidString)",
                    name: memberName,
                    monthlyPoints: points,
                    badge: "本周新晋选手",
                    color: DSColor.infoBlue
                ),
                at: 0
            )
        }

        weekRanking.sort { $0.monthlyPoints > $1.monthlyPoints }
    }

    private func mapUser(_ dto: UserDTO) -> AppUser {
        AppUser(
            id: dto.id,
            displayName: dto.displayName,
            avatarInitial: String(dto.displayName.prefix(1)),
            badge: usesMockData ? "今日值班观察员" : "API 联调用户"
        )
    }

    private func restoreMockPremiumAccess() {
        guard let userId = currentUser?.id else {
            accountHasPremiumAccess = false
            hasPremiumAccess = false
            return
        }
        accountHasPremiumAccess = userDefaults.bool(forKey: Self.premiumAccessKey(for: userId))
        hasPremiumAccess = accountHasPremiumAccess
    }

    private func persistMockPremiumAccess() {
        guard let userId = currentUser?.id else {
            return
        }
        userDefaults.set(true, forKey: Self.premiumAccessKey(for: userId))
        accountHasPremiumAccess = true
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

    private func mapFamilyMemberProfile(_ dto: FamilyMemberDTO) -> FamilyMemberProfile? {
        let roleValue = dto.memberRole ?? dto.role?.uppercased() ?? "MEMBER"
        let statusValue = dto.status ?? "ACTIVE"

        guard let role = FamilyMemberRole(rawValue: roleValue),
              let status = FamilyMemberStatus(rawValue: statusValue) else {
            return nil
        }

        return FamilyMemberProfile(
            id: dto.id,
            userId: dto.userId,
            name: dto.user?.displayName ?? "家庭成员",
            identityLabel: dto.identityLabel ?? "家庭成员",
            customIdentity: dto.customIdentity,
            avatarKey: dto.avatarKey,
            memberRole: role,
            status: status,
            joinedAt: dto.createdAt ?? .distantPast
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
            status: FamilyMemberStatus(rawValue: dto.status) ?? .pending,
            createdAt: dto.createdAt
        )
    }

    private func mapInvitePreview(_ dto: FamilyInvitePreviewDTO) -> FamilyInvitePreview {
        FamilyInvitePreview(
            id: dto.id,
            name: dto.name,
            inviteCode: dto.inviteCode,
            memberCount: dto.memberCount,
            owner: dto.owner.map {
                FamilyInviteOwner(
                    id: $0.id,
                    displayName: $0.displayName,
                    identityLabel: $0.identityLabel,
                    customIdentity: $0.customIdentity,
                    avatarKey: $0.avatarKey
                )
            },
            currentStatus: dto.currentStatus.flatMap(FamilyMemberStatus.init(rawValue:))
        )
    }

    private func mapJoinApplication(_ dto: JoinApplicationDTO) -> JoinApplication {
        JoinApplication(
            id: dto.id,
            userId: dto.userId,
            identityLabel: dto.identityLabel,
            customIdentity: dto.customIdentity,
            avatarKey: dto.avatarKey,
            status: FamilyMemberStatus(rawValue: dto.status) ?? .pending,
            createdAt: dto.createdAt,
            family: mapInvitePreview(dto.family)
        )
    }

    private func mapJoinApplication(_ dto: JoinRequestDTO, family: FamilyInvitePreview) -> JoinApplication {
        JoinApplication(
            id: dto.id,
            userId: dto.userId,
            identityLabel: dto.identityLabel,
            customIdentity: dto.customIdentity,
            avatarKey: dto.avatarKey,
            status: FamilyMemberStatus(rawValue: dto.status) ?? .pending,
            createdAt: dto.createdAt,
            family: family
        )
    }

    private func mapChore(_ dto: ChoreDTO) -> ChoreItem {
        let icon = dto.icon ?? Self.icon(forName: dto.name, category: dto.category)
        let customOption = dto.isCustom == true ? CustomChoreCatalog.option(for: icon) : nil
        let category = ChoreCategory.resolve(dto.category, choreName: dto.name).rawValue
        return ChoreItem(
            id: dto.id,
            catalogKey: dto.catalogKey,
            name: dto.name,
            category: category,
            minutes: dto.minutes,
            points: dto.points,
            icon: icon,
            color: customOption?.color ?? Self.color(forCategory: category),
            themeKey: dto.themeKey ?? (dto.isCustom == true ? "custom" : ChoreTheme.daily.rawValue),
            difficultyMultiplier: dto.difficultyMultiplier ?? 1,
            suggestedFrequency: dto.suggestedFrequency,
            isCustom: dto.isCustom ?? false,
            customSlot: dto.customSlot,
            isLocked: dto.isLocked,
            requiredPlan: dto.requiredPlan
        )
    }

    private func mapRecord(_ dto: ChoreRecordDTO) -> ChoreRecord {
        let creator = dto.createdBy ?? dto.user
        let category = ChoreCategory.resolve(dto.chore.category, choreName: dto.chore.name).rawValue
        return ChoreRecord(
            id: dto.recordId ?? dto.id,
            memberName: creator.displayName,
            choreName: dto.choreName ?? dto.chore.name,
            category: category,
            standardMinutes: dto.minutes,
            actualMinutes: dto.actualMinutes ?? dto.minutes,
            points: dto.points,
            note: dto.note ?? "",
            createdAt: dto.createdAt,
            icon: dto.chore.icon ?? Self.icon(forName: dto.chore.name, category: dto.chore.category),
            color: Self.color(forCategory: category),
            creatorId: creator.id,
            identityLabel: creator.identityLabel ?? "家庭成员",
            customIdentity: creator.customIdentity,
            avatarKey: creator.avatarKey,
            likeCount: dto.likeCount ?? 0,
            likedBy: mapLikers(dto.likedBy),
            likedByMe: dto.likedByMe ?? false,
            reactionCounts: mapReactionCounts(dto.reactionCounts),
            myReaction: dto.myReaction.flatMap(ChoreReaction.init(rawValue:)),
            canDelete: dto.canDelete ?? true,
            canEdit: dto.canEdit ?? true,
            choreId: dto.chore.id,
            defaultPoints: dto.chore.defaultPoints,
            pointsMultiplier: dto.pointsMultiplier
        )
    }

    private func mapActivity(_ dto: ActivityItemDTO) -> ChoreRecord {
        let creator = dto.createdBy ?? dto.user
        let currentMember = familyMembers.first { member in
            member.userId == creator.id && member.status == .active
        }
        let category = ChoreCategory.resolve(dto.chore.category, choreName: dto.chore.name).rawValue
        return ChoreRecord(
            id: dto.recordId ?? dto.id,
            memberName: creator.displayName,
            choreName: dto.choreName ?? dto.chore.name,
            category: category,
            standardMinutes: dto.minutes,
            actualMinutes: dto.actualMinutes ?? dto.minutes,
            points: dto.points,
            note: dto.note ?? "",
            createdAt: dto.createdAt,
            icon: dto.chore.icon ?? Self.icon(forName: dto.chore.name, category: dto.chore.category),
            color: Self.color(forCategory: category),
            creatorId: creator.id,
            identityLabel: creator.identityLabel ?? "家庭成员",
            customIdentity: creator.customIdentity,
            avatarKey: currentMember?.avatarKey ?? creator.avatarKey,
            likeCount: dto.likeCount ?? 0,
            likedBy: mapLikers(dto.likedBy),
            likedByMe: dto.likedByMe ?? false,
            reactionCounts: mapReactionCounts(dto.reactionCounts),
            myReaction: dto.myReaction.flatMap(ChoreReaction.init(rawValue:)),
            canDelete: dto.canDelete ?? false,
            canEdit: dto.canEdit ?? false,
            choreId: dto.chore.id,
            defaultPoints: dto.chore.defaultPoints,
            pointsMultiplier: dto.pointsMultiplier
        )
    }

    private func mapAchievementSummary(_ dto: AchievementSummaryDTO) -> AchievementSummary {
        AchievementSummary(
            familyId: dto.familyId,
            userId: dto.userId,
            showAchievementsToFamily: dto.showAchievementsToFamily,
            unlockedCount: dto.unlockedCount,
            totalCount: dto.totalCount,
            nextAchievement: dto.nextAchievement.map(mapAchievement),
            recentUnlocks: dto.recentUnlocks.map(mapAchievement),
            capacity: mapAchievementCapacity(dto.capacity)
        )
    }

    private func mapAchievement(_ dto: AchievementItemDTO) -> AchievementItem {
        AchievementItem(
            definitionId: dto.definitionId,
            key: dto.key,
            track: dto.track,
            tier: dto.tier,
            targetValue: dto.targetValue,
            currentValue: dto.currentValue,
            rawCurrentValue: dto.rawCurrentValue,
            progressStatus: dto.progressStatus,
            isUnlocked: dto.isUnlocked,
            memberAchievementId: dto.memberAchievementId,
            unlockedAt: dto.unlockedAt,
            visibility: AchievementVisibility(rawValue: dto.visibility) ?? .family,
            reward: dto.reward.map { AchievementReward(type: $0.type, value: $0.value) }
        )
    }

    private func mapAchievementCapacity(_ dto: AchievementCapacityDTO) -> AchievementCapacity {
        AchievementCapacity(
            common: AchievementCapacityBucket(
                base: dto.common.base,
                earned: dto.common.earned,
                limit: dto.common.limit
            ),
            custom: AchievementCapacityBucket(
                base: dto.custom.base,
                earned: dto.custom.earned,
                limit: dto.custom.limit
            )
        )
    }

    private func mapMonthlyReport(_ dto: MonthlyReportDTO) -> MonthlyReport {
        MonthlyReport(
            month: dto.month,
            totalPoints: dto.totalPoints,
            totalRecords: dto.totalRecords,
            totalMinutes: dto.totalMinutes
                ?? dto.recentRecords.reduce(0) { $0 + ($1.actualMinutes ?? $1.minutes) },
            headline: dto.headline,
            comparison: dto.comparison.map {
                MonthlyReportComparison(
                    previousMonth: $0.previousMonth,
                    totalPoints: $0.totalPoints,
                    totalRecords: $0.totalRecords,
                    totalMinutes: $0.totalMinutes
                )
            },
            monthlyTrend: (dto.monthlyTrend ?? []).map {
                MonthlyReportMonth(
                    month: $0.month,
                    points: $0.points,
                    recordCount: $0.recordCount,
                    totalMinutes: $0.totalMinutes
                )
            },
            weeklyTrend: (dto.weeklyTrend ?? []).map {
                MonthlyReportWeek(
                    weekStart: $0.weekStart,
                    weekEnd: $0.weekEnd,
                    label: $0.label,
                    points: $0.points,
                    recordCount: $0.recordCount,
                    totalMinutes: $0.totalMinutes
                )
            },
            memberContributions: (dto.memberContributions ?? dto.leaderboard.map {
                MonthlyReportMemberContributionDTO(
                    userId: $0.userId,
                    displayName: $0.displayName,
                    points: $0.points,
                    recordCount: $0.recordCount,
                    totalMinutes: 0
                )
            }).map {
                MonthlyMemberContribution(
                    userId: $0.userId,
                    displayName: $0.displayName,
                    points: $0.points,
                    recordCount: $0.recordCount,
                    totalMinutes: $0.totalMinutes
                )
            },
            themeStats: (dto.themeStats ?? []).map {
                MonthlyReportTheme(
                    themeKey: $0.themeKey,
                    points: $0.points,
                    recordCount: $0.recordCount
                )
            },
            categoryStats: dto.categoryStats.map {
                MonthlyReportCategory(
                    category: ChoreCategory.resolve($0.category).rawValue,
                    points: $0.points,
                    recordCount: $0.recordCount,
                    memberContributions: ($0.memberContributions ?? []).map {
                        MonthlyMemberContribution(
                            userId: $0.userId,
                            displayName: $0.displayName,
                            points: $0.points,
                            recordCount: $0.recordCount,
                            totalMinutes: $0.totalMinutes
                        )
                    }
                )
            }
        )
    }

    private func monthlyContributions(for records: [ChoreRecord]) -> [MonthlyMemberContribution] {
        Dictionary(grouping: records) { record in
            record.creatorId ?? record.memberName
        }
        .map { userId, memberRecords in
            MonthlyMemberContribution(
                userId: userId,
                displayName: memberRecords.first?.memberName ?? "家庭成员",
                points: memberRecords.reduce(0) { $0 + $1.points },
                recordCount: memberRecords.count,
                totalMinutes: memberRecords.reduce(0) { $0 + $1.actualMinutes }
            )
        }
        .sorted { $0.points > $1.points }
    }

    private func mapLikers(_ users: [RecordUserDTO]?) -> [ActivityLiker] {
        (users ?? []).map { user in
            ActivityLiker(
                id: user.id,
                displayName: user.displayName,
                avatarKey: user.avatarKey,
                reaction: user.reactionKey.flatMap(ChoreReaction.init(rawValue:)) ?? .like
            )
        }
    }

    private func mapReactionCounts(_ counts: [String: Int]?) -> [ChoreReaction: Int] {
        (counts ?? [:]).reduce(into: [:]) { result, item in
            guard let reaction = ChoreReaction(rawValue: item.key) else { return }
            result[reaction] = item.value
        }
    }

    private static func icon(forName name: String, category: String) -> String {
        switch name {
        case "做饭", "做饭备餐", "做饭 / 备餐":
            return "flame.fill"
        case "洗碗", "洗碗收桌", "饭后收拾 / 洗碗":
            return "fork.knife"
        case "洗衣服":
            return "washer.fill"
        case "晾衣服":
            return "wind"
        case "叠衣服", "收叠衣物", "收衣 / 叠衣", "收衣 / 叠衣 / 放回衣柜":
            return "square.stack.3d.up.fill"
        case "扫地", "扫地吸尘", "扫地 / 吸尘":
            return "sparkles"
        case "拖地", "拖地清洁", "拖地 / 地面湿清洁":
            return "drop.fill"
        case "整理收纳":
            return "shippingbox.fill"
        case "清理卫生间", "卫生间清洁":
            return "shower.fill"
        case "倒垃圾", "倒垃圾 / 垃圾分类":
            return "trash.fill"
        case "采购补货", "采购补货 / 家庭物资管理":
            return "cart.fill"
        case "换床单":
            return "bed.double.fill"
        case "清理灶台":
            return "flame.fill"
        case "搬重物":
            return "shippingbox.fill"
        case "遛狗", "清理猫砂":
            return "pawprint.fill"
        case "陪写作业", "陪孩子写作业":
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
        switch ChoreCategory.resolve(category) {
        case .cooking: return DSColor.yellow
        case .cleaning: return DSColor.sky
        case .laundryCare: return DSColor.mint
        case .organizing: return DSColor.lavender
        case .caregiving: return DSColor.coral
        case .household: return DSColor.clay
        }
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
    private static let commonChoreGridDefaultsKeyPrefix = "common-chore-grid-order-v1"
    private static let achievementCacheKeyPrefix = "achievement-cache-v1"
    private static let pendingRecordUploadsDefaultsKey = "pending-chore-record-uploads-v1"
    private static let hasAuthenticatedBeforeDefaultsKey = "has-authenticated-before-v1"
    private static let customChoreSlotPrefix = "custom-chore-slot-"
    private static let mockPremiumRedemptionCode = "241255"

    private static func customChoreSlotID(_ slot: Int) -> String {
        "\(customChoreSlotPrefix)\(slot)"
    }

    private static func premiumAccessKey(for userId: String) -> String {
        "test-premium-access-\(userId)"
    }

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

    private static let monthDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    private static let weekDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = weekCalendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    private static let weekCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }()

    static func previewLoggedIn(userDefaults: UserDefaults = .standard) -> AppViewModel {
        let viewModel = AppViewModel(forceMockData: true, userDefaults: userDefaults)
        viewModel.currentUser = MockData.currentUser
        viewModel.currentFamily = MockData.family
        viewModel.currentMembership = MockData.currentMembership
        viewModel.familyMembers = MockData.familyMemberProfiles
        viewModel.joinRequests = MockData.joinRequests
        viewModel.accessToken = "mock-token"
        viewModel.loadMockMonthlyReport(for: viewModel.selectedReportMonth)
        return viewModel
    }

    static func previewHomeAfterNewRecord() -> AppViewModel {
        let viewModel = previewLoggedIn()
        viewModel.recordWithMock(MockData.chores[1])
        return viewModel
    }

    static func previewJoinStatus(_ status: FamilyMemberStatus) -> AppViewModel {
        let viewModel = previewLoggedIn()
        let source = MockData.pendingJoinApplication
        viewModel.currentFamily = nil
        viewModel.currentMembership = nil
        viewModel.currentJoinApplication = JoinApplication(
            id: source.id,
            userId: source.userId,
            identityLabel: source.identityLabel,
            customIdentity: source.customIdentity,
            avatarKey: source.avatarKey,
            status: status,
            createdAt: source.createdAt,
            family: source.family
        )
        viewModel.rootScreen = .joinStatus
        return viewModel
    }
}

private enum AppStateError: LocalizedError {
    case missingUser
    case missingFamily
    case missingFamilyIdentifier
    case missingJoinApplication
    case missingCustomIdentity
    case ownerRequired
    case deleteForbidden
    case secureSessionStorageFailed

    var errorDescription: String? {
        switch self {
        case .missingUser:
            return "当前登录用户不存在，请重新登录。"
        case .missingFamily:
            return "还没有当前家庭，请先创建家庭"
        case .missingFamilyIdentifier:
            return "请输入家庭邀请码。"
        case .missingJoinApplication:
            return "没有找到当前加入申请，请重新提交。"
        case .missingCustomIdentity:
            return "选择自定义身份后，请填写身份名称"
        case .ownerRequired:
            return "只有一家之主可以执行这个家庭管理操作"
        case .deleteForbidden:
            return "你没有权限删除这条家务记录"
        case .secureSessionStorageFailed:
            return "无法安全保存登录状态，请重新打开 App 后再试。"
        }
    }
}
