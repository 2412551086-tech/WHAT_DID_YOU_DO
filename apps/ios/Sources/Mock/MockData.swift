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

    static let coreChores: [ChoreItem] = [
        ChoreItem(id: "mock-chore-cook", name: "做饭 / 备餐", category: "厨房类", minutes: 45, points: 99, icon: "flame.fill", color: DSColor.coral),
        ChoreItem(id: "mock-chore-dishes", name: "饭后收拾 / 洗碗", category: "厨房类", minutes: 20, points: 28, icon: "fork.knife", color: DSColor.yellow),
        ChoreItem(id: "mock-chore-laundry", name: "洗衣服", category: "洗护类", minutes: 25, points: 33, icon: "washer.fill", color: DSColor.clay),
        ChoreItem(id: "mock-chore-put-away-clothes", name: "收衣 / 叠衣 / 放回衣柜", category: "洗护类", minutes: 20, points: 24, icon: "square.stack.3d.up.fill", color: DSColor.mint),
        ChoreItem(id: "mock-chore-vacuum", name: "扫地 / 吸尘", category: "清洁类", minutes: 20, points: 26, icon: "sparkles", color: DSColor.sky),
        ChoreItem(id: "mock-chore-mop", name: "拖地 / 地面湿清洁", category: "清洁类", minutes: 25, points: 40, icon: "drop.fill", color: DSColor.lavender),
        ChoreItem(id: "mock-chore-organize", name: "整理收纳", category: "收纳类", minutes: 20, points: 26, icon: "shippingbox.fill", color: DSColor.mint),
        ChoreItem(id: "mock-chore-bathroom", name: "卫生间清洁", category: "清洁类", minutes: 35, points: 70, icon: "shower.fill", color: DSColor.lavender),
        ChoreItem(id: "mock-chore-trash", name: "倒垃圾 / 垃圾分类", category: "清洁类", minutes: 10, points: 10, icon: "trash.fill", color: DSColor.sky),
        ChoreItem(id: "mock-chore-shopping", name: "采购补货 / 家庭物资管理", category: "采购类", minutes: 60, points: 102, icon: "cart.fill", color: DSColor.coral),
    ]

    static let premiumChores: [ChoreItem] = [
        ChoreItem(id: "premium-change-bedding", name: "换床单", category: "洗护类", minutes: 20, points: 24, icon: "bed.double.fill", color: DSColor.mint, isLocked: true, requiredPlan: "premium"),
        ChoreItem(id: "premium-clean-stove", name: "清理灶台", category: "厨房类", minutes: 10, points: 11, icon: "flame.fill", color: DSColor.yellow, isLocked: true, requiredPlan: "premium"),
        ChoreItem(id: "premium-heavy-lifting", name: "搬重物", category: "采购类", minutes: 20, points: 32, icon: "shippingbox.fill", color: DSColor.clay, isLocked: true, requiredPlan: "premium"),
        ChoreItem(id: "premium-walk-dog", name: "遛狗", category: "照顾类", minutes: 30, points: 33, icon: "pawprint.fill", color: DSColor.sky, isLocked: true, requiredPlan: "premium"),
        ChoreItem(id: "premium-clean-litter", name: "清理猫砂", category: "照顾类", minutes: 10, points: 12, icon: "pawprint.fill", color: DSColor.clay, isLocked: true, requiredPlan: "premium"),
        ChoreItem(id: "premium-homework-help", name: "陪孩子写作业", category: "照顾类", minutes: 60, points: 90, icon: "book.fill", color: DSColor.lavender, isLocked: true, requiredPlan: "premium"),
        ChoreItem(id: "premium-repair-booking", name: "预约维修", category: "管理类", minutes: 15, points: 17, icon: "wrench.and.screwdriver.fill", color: DSColor.coral, isLocked: true, requiredPlan: "premium"),
        ChoreItem(id: "premium-feed-baby", name: "喂奶", category: "照顾类", minutes: 25, points: 38, icon: "waterbottle.fill", color: DSColor.mint, isLocked: true, requiredPlan: "premium"),
        ChoreItem(id: "premium-walk-child", name: "遛娃", category: "照顾类", minutes: 45, points: 63, icon: "figure.walk", color: DSColor.sky, isLocked: true, requiredPlan: "premium"),
        ChoreItem(id: "premium-school-run", name: "接送孩子", category: "照顾类", minutes: 40, points: 56, icon: "car.fill", color: DSColor.yellow, isLocked: true, requiredPlan: "premium"),
    ]

    static let chores = coreChores + premiumChores

    static let todayRecords: [ChoreRecord] = [
        ChoreRecord(id: "mock-record-dishes", memberName: "我", choreName: "饭后收拾 / 洗碗", category: "厨房类", standardMinutes: 20, actualMinutes: 20, points: 28, note: "水槽终于重见天日", createdAt: Date().addingTimeInterval(-4_200), icon: "fork.knife", color: DSColor.yellow, creatorId: currentUser.id, identityLabel: "老妈", customIdentity: nil, avatarKey: "avatar_01", likeCount: 2, likedByMe: true, canDelete: true),
        ChoreRecord(id: "mock-record-mop", memberName: "小夏", choreName: "拖地 / 地面湿清洁", category: "清洁类", standardMinutes: 25, actualMinutes: 30, points: 48, note: "地板亮到能照出理想", createdAt: Date().addingTimeInterval(-2_700), icon: "drop.fill", color: DSColor.lavender, creatorId: "mock-user-xia", identityLabel: "室友", customIdentity: nil, avatarKey: "avatar_02", likeCount: 1, likedByMe: false, canDelete: true),
        ChoreRecord(id: "mock-record-trash", memberName: "豆豆", choreName: "倒垃圾 / 垃圾分类", category: "清洁类", standardMinutes: 10, actualMinutes: 10, points: 10, note: "垃圾桶暂时恢复平静", createdAt: Date().addingTimeInterval(-1_100), icon: "trash.fill", color: DSColor.sky, creatorId: "mock-user-doudou", identityLabel: "妹妹", customIdentity: nil, avatarKey: "avatar_03", likeCount: 0, likedByMe: false, canDelete: true),
    ]

    static let monthlyReport = MonthlyReport(
        month: "2026-06",
        totalPoints: members.reduce(0) { $0 + $1.monthlyPoints },
        totalRecords: todayRecords.count,
        headline: "Mock 家庭劳动广播稳定播出"
    )
}
