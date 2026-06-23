import Foundation

struct MockLoginRequest: Encodable {
    let phoneNumber: String
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

struct CreateChoreRecordRequest: Encodable {
    let familyId: String
    let choreId: String
    let actualMinutes: Int
    let note: String?
    let imageUrls: [String]?
}

struct LoginResponse: Decodable {
    let user: UserDTO
    let accessToken: String
}

struct UserDTO: Decodable {
    let id: String
    let phoneNumber: String?
    let displayName: String
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

struct ChoreDTO: Decodable {
    let id: String
    let name: String
    let category: String
    let minutes: Int
    let points: Int
    let isCoreFree: Bool
    let requiredPlan: String
    let isLocked: Bool
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
    let note: String?
    let imageUrls: [String]
    let likeCount: Int?
    let likedBy: [RecordUserDTO]?
    let likedByMe: Bool?
    let canDelete: Bool?
    let createdAt: Date
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
    let note: String?
    let imageUrls: [String]
    let likeCount: Int?
    let likedBy: [RecordUserDTO]?
    let likedByMe: Bool?
    let canDelete: Bool?
    let createdAt: Date
}

struct RecordUserDTO: Decodable {
    let id: String
    let displayName: String
    let identityLabel: String?
    let customIdentity: String?
    let avatarKey: String?
}

struct RecordChoreDTO: Decodable {
    let id: String
    let name: String
    let category: String
    let icon: String?
}

struct LikeResponseDTO: Decodable {
    let recordId: String
    let likeCount: Int
    let likedByMe: Bool
}

struct DeleteRecordResponseDTO: Decodable {
    let recordId: String
    let id: String
    let deletedAt: Date?
    let deletedById: String?
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
    let headline: String
    let leaderboard: [MonthlyReportLeaderboardItemDTO]
    let categoryStats: [MonthlyReportCategoryDTO]
    let recentRecords: [MonthlyReportRecordDTO]
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
