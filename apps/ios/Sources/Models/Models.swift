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
}

struct FamilyMember: Identifiable, Hashable {
    let id: String
    let name: String
    var monthlyPoints: Int
    let badge: String
    let color: Color
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
}

struct MonthlyReport: Hashable {
    let month: String
    let totalPoints: Int
    let totalRecords: Int
    let headline: String
}
