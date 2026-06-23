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

struct JoinRequestItem: Identifiable, Hashable {
    let id: String
    let userId: String
    let displayName: String
    let identityLabel: String
    let customIdentity: String?
    let avatarKey: String?
    let status: FamilyMemberStatus

    var displayIdentity: String {
        identityLabel == "自定义" ? (customIdentity ?? identityLabel) : identityLabel
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
    var isLocked = false
    var requiredPlan = "free"
}

struct ActivityLiker: Identifiable, Hashable {
    let id: String
    let displayName: String
    let avatarKey: String?
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
    var canDelete: Bool = false

    var displayIdentity: String {
        identityLabel == "自定义" ? (customIdentity ?? identityLabel) : identityLabel
    }
}

struct MonthlyReport: Hashable {
    let month: String
    let totalPoints: Int
    let totalRecords: Int
    let headline: String
}
