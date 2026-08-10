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
    case highFive = "high_five"
    case moonFace = "moon_face"
    case laughCry = "laugh_cry"
    case tease

    var id: String { rawValue }

    var title: String {
        switch self {
        case .like: "点赞"
        case .highFive: "击掌"
        case .moonFace: "黑脸"
        case .laughCry: "笑哭"
        case .tease: "调侃"
        }
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
    let actualMinutes: Int
    let points: Int
    let note: String
    let createdAt: Date
    let icon: String
    let color: Color
    let creatorId: String?
    let identityLabel: String
    let customIdentity: String?
    let avatarKey: String?
    var likeCount: Int = 0
    var likedBy: [ActivityLiker] = []
    var likedByMe: Bool = false
    var reactionCounts: [ChoreReaction: Int] = [:]
    var myReaction: ChoreReaction? = nil
    var canDelete: Bool = false

    var displayIdentity: String {
        identityLabel == "自定义" ? (customIdentity ?? identityLabel) : identityLabel
    }
}

struct MonthlyReport: Hashable {
    let month: String
    let totalPoints: Int
    let totalRecords: Int
    let totalMinutes: Int
    let headline: String
    let themeStats: [MonthlyReportTheme]
    let categoryStats: [MonthlyReportCategory]
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
}
