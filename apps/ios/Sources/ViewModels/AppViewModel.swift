import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var rootScreen: AppScreen = .login
    @Published var selectedTab: MainTab = .today
    @Published var phoneNumber = ""
    @Published var familyName = MockData.family.name
    @Published var requiresPhotoProof = false
    @Published private(set) var accessToken: String?
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var currentFamily: FamilySpace?
    @Published private(set) var chores = MockData.chores
    @Published private(set) var choreOrder: [String] = []
    @Published private(set) var pinnedChoreIDs: Set<String> = []
    @Published private(set) var todayRecords = MockData.todayRecords
    @Published private(set) var monthlyRanking = MockData.members
    @Published private(set) var monthlyReport: MonthlyReport? = MockData.monthlyReport
    @Published private(set) var isLoading = false
    @Published private(set) var loadingMessage: String?
    @Published var errorMessage: String?
    @Published private(set) var lastRequestPath: String?
    @Published private(set) var lastStatusCode: Int?
    @Published private(set) var lastAPIErrorMessage: String?
    @Published var selectedChore: ChoreItem?

    private let apiClient: APIClient
    private let forceMockData: Bool

    init(apiClient: APIClient = APIClient(), forceMockData: Bool = false) {
        self.apiClient = apiClient
        self.forceMockData = forceMockData

        if !forceMockData {
            choreOrder = UserDefaults.standard.stringArray(forKey: Self.choreOrderDefaultsKey) ?? []
            pinnedChoreIDs = Set(UserDefaults.standard.stringArray(forKey: Self.pinnedChoresDefaultsKey) ?? [])
        }

        synchronizeChoreLayout()
    }

    var familyDisplayName: String {
        currentFamily?.name ?? familyName
    }

    var currentUserName: String {
        currentUser?.displayName ?? MockData.currentUser.displayName
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

    var hasAccessToken: Bool {
        !(accessToken?.isEmpty ?? true)
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

        guard !usesMockData else {
            loginWithMock()
            return
        }

        Task {
            await loginWithAPI()
        }
    }

    func createFamily() {
        clearError()

        guard !usesMockData else {
            createFamilyWithMock()
            return
        }

        Task {
            await createFamilyWithAPI()
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

    func logout() {
        accessToken = nil
        currentUser = nil
        currentFamily = nil
        selectedChore = nil
        selectedTab = .today
        phoneNumber = ""
        familyName = MockData.family.name
        todayRecords = usesMockData ? MockData.todayRecords : []
        monthlyRanking = usesMockData ? MockData.members : []
        monthlyReport = usesMockData ? MockData.monthlyReport : nil
        rootScreen = .login
        clearError()

        Task {
            await apiClient.setAccessToken(nil)
        }
    }

    private var usesMockData: Bool {
        forceMockData || APIConfig.useMockData
    }

    private func loginWithMock() {
        accessToken = "mock-token"
        currentUser = MockData.currentUser
        currentFamily = nil
        replaceChores(MockData.chores)
        todayRecords = MockData.todayRecords
        monthlyRanking = MockData.members
        monthlyReport = MockData.monthlyReport
        rootScreen = .createFamily
    }

    private func createFamilyWithMock() {
        currentFamily = FamilySpace(
            id: MockData.family.id,
            name: trimmedFamilyName,
            inviteCode: MockData.family.inviteCode,
            requiresPhotoProof: requiresPhotoProof
        )
        selectedTab = .today
        rootScreen = .home
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
            color: chore.color
        )

        todayRecords.insert(record, at: 0)
        addMonthlyPoints(points, to: currentUserName)
        monthlyReport = MonthlyReport(
            month: currentMonth,
            totalPoints: monthlyRanking.reduce(0) { $0 + $1.monthlyPoints },
            totalRecords: todayRecords.count,
            headline: "今天又有一笔家务被记上功劳簿"
        )
        selectedTab = .today
        rootScreen = .home
    }

    private func loginWithAPI() async {
        await performLoading("正在连接本地后端") {
            let displayName = loginDisplayName
            let response: LoginResponse = try await apiClient.post(
                "auth/mock-login",
                body: MockLoginRequest(displayName: displayName)
            )

            accessToken = response.accessToken
            currentUser = mapUser(response.user)
            await apiClient.setAccessToken(response.accessToken)
            try await loadChoresFromAPI()
            _ = try await loadMyFamiliesFromAPI()
            rootScreen = .createFamily
        }
    }

    private func createFamilyWithAPI() async {
        await performLoading("正在创建家庭空间") {
            let family: FamilyDTO = try await apiClient.post(
                "families",
                body: CreateFamilyRequest(name: trimmedFamilyName, requirePhotoProof: requiresPhotoProof)
            )

            currentFamily = mapFamily(family)
            _ = try await loadMyFamiliesFromAPI(preferredFamilyId: family.id)
            selectedTab = .today
            rootScreen = .home
            try await refreshHomeDataFromAPI()
        }
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

        UserDefaults.standard.set(choreOrder, forKey: Self.choreOrderDefaultsKey)
        UserDefaults.standard.set(Array(pinnedChoreIDs), forKey: Self.pinnedChoresDefaultsKey)
    }

    @discardableResult
    private func loadMyFamiliesFromAPI(preferredFamilyId: String? = nil) async throws -> [FamilyDTO] {
        let families: [FamilyDTO] = try await apiClient.get("families/me")

        if let preferredFamilyId, let family = families.first(where: { $0.id == preferredFamilyId }) {
            currentFamily = mapFamily(family)
        } else if currentFamily == nil, let family = families.first {
            currentFamily = mapFamily(family)
            familyName = family.name
            requiresPhotoProof = family.requirePhotoProof
        }

        return families
    }

    private func refreshHomeDataFromAPI() async throws {
        guard let familyId = currentFamily?.id else {
            return
        }

        try await loadChoresFromAPI()

        async let activity: [ActivityItemDTO] = apiClient.get("families/\(familyId)/activity")
        async let leaderboard: [LeaderboardItemDTO] = apiClient.get(
            "families/\(familyId)/leaderboard",
            queryItems: [URLQueryItem(name: "range", value: "month")]
        )
        async let report: MonthlyReportDTO = apiClient.get(
            "families/\(familyId)/monthly-report",
            queryItems: [URLQueryItem(name: "month", value: currentMonth)]
        )

        let (activityItems, leaderboardItems, monthlyReportDTO) = try await (activity, leaderboard, report)

        todayRecords = activityItems.map(mapActivity)
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

    private func performLoading(_ message: String, operation: () async throws -> Void) async {
        isLoading = true
        loadingMessage = message
        errorMessage = nil

        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }

        await syncAPIDebugSnapshot()

        isLoading = false
        loadingMessage = nil
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

    private var loginDisplayName: String {
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhone.isEmpty else {
            return "iOS联调用户"
        }

        return "用户\(trimmedPhone.suffix(4))"
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

    private func mapFamily(_ dto: FamilyDTO) -> FamilySpace {
        FamilySpace(
            id: dto.id,
            name: dto.name,
            inviteCode: dto.inviteCode,
            requiresPhotoProof: dto.requirePhotoProof
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
        ChoreRecord(
            id: dto.id,
            memberName: dto.user.displayName,
            choreName: dto.chore.name,
            category: dto.chore.category,
            standardMinutes: dto.minutes,
            actualMinutes: dto.actualMinutes ?? dto.minutes,
            points: dto.points,
            note: dto.note ?? "",
            createdAt: dto.createdAt,
            icon: dto.chore.icon ?? Self.icon(forName: dto.chore.name, category: dto.chore.category),
            color: Self.color(forCategory: dto.chore.category)
        )
    }

    private func mapActivity(_ dto: ActivityItemDTO) -> ChoreRecord {
        ChoreRecord(
            id: dto.id,
            memberName: dto.user.displayName,
            choreName: dto.chore.name,
            category: dto.chore.category,
            standardMinutes: dto.minutes,
            actualMinutes: dto.actualMinutes ?? dto.minutes,
            points: dto.points,
            note: dto.note ?? "",
            createdAt: dto.createdAt,
            icon: dto.chore.icon ?? Self.icon(forName: dto.chore.name, category: dto.chore.category),
            color: Self.color(forCategory: dto.chore.category)
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

    private static func icon(forName name: String, category: String) -> String {
        switch name {
        case "做饭 / 备餐":
            return "flame.fill"
        case "饭后收拾 / 洗碗":
            return "fork.knife"
        case "洗衣服":
            return "washer.fill"
        case "收衣 / 叠衣 / 放回衣柜":
            return "square.stack.3d.up.fill"
        case "扫地 / 吸尘":
            return "sparkles"
        case "拖地 / 地面湿清洁":
            return "drop.fill"
        case "整理收纳":
            return "shippingbox.fill"
        case "卫生间清洁":
            return "shower.fill"
        case "倒垃圾 / 垃圾分类":
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
    case missingFamily

    var errorDescription: String? {
        switch self {
        case .missingFamily:
            return "还没有当前家庭，请先创建家庭"
        }
    }
}
