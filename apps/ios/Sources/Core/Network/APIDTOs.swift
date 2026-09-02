import Foundation

struct MockLoginRequest: Encodable {
    let phoneNumber: String
    let displayName: String?
    let deviceId: String?
    let deviceName: String?
    let platform: String?
    let appVersion: String?
}

struct RefreshTokenRequest: Encodable, Sendable {
    let refreshToken: String
}

struct CreateFamilyRequest: Encodable {
    let name: String
    let requirePhotoProof: Bool
    let identityLabel: String
    let customIdentity: String?
    let avatarKey: String?
    let timezone: String?
}

struct CreateJoinRequestRequest: Encodable {
    let inviteCode: String
    let identityLabel: String
    let customIdentity: String?
    let avatarKey: String?
}

struct ReviewJoinRequestRequest: Encodable {
    let action: String
}

struct TransferOwnershipRequest: Encodable {
    let memberId: String
}

struct UpdateFamilyRequest: Encodable {
    let name: String
}

struct UpdateCurrentUserRequest: Encodable {
    let displayName: String
}

struct UpdateMemberAppearanceRequest: Encodable {
    let avatarKey: String
}

struct CreateChoreRecordRequest: Encodable {
    let familyId: String
    let choreId: String
    let actualMinutes: Int
    let pointsMultiplier: Double?
    let note: String?
    let imageUrls: [String]?
}

struct UpdateChoreRecordRequest: Encodable {
    let actualMinutes: Int
    let pointsMultiplier: Double?
}

struct SaveCustomChoreRequest: Encodable {
    let name: String
    let iconKey: String
    let category: String
    let standardMinutes: Int
    let difficultyMultiplier: Double
}

struct LoginResponse: Decodable {
    let user: UserDTO
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: Date
    let refreshTokenExpiresAt: Date

    var tokens: AuthTokens {
        AuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessTokenExpiresAt: accessTokenExpiresAt,
            refreshTokenExpiresAt: refreshTokenExpiresAt
        )
    }
}

struct RefreshTokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: Date
    let refreshTokenExpiresAt: Date

    var tokens: AuthTokens {
        AuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessTokenExpiresAt: accessTokenExpiresAt,
            refreshTokenExpiresAt: refreshTokenExpiresAt
        )
    }
}

struct LogoutResponseDTO: Decodable {
    let revoked: Bool?
    let revokedSessions: Int?
}

struct PremiumRedemptionRequest: Codable {
    let code: String
}

struct PremiumRedemptionResponseDTO: Decodable {
    let plan: String
    let premiumRedeemedAt: Date?
}

struct UserDTO: Decodable {
    let id: String
    let phoneNumber: String?
    let displayName: String
    let plan: String?
    let premiumRedeemedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?
}

struct FamilyDTO: Decodable {
    let id: String
    let name: String
    let requirePhotoProof: Bool
    let timezone: String?
    let inviteCode: String
    let createdAt: Date?
    let updatedAt: Date?
    let members: [FamilyMemberDTO]?
    let myRole: String?
    let identityLabel: String?
    let customIdentity: String?
    let avatarKey: String?
    let memberRole: String?
    let status: String?
    let myMembership: FamilyMemberDTO?
    let hasPremiumAccess: Bool?
}

struct FamilyMemberDTO: Decodable {
    let id: String
    let userId: String
    let familyId: String
    let role: String?
    let identityLabel: String?
    let customIdentity: String?
    let avatarKey: String?
    let memberRole: String?
    let status: String?
    let approvedAt: Date?
    let approvedById: String?
    let createdAt: Date?
    let user: UserDTO?
}

struct TransferOwnershipResponseDTO: Decodable {
    let familyId: String
    let previousOwner: FamilyMemberDTO
    let newOwner: FamilyMemberDTO
}

struct LeaveFamilyResponseDTO: Decodable {
    let familyId: String
    let left: Bool
}

struct DeleteAccountResponseDTO: Decodable {
    let deleted: Bool
    let deletedAt: Date
}

struct JoinRequestDTO: Decodable {
    let id: String
    let userId: String
    let familyId: String
    let identityLabel: String
    let customIdentity: String?
    let avatarKey: String?
    let memberRole: String
    let status: String
    let approvedAt: Date?
    let approvedById: String?
    let createdAt: Date
    let user: UserDTO?
}

struct FamilyInviteOwnerDTO: Decodable {
    let id: String
    let displayName: String
    let identityLabel: String
    let customIdentity: String?
    let avatarKey: String?
}

struct FamilyInvitePreviewDTO: Decodable {
    let id: String
    let name: String
    let inviteCode: String
    let memberCount: Int
    let owner: FamilyInviteOwnerDTO?
    let currentStatus: String?
}

struct JoinApplicationDTO: Decodable {
    let id: String
    let userId: String
    let familyId: String
    let identityLabel: String
    let customIdentity: String?
    let avatarKey: String?
    let memberRole: String
    let status: String
    let approvedAt: Date?
    let approvedById: String?
    let createdAt: Date
    let user: UserDTO?
    let family: FamilyInvitePreviewDTO
}

struct ChoreDTO: Decodable {
    let id: String
    let name: String
    let themeKey: String?
    let category: String
    let minutes: Int
    let points: Int
    let difficultyMultiplier: Double?
    let icon: String?
    let suggestedFrequency: String?
    let isCustom: Bool?
    let customSlot: Int?
    let isCoreFree: Bool
    let requiredPlan: String
    let isLocked: Bool
}

struct ChoreLayoutDTO: Codable, Sendable {
    let choreIds: [String]
    let pinnedChoreIds: [String]
    let isConfigured: Bool
    let scope: String?
    let canEdit: Bool?
    let selectionLimit: Int?
    let customChoreLimit: Int?
    let isPersonalized: Bool?
    let followFamilyLayout: Bool?
}

struct UpdateChoreLayoutRequest: Encodable, Sendable {
    let choreIds: [String]
    let pinnedChoreIds: [String]
    let followFamilyLayout: Bool?

    init(choreIds: [String], pinnedChoreIds: [String], followFamilyLayout: Bool? = nil) {
        self.choreIds = choreIds
        self.pinnedChoreIds = pinnedChoreIds
        self.followFamilyLayout = followFamilyLayout
    }
}

struct ArchiveCustomChoreResponseDTO: Decodable {
    let id: String
    let archivedAt: Date?
}

struct ChoreRecordDTO: Decodable {
    let id: String
    let recordId: String?
    let familyId: String
    let user: RecordUserDTO
    let createdBy: RecordUserDTO?
    let chore: RecordChoreDTO
    let choreName: String?
    let minutes: Int
    let actualMinutes: Int?
    let points: Int
    let pointsMultiplier: Double?
    let note: String?
    let imageUrls: [String]
    let likeCount: Int?
    let likedBy: [RecordUserDTO]?
    let likedByMe: Bool?
    let reactionCounts: [String: Int]?
    let myReaction: String?
    let canDelete: Bool?
    let canEdit: Bool?
    let createdAt: Date
    let achievementEvaluation: AchievementEvaluationDTO?
}

struct ActivityItemDTO: Decodable {
    let id: String
    let recordId: String?
    let familyId: String
    let user: RecordUserDTO
    let createdBy: RecordUserDTO?
    let chore: RecordChoreDTO
    let choreName: String?
    let minutes: Int
    let actualMinutes: Int?
    let points: Int
    let pointsMultiplier: Double?
    let note: String?
    let imageUrls: [String]
    let likeCount: Int?
    let likedBy: [RecordUserDTO]?
    let likedByMe: Bool?
    let reactionCounts: [String: Int]?
    let myReaction: String?
    let canDelete: Bool?
    let canEdit: Bool?
    let createdAt: Date
}

struct RecordUserDTO: Decodable {
    let id: String
    let displayName: String
    let identityLabel: String?
    let customIdentity: String?
    let avatarKey: String?
    let reactionKey: String?
}

struct RecordChoreDTO: Decodable {
    let id: String
    let name: String
    let category: String
    let icon: String?
    let standardMinutes: Int?
    let defaultPoints: Int?
    let difficultyMultiplier: Double?
}

struct LikeResponseDTO: Decodable {
    let recordId: String
    let likeCount: Int
    let likedByMe: Bool
    let reactionCounts: [String: Int]?
    let myReaction: String?
}

struct ReactionRequestDTO: Encodable, Sendable {
    let reactionKey: String
}

struct DeleteRecordResponseDTO: Decodable {
    let recordId: String
    let deletedAt: Date?
    let deletedById: String?
    let undoExpiresAt: Date?
    let achievementEvaluation: AchievementEvaluationDTO?
}

struct RestoreRecordResponseDTO: Decodable {
    let recordId: String
    let restored: Bool
    let achievementEvaluation: AchievementEvaluationDTO?
}

struct LeaderboardItemDTO: Decodable {
    let rank: Int
    let userId: String
    let displayName: String
    let points: Int
    let recordCount: Int
}

struct MonthlyReportDTO: Decodable {
    let familyId: String
    let month: String
    let totalPoints: Int
    let totalRecords: Int
    let totalMinutes: Int?
    let headline: String
    let comparison: MonthlyReportComparisonDTO?
    let monthlyTrend: [MonthlyReportMonthDTO]?
    let weeklyTrend: [MonthlyReportWeekDTO]?
    let memberContributions: [MonthlyReportMemberContributionDTO]?
    let leaderboard: [MonthlyReportLeaderboardItemDTO]
    let themeStats: [MonthlyReportThemeDTO]?
    let categoryStats: [MonthlyReportCategoryDTO]
    let recentRecords: [MonthlyReportRecordDTO]
}

struct MonthlyReportMonthDTO: Decodable {
    let month: String
    let points: Int
    let recordCount: Int
    let totalMinutes: Int
}

struct MonthlyReportComparisonDTO: Decodable {
    let previousMonth: String
    let totalPoints: Int
    let totalRecords: Int
    let totalMinutes: Int
}

struct MonthlyReportWeekDTO: Decodable {
    let weekStart: String
    let weekEnd: String
    let label: String
    let points: Int
    let recordCount: Int
    let totalMinutes: Int
}

struct MonthlyReportMemberContributionDTO: Decodable {
    let userId: String
    let displayName: String
    let points: Int
    let recordCount: Int
    let totalMinutes: Int
}

struct MonthlyReportLeaderboardItemDTO: Decodable {
    let userId: String
    let displayName: String
    let points: Int
    let recordCount: Int
}

struct MonthlyReportCategoryDTO: Decodable {
    let category: String
    let points: Int
    let recordCount: Int
    let memberContributions: [MonthlyReportMemberContributionDTO]?
}

struct MonthlyReportThemeDTO: Decodable {
    let themeKey: String
    let points: Int
    let recordCount: Int
}

struct MonthlyReportRecordDTO: Decodable {
    let id: String
    let memberName: String
    let choreName: String
    let category: String
    let points: Int
    let minutes: Int
    let actualMinutes: Int?
    let createdAt: Date
}

struct AchievementEvaluationDTO: Decodable, Sendable {
    let eventId: String
    let state: String
    let retryAfterMs: Int?
}

struct AchievementRewardDTO: Decodable, Sendable {
    let type: String
    let value: Int
}

struct AchievementCapacityBucketDTO: Decodable, Sendable {
    let base: Int
    let earned: Int
    let limit: Int?
}

struct AchievementCapacityDTO: Decodable, Sendable {
    let common: AchievementCapacityBucketDTO
    let custom: AchievementCapacityBucketDTO
}

struct AchievementItemDTO: Decodable, Sendable {
    let definitionId: String
    let key: String
    let nameKey: String
    let descriptionKey: String
    let unlockCopyKey: String
    let track: String
    let tier: String
    let targetValue: Int
    let currentValue: Int
    let rawCurrentValue: Int
    let progressStatus: String
    let isUnlocked: Bool
    let memberAchievementId: String?
    let unlockedAt: Date?
    let visibility: String
    let reward: AchievementRewardDTO?
}

struct AchievementSummaryDTO: Decodable, Sendable {
    let familyId: String
    let userId: String
    let showAchievementsToFamily: Bool
    let unlockedCount: Int
    let totalCount: Int
    let nextAchievement: AchievementItemDTO?
    let recentUnlocks: [AchievementItemDTO]
    let capacity: AchievementCapacityDTO
}

struct AchievementCollectionDTO: Decodable, Sendable {
    let familyId: String
    let userId: String
    let showAchievementsToFamily: Bool
    let achievements: [AchievementItemDTO]
    let capacity: AchievementCapacityDTO
    let updatedAt: Date
}

struct UpdateAchievementVisibilityRequest: Encodable, Sendable {
    let visibility: String
}

struct UpdateAchievementSharingRequest: Encodable, Sendable {
    let showToFamily: Bool
}

struct AchievementSharingResponseDTO: Decodable, Sendable {
    let familyId: String
    let userId: String
    let showToFamily: Bool
}

struct AchievementVisibilityResponseDTO: Decodable, Sendable {
    let id: String
    let achievementKey: String
    let visibility: String
    let unlockedAt: Date
}

struct AchievementUnlockDTO: Decodable, Sendable {
    let id: String
    let achievementKey: String
    let tier: String
    let unlockedAt: Date
    let visibility: String
}

struct AchievementRewardGrantDTO: Decodable, Sendable {
    let achievementKey: String
    let rewardType: String
    let rewardValue: Int
    let grantedAt: Date
}

struct AchievementUnlockBatchDTO: Decodable, Sendable {
    let id: String
    let primaryUnlockId: String?
    let unlockCount: Int
    let unlocks: [AchievementUnlockDTO]
    let rewards: [AchievementRewardGrantDTO]
}

struct AchievementSyncDTO: Decodable, Sendable {
    let eventId: String
    let state: String
    let retryCount: Int
    let retryAfterMs: Int?
    let processedAt: Date?
    let lastErrorCode: String?
    let unlockBatch: AchievementUnlockBatchDTO?
}
