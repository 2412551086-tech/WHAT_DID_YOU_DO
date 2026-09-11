import Foundation
import SwiftUI

struct AppUser: Identifiable, Hashable {
    let id: String
    let displayName: String
    let avatarInitial: String
    let badge: String
}

struct FamilySpace: Identifiable, Hashable {
    let id: String
    let name: String
    let inviteCode: String
    let requiresPhotoProof: Bool
    let timezone: String?
}

struct FamilyMember: Identifiable, Hashable {
    let id: String
    let name: String
    var monthlyPoints: Int
    let badge: String
    let color: Color
}

enum FamilyMemberRole: String, Hashable {
    case owner = "OWNER"
    case member = "MEMBER"
}

enum FamilyMemberStatus: String, Hashable {
    case pending = "PENDING"
    case active = "ACTIVE"
    case rejected = "REJECTED"
}

struct FamilyMembership: Identifiable, Hashable {
    let id: String
    let userId: String
    let familyId: String
    let identityLabel: String
    let customIdentity: String?
    let avatarKey: String?
    let memberRole: FamilyMemberRole
    let status: FamilyMemberStatus

    var displayIdentity: String {
        identityLabel == "自定义" ? (customIdentity ?? identityLabel) : identityLabel
    }
}

struct FamilyMemberProfile: Identifiable, Hashable {
    let id: String
    let userId: String
    let name: String
    let identityLabel: String
    let customIdentity: String?
    let avatarKey: String?
    let memberRole: FamilyMemberRole
    let status: FamilyMemberStatus
    let joinedAt: Date

    var displayIdentity: String {
        identityLabel == "自定义" ? (customIdentity ?? identityLabel) : identityLabel
    }
}

struct JoinRequestItem: Identifiable, Hashable {
    let id: String
    let userId: String
    let displayName: String
    let identityLabel: String
    let customIdentity: String?
    let avatarKey: String?
    let status: FamilyMemberStatus
    let createdAt: Date

    var displayIdentity: String {
        identityLabel == "自定义" ? (customIdentity ?? identityLabel) : identityLabel
    }
}

struct FamilyInviteOwner: Hashable {
    let id: String
    let displayName: String
    let identityLabel: String
    let customIdentity: String?
    let avatarKey: String?

    var displayIdentity: String {
        identityLabel == "自定义" ? (customIdentity ?? identityLabel) : identityLabel
    }
}

struct FamilyInvitePreview: Identifiable, Hashable {
    let id: String
    let name: String
    let inviteCode: String
    let memberCount: Int
    let owner: FamilyInviteOwner?
    let currentStatus: FamilyMemberStatus?
}

struct JoinApplication: Identifiable, Hashable {
    let id: String
    let userId: String
    let identityLabel: String
    let customIdentity: String?
    let avatarKey: String?
    let status: FamilyMemberStatus
    let createdAt: Date
    let family: FamilyInvitePreview

    var displayIdentity: String {
        identityLabel == "自定义" ? (customIdentity ?? identityLabel) : identityLabel
    }
}

enum InviteValidationState: Equatable {
    case idle
    case validating
    case valid(FamilyInvitePreview)
    case invalid(String)
}

enum DistributionRegion: String, Codable, CaseIterable {
    case cn = "CN"
    case global = "GLOBAL"

    static var configured: DistributionRegion {
        let value = Bundle.main.object(forInfoDictionaryKey: "WDDDistributionRegion") as? String
        return DistributionRegion(rawValue: value?.uppercased() ?? "") ?? .cn
    }

    var providers: [ClientAuthProvider] {
        switch self {
        case .cn: [.apple, .wechat, .email]
        case .global: [.apple, .google, .email]
        }
    }
}

enum ClientAuthProvider: String, Codable, Identifiable {
    case apple = "APPLE"
    case wechat = "WECHAT"
    case email = "EMAIL"
    case google = "GOOGLE"

    var id: String { rawValue }
}

enum PendingAuthAction: Hashable {
    case claimLocalDraft
    case joinFamily(inviteCode: String)
    case enableCloudSync
    case inviteMembers
}

enum ChoreTheme: String, CaseIterable, Hashable, Identifiable {
    case daily
    case love
    case childcare
    case pet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "家庭"
        case .love: "恋爱"
        case .childcare: "育儿"
        case .pet: "宠物"
        }
    }

    var systemImage: String {
        switch self {
        case .daily: "house.fill"
        case .love: "heart.fill"
        case .childcare: "figure.and.child.holdinghands"
        case .pet: "pawprint.fill"
        }
    }
}

enum RotatingCopy {
    static let login = [
        "家务不会自己消失，但功劳可以自动留下。",
        "谁做了什么，这次终于有账可查。",
        "不催家务，只负责让每份付出被看见。",
        "做都做了，顺手把功劳领走吧。"
    ]

    static let homeEmpty = [
        "本周还没人记功，首发位置等你。",
        "功劳簿还是空白，等一位行动派。",
        "战局尚未开启，先做的人先上榜。",
        "家里很安静，积分也很安静。",
        "第一笔家务，等你来打响。"
    ]

    static let choreSelection = [
        "刚忙完什么？趁热把功劳记上。",
        "做都做了，别让积分跑掉。",
        "选一项，把这份付出写进功劳簿。",
        "家务结束，领奖环节开始。",
        "默默做事很好，顺手记功更好。"
    ]

    static let recordSuccess = [
        "家庭战报更新，功劳已入账。",
        "干得漂亮，这次付出没有隐身。",
        "功劳簿喜提新记录。",
        "已收录，家里又被守护了一次。"
    ]

    static let monthlyEmpty = [
        "本月战局待开启，第一笔功劳等你登场。",
        "功劳簿刚翻到新的一页。",
        "本月暂时风平浪静，积分还没开张。",
        "排行榜正在等它的第一位选手。"
    ]

    static func value(from values: [String], seed: Int) -> String {
        guard !values.isEmpty else { return "" }
        return values[abs(seed) % values.count]
    }
}

struct ChoreItem: Identifiable, Hashable {
    let id: String
    var catalogKey: String? = nil
    let name: String
    let category: String
    let minutes: Int
    let points: Int
    let icon: String
    let color: Color
    var themeKey = ChoreTheme.daily.rawValue
    var difficultyMultiplier = 1.0
    var suggestedFrequency: String?
    var isCustom = false
    var customSlot: Int?
    var isLocked = false
    var requiredPlan = "free"
}

enum ChoreCategory: String, CaseIterable, Codable, Hashable, Identifiable {
    case cooking = "烹饪"
    case cleaning = "清洁"
    case laundryCare = "洗护"
    case organizing = "整理"
    case caregiving = "照顾"
    case household = "家庭事务"

    var id: String { rawValue }

    static func resolve(_ value: String, choreName: String = "") -> ChoreCategory {
        if value.contains("烹饪") {
            return .cooking
        }
        if value.contains("清洁") || value == "卫生间" || value == "日常杂务" {
            return .cleaning
        }
        if value.contains("洗护") || value == "衣物整理" {
            return .laundryCare
        }
        if value.contains("整理") || value.contains("收纳") {
            return .organizing
        }
        if value.contains("照顾") || value.contains("宠物") {
            return .caregiving
        }
        if value.contains("家庭事务") || value.contains("采购") || value.contains("管理") {
            return .household
        }
        if value.contains("厨房") {
            return choreName.contains("做饭") || choreName.contains("备餐") ? .cooking : .cleaning
        }
        return .household
    }
}

struct CustomChoreIconOption: Identifiable, Hashable {
    let id: String
    let accessibilityLabel: String
    let color: Color
}

struct CustomChoreDraft: Hashable {
    var name: String
    var iconKey: String
    var category: ChoreCategory
    var standardMinutes: Int
    var difficultyMultiplier: Double

    var defaultPoints: Int {
        max(1, Int((Double(standardMinutes) * difficultyMultiplier).rounded()))
    }

    init(
        name: String,
        iconKey: String,
        category: ChoreCategory? = nil,
        standardMinutes: Int,
        difficultyMultiplier: Double
    ) {
        self.name = name
        self.iconKey = iconKey
        self.category = category ?? .household
        self.standardMinutes = standardMinutes
        self.difficultyMultiplier = difficultyMultiplier
    }

    init(option: CustomChoreIconOption = CustomChoreCatalog.options[0]) {
        name = ""
        iconKey = option.id
        category = .household
        standardMinutes = 15
        difficultyMultiplier = 1
    }

    init(chore: ChoreItem) {
        name = chore.name
        iconKey = chore.icon
        category = ChoreCategory.resolve(chore.category, choreName: chore.name)
        standardMinutes = chore.minutes
        difficultyMultiplier = chore.difficultyMultiplier
    }
}

enum CustomChoreCatalog {
    static let options: [CustomChoreIconOption] = [
        .init(id: "chore_custom_generic_01", accessibilityLabel: "通用图标一", color: DSColor.yellow),
        .init(id: "chore_custom_generic_02", accessibilityLabel: "通用图标二", color: DSColor.sky),
        .init(id: "chore_custom_generic_03", accessibilityLabel: "通用图标三", color: DSColor.mint),
        .init(id: "chore_custom_generic_04", accessibilityLabel: "通用图标四", color: DSColor.lavender),
    ]

    static func option(for iconKey: String) -> CustomChoreIconOption? {
        options.first { $0.id == iconKey }
    }
}

enum ChoreReaction: String, CaseIterable, Codable, Identifiable, Hashable {
    case like
    case doubt
    case highFive = "high_five"
    case moonFace = "moon_face"
    case laughCry = "laugh_cry"
    case tease

    var id: String { rawValue }

    var title: String {
        switch self {
        case .like: "点赞"
        case .doubt: "质疑"
        case .highFive: "击掌"
        case .moonFace: "黑脸"
        case .laughCry: "笑哭"
        case .tease: "调侃"
        }
    }
}

struct ReactionConsensus: Codable, Hashable {
    let eligibleMemberCount: Int
    let requiredCount: Int
    let likeCount: Int
    let doubtCount: Int
    let status: String

    init(
        eligibleMemberCount: Int,
        requiredCount: Int,
        likeCount: Int,
        doubtCount: Int,
        status: String
    ) {
        self.eligibleMemberCount = eligibleMemberCount
        self.requiredCount = requiredCount
        self.likeCount = likeCount
        self.doubtCount = doubtCount
        self.status = status
    }

    static func evaluate(
        eligibleMemberIDs: Set<String>,
        reactions: [ActivityLiker]
    ) -> Self {
        let requiredCount = eligibleMemberIDs.isEmpty ? 1 : (eligibleMemberIDs.count / 2) + 1
        var uniqueEligibleReactions: [String: ChoreReaction] = [:]

        for reaction in reactions where eligibleMemberIDs.contains(reaction.id) {
            uniqueEligibleReactions[reaction.id] = reaction.reaction
        }

        let likeCount = uniqueEligibleReactions.values.filter { $0 == .like }.count
        let doubtCount = uniqueEligibleReactions.values.filter { $0 == .doubt }.count
        let status: String
        if likeCount >= requiredCount {
            status = "appreciated"
        } else if doubtCount >= requiredCount {
            status = "questioned"
        } else {
            status = "none"
        }

        return Self(
            eligibleMemberCount: eligibleMemberIDs.count,
            requiredCount: requiredCount,
            likeCount: likeCount,
            doubtCount: doubtCount,
            status: status
        )
    }
}

struct ActivityLiker: Identifiable, Hashable {
    let id: String
    let displayName: String
    let avatarKey: String?
    let reaction: ChoreReaction

    init(
        id: String,
        displayName: String,
        avatarKey: String?,
        reaction: ChoreReaction = .like
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarKey = avatarKey
        self.reaction = reaction
    }
}

struct ChoreRecord: Identifiable, Hashable {
    let id: String
    let memberName: String
    let choreName: String
    let category: String
    let standardMinutes: Int
    var actualMinutes: Int
    var points: Int
    let note: String
    let createdAt: Date
    let icon: String
    let color: Color
    let creatorId: String?
    let identityLabel: String
    let customIdentity: String?
    var avatarKey: String?
    var likeCount: Int = 0
    var likedBy: [ActivityLiker] = []
    var likedByMe: Bool = false
    var reactionCounts: [ChoreReaction: Int] = [:]
    var myReaction: ChoreReaction? = nil
    var reactionConsensus: ReactionConsensus? = nil
    var canDelete: Bool = false
    var canEdit: Bool = false
    var choreId: String? = nil
    var defaultPoints: Int? = nil
    var pointsMultiplier: Double? = nil
    var syncState: ChoreRecordSyncState = .synced

    var displayIdentity: String {
        identityLabel == "自定义" ? (customIdentity ?? identityLabel) : identityLabel
    }

    func updating(actualMinutes: Int, points: Int, pointsMultiplier: Double?) -> ChoreRecord {
        var copy = self
        copy.actualMinutes = actualMinutes
        copy.points = points
        copy.pointsMultiplier = pointsMultiplier
        return copy
    }

    func updatingAvatar(for userId: String, avatarKey: String) -> ChoreRecord {
        var copy = self
        if creatorId == userId {
            copy.avatarKey = avatarKey
        }
        copy.likedBy = likedBy.map { liker in
            guard liker.id == userId else { return liker }
            return ActivityLiker(
                id: liker.id,
                displayName: liker.displayName,
                avatarKey: avatarKey,
                reaction: liker.reaction
            )
        }
        return copy
    }
}

enum ChoreRecordSyncState: String, Codable, Hashable {
    case synced
    case pending
    case failed
}

struct PendingRecordDeletion: Identifiable, Hashable {
    var id: String { record.id }
    let record: ChoreRecord
    let expiresAt: Date

    var isExpired: Bool {
        expiresAt <= Date()
    }
}

struct MonthlyReport: Hashable {
    let month: String
    let totalPoints: Int
    let totalRecords: Int
    let totalMinutes: Int
    let headline: String
    let comparison: MonthlyReportComparison?
    let monthlyTrend: [MonthlyReportMonth]
    let weeklyTrend: [MonthlyReportWeek]
    let memberContributions: [MonthlyMemberContribution]
    let themeStats: [MonthlyReportTheme]
    let categoryStats: [MonthlyReportCategory]
}

struct MonthlyReportMonth: Identifiable, Hashable {
    let month: String
    let points: Int
    let recordCount: Int
    let totalMinutes: Int

    var id: String { month }
}

struct MonthlyReportComparison: Hashable {
    let previousMonth: String
    let totalPoints: Int
    let totalRecords: Int
    let totalMinutes: Int
}

struct MonthlyReportWeek: Identifiable, Hashable {
    let weekStart: String
    let weekEnd: String
    let label: String
    let points: Int
    let recordCount: Int
    let totalMinutes: Int

    var id: String { weekStart }
}

struct MonthlyMemberContribution: Identifiable, Hashable {
    let userId: String
    let displayName: String
    let points: Int
    let recordCount: Int
    let totalMinutes: Int

    var id: String { userId }
}

struct MonthlyReportTheme: Identifiable, Hashable {
    let themeKey: String
    let points: Int
    let recordCount: Int

    var id: String { themeKey }
}

struct MonthlyReportCategory: Hashable {
    let category: String
    let points: Int
    let recordCount: Int
    let memberContributions: [MonthlyMemberContribution]

    init(
        category: String,
        points: Int,
        recordCount: Int,
        memberContributions: [MonthlyMemberContribution] = []
    ) {
        self.category = category
        self.points = points
        self.recordCount = recordCount
        self.memberContributions = memberContributions
    }
}

enum AchievementVisibility: String, Codable, CaseIterable, Hashable {
    case family = "FAMILY"
    case privateOnly = "PRIVATE"

    var title: String {
        switch self {
        case .family: "家人可见"
        case .privateOnly: "仅自己可见"
        }
    }
}

enum AchievementDataState: Equatable {
    case idle
    case loading
    case loaded
    case cached
    case failed(String)
}

enum AchievementSyncState: Equatable {
    case idle
    case pending
    case failed
}

struct AchievementReward: Codable, Hashable {
    let type: String
    let value: Int

    var displayText: String {
        switch type {
        case "COMMON_CHORE_SLOT": "+\(value) 个常用家务位"
        case "CUSTOM_CHORE_SLOT": "+\(value) 个自定义家务位"
        default: "家庭奖励 +\(value)"
        }
    }
}

struct AchievementCapacityBucket: Codable, Hashable {
    let base: Int
    let earned: Int
    let limit: Int?
}

struct AchievementCapacity: Codable, Hashable {
    let common: AchievementCapacityBucket
    let custom: AchievementCapacityBucket
}

struct AchievementItem: Identifiable, Codable, Hashable {
    let definitionId: String
    let key: String
    let track: String
    let tier: String
    let targetValue: Int
    let currentValue: Int
    let rawCurrentValue: Int
    let progressStatus: String
    let isUnlocked: Bool
    let memberAchievementId: String?
    let unlockedAt: Date?
    var visibility: AchievementVisibility
    let reward: AchievementReward?
    var ownerType: String? = nil
    var ownerKey: String? = nil
    var familyId: String? = nil
    var userId: String? = nil
    var relationshipId: String? = nil
    var familyAchievementId: String? = nil
    var pairAchievementId: String? = nil
    var participantUserIds: [String]? = nil
    var minimumMemberCount: Int? = nil
    var serverIsHidden: Bool? = nil

    var id: String { definitionId + ":" + seriesIdentity }

    var isHidden: Bool { serverIsHidden == true || key.hasPrefix("HIDDEN_") || track == "HIDDEN" }

    var seriesIdentity: String {
        let familyKeys: Set<String> = ["FAMILY_FORMED", "FAMILY_ALL_IN", "FAMILY_RELAY", "FAMILY_VISIBLE_4W", "FAMILY_FULL_SERVICE", "FAMILY_CATEGORY_COVERAGE", "FAMILY_ACTIVE_DAYS", "FAMILY_RECORD_COUNT", "FAMILY_ANNIVERSARY"]
        let scope = ownerType ?? (key == "PAIR_COOK_AND_CLEAN" ? "PAIR" : familyKeys.contains(key) ? "FAMILY" : "MEMBER")
        let identity: String
        if let ownerKey, !ownerKey.isEmpty {
            identity = ownerKey
        } else if scope == "PAIR" {
            if let relationshipId {
                identity = relationshipId
            } else if let participants = participantUserIds, Set(participants).count == 2 {
                identity = Self.identityComponents([familyId ?? "legacy-family"] + participants.sorted())
            } else {
                // A tier's unlock ID is not a relationship ID. Never merge unknown pairs.
                identity = pairAchievementId ?? memberAchievementId ?? definitionId
            }
        } else {
            identity = Self.identityComponents([familyId ?? "legacy-family", scope == "MEMBER" ? userId ?? "legacy-self" : ""])
        }
        return Self.identityComponents([key, scope, identity])
    }

    private static func identityComponents(_ values: [String]) -> String {
        values.map { "\($0.utf8.count):\($0)" }.joined()
    }

    var clampedProgress: Double {
        guard targetValue > 0 else { return isUnlocked ? 1 : 0 }
        return min(1, max(0, Double(currentValue) / Double(targetValue)))
    }

    var displayCurrentValue: Int {
        min(max(0, currentValue), max(0, targetValue))
    }

    var name: String { isHidden && !isUnlocked ? "未发现" : AchievementCopy.name(for: key, tier: tier) }
    var description: String { isHidden && !isUnlocked ? "" : AchievementCopy.description(for: key, tier: tier) }
    var unlockCopy: String { isHidden && !isUnlocked ? "" : AchievementCopy.unlockCopy(for: key, tier: tier) }
    var systemImage: String { AchievementCopy.systemImage(for: key) }
    var artworkAssetName: String? { AchievementCopy.artworkAssetName(for: key) }
}

struct AchievementSummary: Codable, Hashable {
    let familyId: String
    let userId: String
    var showAchievementsToFamily: Bool
    let unlockedCount: Int
    let totalCount: Int
    let nextAchievement: AchievementItem?
    let recentUnlocks: [AchievementItem]
    let capacity: AchievementCapacity
}

struct AchievementCollection: Codable, Hashable {
    let familyId: String
    let userId: String
    var showAchievementsToFamily: Bool
    var achievements: [AchievementItem]
    let capacity: AchievementCapacity
    let updatedAt: Date
    var undiscoveredHiddenCount: Int? = nil
}

struct AchievementSeries: Identifiable, Hashable {
    let id: String
    let levels: [AchievementItem]

    var highestUnlocked: AchievementItem? { levels.last(where: \.isUnlocked) }
    var nextLevel: AchievementItem? {
        let nextIndex = levels.lastIndex(where: \.isUnlocked).map { $0 + 1 } ?? 0
        return levels.dropFirst(nextIndex).first(where: { !$0.isUnlocked })
    }
    var main: AchievementItem { highestUnlocked ?? levels[0] }
    var name: String { AchievementCopy.name(for: main.key) }
    var isTiered: Bool { levels.contains { AchievementCopy.tierName($0.tier) != nil } }
    var collectedLevelCount: Int { levels.filter(\.isUnlocked).count }
    var statusText: String {
        if let next = nextLevel {
            let tier = AchievementCopy.tierName(next.tier) ?? "目标"
            let prefix = highestUnlocked.flatMap { AchievementCopy.tierName($0.tier) }.map { "\($0)已达成 · " } ?? ""
            return "\(prefix)\(tier) \(next.displayCurrentValue)/\(next.targetValue)"
        }
        if highestUnlocked?.tier == "GOLD" { return "系列已完成" }
        if let tier = highestUnlocked.flatMap({ AchievementCopy.tierName($0.tier) }) {
            return "\(tier)已达成"
        }
        return "已收藏"
    }

    static func grouped(_ items: [AchievementItem]) -> [AchievementSeries] {
        let visible = items.filter { !$0.isHidden || $0.isUnlocked }
        let grouped = Dictionary(grouping: visible, by: \.seriesIdentity)
        var seen = Set<String>()
        return visible.compactMap { item in
            guard seen.insert(item.seriesIdentity).inserted, let levels = grouped[item.seriesIdentity] else { return nil }
            let ordered = levels.sorted {
                let ranks = ["NONE": 0, "BRONZE": 1, "SILVER": 2, "GOLD": 3]
                let left = ranks[$0.tier] ?? 0, right = ranks[$1.tier] ?? 0
                return left == right ? $0.targetValue < $1.targetValue : left < right
            }
            return AchievementSeries(id: item.seriesIdentity, levels: ordered)
        }
    }
}

struct AchievementCelebration: Identifiable, Hashable {
    let id: String
    let achievements: [AchievementItem]
    let rewards: [AchievementReward]
}

struct AchievementCharacter: Identifiable, Codable, Hashable, Sendable {
    let key: String
    let achievementKey: String
    let requiredTier: String
    let achievementUnlocked: Bool
    let hasPremium: Bool
    let isOwned: Bool
    let canClaim: Bool
    let claimedAt: Date?

    var id: String { key }
}

struct CollectibleCharacter: Identifiable, Hashable {
    let key: String
    let name: String
    let achievementKey: String
    var id: String { key }

    static let all: [CollectibleCharacter] = [
        .init(key: "avatar_v2_recycler", name: "回收游侠", achievementKey: "MASTERY_TRASH"),
        .init(key: "avatar_v2_chef", name: "料理主理人", achievementKey: "MASTERY_COOKING"),
        .init(key: "avatar_v2_trainer", name: "宠物训练师", achievementKey: "MASTERY_PET"),
        .init(key: "avatar_v2_dad", name: "酷酷奶爸", achievementKey: "MASTERY_CHILDCARE")
    ]

    static func contains(_ key: String) -> Bool { all.contains { $0.key == key } }
}

struct AchievementCharacterCache: Codable {
    let userId: String
    let characters: [AchievementCharacter]
    let updatedAt: Date
}

struct AchievementCacheEnvelope: Codable, Hashable {
    let summary: AchievementSummary
    let collection: AchievementCollection
    let cachedAt: Date
}

enum AchievementCopy {
    static func artworkAssetName(for key: String) -> String? {
        switch key {
        case "FIRST_RECORD": "achievement_first_record"
        case "ACTIVE_DAYS_3": "achievement_active_days_3"
        case "ACTIVE_DAYS_5": "achievement_active_days_5"
        case "ACTIVE_DAYS_7": "achievement_active_days_7"
        case "STREAK_7": "achievement_streak_7"
        case "STREAK_14": "achievement_streak_14"
        case "HABIT_30": "achievement_habit_25_30"
        case "MASTERY_DISHES": "achievement_mastery_dishes"
        case "MASTERY_COOKING": "achievement_mastery_cooking"
        case "MASTERY_TRASH": "achievement_mastery_trash"
        case "MASTERY_PET": "achievement_mastery_pet"
        case "MASTERY_CHILDCARE": "achievement_mastery_childcare"
        case "MASTERY_FLOOR": "achievement_mastery_floor"
        case "MASTERY_LAUNDRY": "achievement_mastery_laundry"
        case "MASTERY_ROMANCE": "achievement_mastery_romance"
        case "MASTERY_ORGANIZE": "achievement_mastery_organize"
        case "MASTERY_ALL_ROUNDER": "achievement_mastery_all_rounder"
        case "REACTION_FIRST": "achievement_reaction_first"
        case "REACTION_GIVEN_20": "achievement_reaction_given_20"
        case "REACTION_RECEIVED_10": "achievement_reaction_received_10"
        case "FAMILY_FORMED": "achievement_family_formed"
        case "FAMILY_ALL_IN": "achievement_family_all_in"
        case "FAMILY_RELAY": "achievement_family_relay"
        case "FAMILY_VISIBLE_4W": "achievement_family_visible_4w"
        case "FAMILY_FULL_SERVICE": "achievement_family_full_service"
        case "FAMILY_CATEGORY_COVERAGE": "achievement_family_category_coverage"
        case "PAIR_COOK_AND_CLEAN": "achievement_pair_cook_and_clean"
        case "FAMILY_ACTIVE_DAYS": "achievement_family_visible_4w"
        case "FAMILY_RECORD_COUNT": "achievement_family_all_in"
        case "FAMILY_ANNIVERSARY": "achievement_family_formed"
        case "HIDDEN_DISHES_3": "achievement_mastery_dishes"
        case "HIDDEN_SHINY_FLOOR": "achievement_mastery_floor"
        case "HIDDEN_GUESTS": "achievement_mastery_all_rounder"
        case "HIDDEN_NIGHT_SHIFT": "achievement_streak_14"
        case "HIDDEN_ENDURANCE": "achievement_mastery_organize"
        default: nil
        }
    }

    static func name(for key: String, tier: String = "NONE") -> String {
        let baseName = switch key {
        case "FIRST_RECORD": "功劳簿开张"
        case "ACTIVE_DAYS_3": "三日有功"
        case "ACTIVE_DAYS_5": "五日渐入佳境"
        case "ACTIVE_DAYS_7": "七日守护者"
        case "STREAK_7": "一周不落"
        case "STREAK_14": "两周稳稳当当"
        case "HABIT_30": "家务已成习惯"
        case "MASTERY_DISHES": "洗碗战神"
        case "MASTERY_COOKING": "厨房永动机"
        case "MASTERY_TRASH": "垃圾终结者"
        case "MASTERY_PET": "宠物后勤部长"
        case "MASTERY_CHILDCARE": "育儿守护者"
        case "MASTERY_FLOOR": "地板反光负责人"
        case "MASTERY_LAUNDRY": "衣物轮回管理局"
        case "MASTERY_ROMANCE": "浪漫后勤部"
        case "MASTERY_ORGANIZE": "收纳秩序守护者"
        case "MASTERY_ALL_ROUNDER": "家务六边形"
        case "REACTION_FIRST": "夸夸群开张"
        case "REACTION_GIVEN_20": "气氛组组长"
        case "REACTION_RECEIVED_10": "你做我夸"
        case "FAMILY_FORMED": "家庭成立"
        case "FAMILY_ALL_IN": "全员出动"
        case "FAMILY_RELAY": "家庭接力赛"
        case "FAMILY_VISIBLE_4W": "无人隐身"
        case "FAMILY_FULL_SERVICE": "一条龙服务"
        case "FAMILY_CATEGORY_COVERAGE": "家务全图鉴"
        case "PAIR_COOK_AND_CLEAN": "一餐好搭档"
        case "FAMILY_ACTIVE_DAYS": "日子有了形状"
        case "FAMILY_RECORD_COUNT": "件件有回响"
        case "FAMILY_ANNIVERSARY": "一周年纪念"
        case "HIDDEN_DISHES_3": "水槽今天归你管"
        case "HIDDEN_SHINY_FLOOR": "地板可以照镜子了"
        case "HIDDEN_GUESTS": "家里今天像来客了"
        case "HIDDEN_NIGHT_SHIFT": "夜班守护者"
        case "HIDDEN_ENDURANCE": "耐力型选手"
        case "SCENE_PET_CARE": "小窝焕新日"
        case "SCENE_PET_TEAM": "今天我接班"
        case "SCENE_CHILDCARE_STORY": "陪伴后勤组"
        case "SCENE_CHILDCARE_TEAM": "换班辛苦了"
        case "SCENE_LOVE_MOMENT": "普通日子也庆祝"
        case "SCENE_LOVE_TEAM": "约会好搭档"
        case "HIDDEN_FRESH_START": "焕新的一天"
        case "HIDDEN_WARM_WELCOME": "温暖迎接"
        default: "家庭新成就"
        }
        guard let tierName = tierName(tier) else { return baseName }
        return "\(baseName) · \(tierName)"
    }

    static func description(for key: String, tier: String = "NONE") -> String {
        switch key {
        case "FIRST_RECORD": "记录第一笔家务，让付出正式留下名字。"
        case "ACTIVE_DAYS_3": "累计 3 个不同日期记录家务。"
        case "ACTIVE_DAYS_5": "累计 5 个不同日期记录家务。"
        case "ACTIVE_DAYS_7": "累计 7 个不同日期记录家务。"
        case "STREAK_7": "连续 7 天留下家务记录。"
        case "STREAK_14": "连续 14 天留下家务记录。"
        case "HABIT_30": "最近 30 天里，有 25 天记录家务。"
        case "MASTERY_DISHES": "有效完成洗碗收桌，单日最多计入 3 次。"
        case "MASTERY_COOKING": "有效完成烹饪家务，单日最多计入 3 次。"
        case "MASTERY_TRASH": "有效完成倒垃圾，单日最多计入 3 次。"
        case "MASTERY_PET": "在已启用的宠物主题中持续照料伙伴。"
        case "MASTERY_CHILDCARE": "在已启用的育儿主题中持续投入照护。"
        case "MASTERY_FLOOR": "有效完成扫地、吸尘或拖地。"
        case "MASTERY_LAUNDRY": "有效完成洗衣、叠衣或床品洗护。"
        case "MASTERY_ROMANCE": "把约会、礼物和陪伴也认真记进功劳簿。"
        case "MASTERY_ORGANIZE": "累计经过校验的整理收纳实际时长。"
        case "MASTERY_ALL_ROUNDER": "在同一个自然月覆盖更多标准家务类别。"
        case "REACTION_FIRST": "首次回应一位家庭成员的有效家务记录。"
        case "REACTION_GIVEN_20": "累计送出 20 次有效回应，每段关系每日最多计入 3 次。"
        case "REACTION_RECEIVED_10": "你的家务记录累计收到 10 次来自家人的有效回应。"
        case "FAMILY_FORMED": "家庭中首次同时拥有 2 位活跃成员。"
        case "FAMILY_ALL_IN": "同一周内，周期快照中的每位成员都留下家务记录。"
        case "FAMILY_RELAY": "同一天至少 3 位家庭成员各完成一项家务。"
        case "FAMILY_VISIBLE_4W": "连续 4 周，全体合格成员都没有隐身。"
        case "FAMILY_FULL_SERVICE": "同一天由至少 2 位成员共同覆盖烹饪、洗碗和地面清洁。"
        case "FAMILY_CATEGORY_COVERAGE": "同一个月，全家共同覆盖 8 个标准家务类别。"
        case "PAIR_COOK_AND_CLEAN": "同一天，一位成员做饭，另一位成员负责洗碗。"
        case "FAMILY_ACTIVE_DAYS": "累计更多有家务记录的家庭活跃日。"
        case "FAMILY_RECORD_COUNT": "累计更多未删除的有效家庭记录。"
        case "FAMILY_ANNIVERSARY": "家庭成立满 365 天，并且仍有成员和有效记录。"
        case "HIDDEN_DISHES_3": "同一天完成 3 次有效洗碗记录。"
        case "HIDDEN_SHINY_FLOOR": "同一天完成扫地和拖地。"
        case "HIDDEN_GUESTS": "同一天覆盖 5 个不同家务类别。"
        case "HIDDEN_NIGHT_SHIFT": "在家庭夜班时段完成一项照护。"
        case "HIDDEN_ENDURANCE": "单次家务的实际耗时达到 120 分钟。"
        case "SCENE_PET_CARE": "同一天完成目录家务「清理猫砂」与「宠物照料」，不计入自定义项。"
        case "SCENE_PET_TEAM": "同一天，你和另一位成员分别完成一项宠物主题家务。"
        case "SCENE_CHILDCARE_STORY": "同一天完成目录家务「陪伴孩子」与「准备辅食」，不计入自定义项。"
        case "SCENE_CHILDCARE_TEAM": "同一天，你和另一位成员分别完成一项育儿主题家务。"
        case "SCENE_LOVE_MOMENT": "同一天完成目录家务「约会策划」与「为你做饭」，不计入自定义项。"
        case "SCENE_LOVE_TEAM": "同一天，你与另一位成员分工完成目录家务「约会策划」和「为你做饭」，不计入自定义项。"
        case "HIDDEN_FRESH_START": "同一天完成换洗床品与洗衣。"
        case "HIDDEN_WARM_WELCOME": "同一天完成做饭备菜与整理收纳。"
        default: "继续记录，让每一份家庭劳动被看见。"
        }
    }

    static func unlockCopy(for key: String, tier: String = "NONE") -> String {
        switch key {
        case "FIRST_RECORD": "功劳簿第一页，已经写上你的名字。"
        case "ACTIVE_DAYS_3": "三天的付出，全都没有隐身。"
        case "ACTIVE_DAYS_5": "五日稳定发挥，家庭战线有你真稳。"
        case "ACTIVE_DAYS_7": "一周活跃达成，还带回了新的自定义位置。"
        case "STREAK_7": "连续一周守住阵地，漂亮。"
        case "STREAK_14": "两周不落，家务已经被你做出节奏。"
        case "HABIT_30": "这不只是勤快，已经是一种可靠。"
        case "MASTERY_DISHES": "碗碟战线再升级，水槽见你都客气。"
        case "MASTERY_COOKING": "厨房火力稳定，开饭这件事有了主心骨。"
        case "MASTERY_TRASH": "垃圾不留过夜，清爽由你守住。"
        case "MASTERY_PET": "毛孩子的后勤补给，被你稳稳接住。"
        case "MASTERY_CHILDCARE": "琐碎照护都有回音，你的耐心被记住了。"
        case "MASTERY_FLOOR": "地面亮度继续提升，脚底都更有底气。"
        case "MASTERY_LAUNDRY": "衣物轮回顺畅运转，少不了你的调度。"
        case "MASTERY_ROMANCE": "浪漫不是偶然，是有人一直认真准备。"
        case "MASTERY_ORGANIZE": "乱中取序的能力，又被功劳簿盖了章。"
        case "MASTERY_ALL_ROUNDER": "多条战线都能接住，家庭六边形已点亮。"
        case "REACTION_FIRST": "家庭夸夸群正式开张，付出有了回音。"
        case "REACTION_GIVEN_20": "气氛组稳定营业，家人的功劳你都看见了。"
        case "REACTION_RECEIVED_10": "十次回应到账，你的付出从来不是静音模式。"
        case "FAMILY_FORMED": "两个人就能成队，家庭战线正式成立。"
        case "FAMILY_ALL_IN": "这一周全员到齐，没有一份劳动隐身。"
        case "FAMILY_RELAY": "家务接力漂亮交棒，今天全家都在场。"
        case "FAMILY_VISIBLE_4W": "连续四周全员有功，这个家稳稳在运转。"
        case "FAMILY_FULL_SERVICE": "从开火到收尾再到地面，一条龙配合完成。"
        case "FAMILY_CATEGORY_COVERAGE": "八条家庭战线全部点亮，家务图鉴已收齐。"
        case "PAIR_COOK_AND_CLEAN": "一人掌勺一人收尾，这顿饭配合得刚刚好。"
        case "FAMILY_ACTIVE_DAYS": "日子一天天有了形状，家的运转都有迹可循。"
        case "FAMILY_RECORD_COUNT": "一件一件记下来，原来这个家被照顾了这么多次。"
        case "FAMILY_ANNIVERSARY": "一起过了一整年，普通日子也值得一枚纪念章。"
        case "HIDDEN_DISHES_3": "水槽三连清空，今天这片水域由你接管。"
        case "HIDDEN_SHINY_FLOOR": "扫拖联动完成，地板差点能当镜子。"
        case "HIDDEN_GUESTS": "五条战线同日开工，家里像刚迎接过重要客人。"
        case "HIDDEN_NIGHT_SHIFT": "夜深了还有人在照顾这个家，这份守护被发现了。"
        case "HIDDEN_ENDURANCE": "两小时耐力局完成，你把一件难事稳稳收了尾。"
        default: "新的家庭功劳已经解锁。"
        }
    }

    static func systemImage(for key: String) -> String {
        switch key {
        case "FIRST_RECORD": "checkmark.seal.fill"
        case "ACTIVE_DAYS_3": "calendar.badge.checkmark"
        case "ACTIVE_DAYS_5": "hand.thumbsup.fill"
        case "ACTIVE_DAYS_7": "house.and.flag.fill"
        case "STREAK_7": "flame.fill"
        case "STREAK_14": "bolt.heart.fill"
        case "HABIT_30": "medal.star.fill"
        case "MASTERY_DISHES": "fork.knife.circle.fill"
        case "MASTERY_COOKING": "frying.pan.fill"
        case "MASTERY_TRASH": "trash.circle.fill"
        case "MASTERY_PET": "pawprint.circle.fill"
        case "MASTERY_CHILDCARE": "figure.2.and.child.holdinghands"
        case "MASTERY_FLOOR": "sparkles.rectangle.stack.fill"
        case "MASTERY_LAUNDRY": "washer.fill"
        case "MASTERY_ROMANCE": "heart.circle.fill"
        case "MASTERY_ORGANIZE": "shippingbox.circle.fill"
        case "MASTERY_ALL_ROUNDER": "hexagon.fill"
        case "REACTION_FIRST": "hand.thumbsup.fill"
        case "REACTION_GIVEN_20": "hands.clap.fill"
        case "REACTION_RECEIVED_10": "heart.circle.fill"
        case "FAMILY_FORMED": "house.and.flag.fill"
        case "FAMILY_ALL_IN": "person.3.fill"
        case "FAMILY_RELAY": "figure.run.circle.fill"
        case "FAMILY_VISIBLE_4W": "calendar.badge.checkmark"
        case "FAMILY_FULL_SERVICE": "fork.knife.circle.fill"
        case "FAMILY_CATEGORY_COVERAGE": "square.grid.3x3.fill"
        case "PAIR_COOK_AND_CLEAN": "person.2.fill"
        case "FAMILY_ACTIVE_DAYS": "calendar"
        case "FAMILY_RECORD_COUNT": "books.vertical.fill"
        case "FAMILY_ANNIVERSARY": "birthday.cake.fill"
        case "HIDDEN_DISHES_3": "drop.fill"
        case "HIDDEN_SHINY_FLOOR": "sparkles"
        case "HIDDEN_GUESTS": "door.left.hand.open"
        case "HIDDEN_NIGHT_SHIFT": "moon.stars.fill"
        case "HIDDEN_ENDURANCE": "stopwatch.fill"
        default: "sparkles"
        }
    }

    static func tierName(_ tier: String) -> String? {
        switch tier {
        case "BRONZE": "铜"
        case "SILVER": "银"
        case "GOLD": "金"
        default: nil
        }
    }
}
