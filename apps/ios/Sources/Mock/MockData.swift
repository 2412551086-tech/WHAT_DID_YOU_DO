import SwiftUI

enum MockData {
    static let currentUser = AppUser(
        id: "mock-user-me",
        displayName: "我",
        avatarInitial: "我",
        badge: "今日值班观察员"
    )

    static let family = FamilySpace(
        id: "mock-family-main",
        name: "今日劳动观察站",
        inviteCode: "WDYD88",
        requiresPhotoProof: false
    )

    static let members: [FamilyMember] = [
        FamilyMember(id: currentUser.id, name: "我", monthlyPoints: 126, badge: "厨房战神", color: DSColor.yellow),
        FamilyMember(id: "mock-user-xia", name: "小夏", monthlyPoints: 98, badge: "地板守护者", color: DSColor.mint),
        FamilyMember(id: "mock-user-doudou", name: "豆豆", monthlyPoints: 42, badge: "浇花小队长", color: DSColor.sky),
    ]

    static let currentMembership = FamilyMembership(
        id: "mock-membership-owner",
        userId: currentUser.id,
        familyId: family.id,
        identityLabel: "老妈",
        customIdentity: nil,
        avatarKey: "avatar_01",
        memberRole: .owner,
        status: .active
    )

    static let joinRequests: [JoinRequestItem] = [
        JoinRequestItem(
            id: "mock-join-request",
            userId: "mock-user-pending",
            displayName: "新成员",
            identityLabel: "室友",
            customIdentity: nil,
            avatarKey: "avatar_04",
            status: .pending
        ),
    ]

    static let chores: [ChoreItem] = [
        ChoreItem(id: "mock-chore-dishes", name: "洗碗", category: "厨房类", minutes: 15, points: 15, icon: "fork.knife", color: DSColor.yellow),
        ChoreItem(id: "mock-chore-cook", name: "做饭", category: "厨房类", minutes: 45, points: 59, icon: "flame.fill", color: DSColor.coral),
        ChoreItem(id: "mock-chore-trash", name: "倒垃圾", category: "清洁类", minutes: 5, points: 5, icon: "trash.fill", color: DSColor.mint),
        ChoreItem(id: "mock-chore-sweep", name: "扫地", category: "清洁类", minutes: 15, points: 15, icon: "sparkles", color: DSColor.sky),
        ChoreItem(id: "mock-chore-mop", name: "拖地", category: "清洁类", minutes: 20, points: 22, icon: "drop.fill", color: DSColor.lavender),
        ChoreItem(id: "mock-chore-laundry", name: "洗衣服", category: "洗护类", minutes: 10, points: 10, icon: "washer.fill", color: DSColor.clay),
        ChoreItem(id: "mock-chore-dry-clothes", name: "晾衣服", category: "洗护类", minutes: 10, points: 10, icon: "wind", color: DSColor.mint),
        ChoreItem(id: "mock-chore-fold-clothes", name: "叠衣服", category: "洗护类", minutes: 20, points: 22, icon: "square.stack.3d.up.fill", color: DSColor.sky),
        ChoreItem(id: "mock-chore-bathroom", name: "清理卫生间", category: "清洁类", minutes: 30, points: 45, icon: "shower.fill", color: DSColor.lavender),
        ChoreItem(id: "mock-chore-plants", name: "浇花", category: "照顾类", minutes: 8, points: 8, icon: "leaf.fill", color: DSColor.mint),
    ]

    static let todayRecords: [ChoreRecord] = [
        ChoreRecord(id: "mock-record-dishes", memberName: "我", choreName: "洗碗", category: "厨房类", standardMinutes: 15, actualMinutes: 15, points: 15, note: "水槽终于重见天日", createdAt: Date().addingTimeInterval(-4_200), icon: "fork.knife", color: DSColor.yellow, creatorId: currentUser.id, identityLabel: "老妈", customIdentity: nil, avatarKey: "avatar_01", likeCount: 2, likedByMe: true, canDelete: true),
        ChoreRecord(id: "mock-record-mop", memberName: "小夏", choreName: "拖地", category: "清洁类", standardMinutes: 20, actualMinutes: 24, points: 26, note: "地板亮到能照出理想", createdAt: Date().addingTimeInterval(-2_700), icon: "drop.fill", color: DSColor.lavender, creatorId: "mock-user-xia", identityLabel: "室友", customIdentity: nil, avatarKey: "avatar_02", likeCount: 1, likedByMe: false, canDelete: true),
        ChoreRecord(id: "mock-record-plants", memberName: "豆豆", choreName: "浇花", category: "照顾类", standardMinutes: 8, actualMinutes: 8, points: 8, note: "植物表示情绪稳定", createdAt: Date().addingTimeInterval(-1_100), icon: "leaf.fill", color: DSColor.mint, creatorId: "mock-user-doudou", identityLabel: "妹妹", customIdentity: nil, avatarKey: "avatar_03", likeCount: 0, likedByMe: false, canDelete: true),
    ]

    static let monthlyReport = MonthlyReport(
        month: "2026-06",
        totalPoints: members.reduce(0) { $0 + $1.monthlyPoints },
        totalRecords: todayRecords.count,
        headline: "Mock 家庭劳动广播稳定播出"
    )
}
