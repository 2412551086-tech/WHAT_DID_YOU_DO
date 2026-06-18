import Foundation

struct MockLoginRequest: Encodable {
    let displayName: String
}

struct CreateFamilyRequest: Encodable {
    let name: String
    let requirePhotoProof: Bool
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
    let displayName: String
    let createdAt: Date?
    let updatedAt: Date?
}

struct FamilyDTO: Decodable {
    let id: String
    let name: String
    let requirePhotoProof: Bool
    let inviteCode: String
    let createdAt: Date?
    let updatedAt: Date?
    let members: [FamilyMemberDTO]?
    let myRole: String?
}

struct FamilyMemberDTO: Decodable {
    let id: String
    let userId: String
    let familyId: String
    let role: String
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
    let familyId: String
    let user: RecordUserDTO
    let chore: RecordChoreDTO
    let minutes: Int
    let actualMinutes: Int?
    let points: Int
    let note: String?
    let imageUrls: [String]
    let createdAt: Date
}

struct ActivityItemDTO: Decodable {
    let id: String
    let familyId: String
    let user: RecordUserDTO
    let chore: RecordChoreDTO
    let minutes: Int
    let actualMinutes: Int?
    let points: Int
    let note: String?
    let imageUrls: [String]
    let createdAt: Date
}

struct RecordUserDTO: Decodable {
    let id: String
    let displayName: String
}

struct RecordChoreDTO: Decodable {
    let id: String
    let name: String
    let category: String
    let icon: String?
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
