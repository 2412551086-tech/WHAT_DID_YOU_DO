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
        requiresPhotoProof: false,
        timezone: TimeZone.current.identifier
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

    static let familyMemberProfiles: [FamilyMemberProfile] = [
        FamilyMemberProfile(
            id: currentMembership.id,
            userId: currentUser.id,
            name: currentUser.displayName,
            identityLabel: currentMembership.identityLabel,
            customIdentity: nil,
            avatarKey: "avatar_01",
            memberRole: .owner,
            status: .active
        ),
        FamilyMemberProfile(
            id: "mock-membership-xia",
            userId: "mock-user-xia",
            name: "小夏",
            identityLabel: "室友",
            customIdentity: nil,
            avatarKey: "avatar_02",
            memberRole: .member,
            status: .active
        ),
        FamilyMemberProfile(
            id: "mock-membership-doudou",
            userId: "mock-user-doudou",
            name: "豆豆",
            identityLabel: "妹妹",
            customIdentity: nil,
            avatarKey: "avatar_03",
            memberRole: .member,
            status: .active
        ),
    ]

    static let joinRequests: [JoinRequestItem] = [
        JoinRequestItem(
            id: "mock-join-request",
            userId: "mock-user-pending",
            displayName: "新成员",
            identityLabel: "室友",
            customIdentity: nil,
            avatarKey: "avatar_04",
            status: .pending,
            createdAt: Date().addingTimeInterval(-300)
        ),
    ]

    static let invitePreview = FamilyInvitePreview(
        id: family.id,
        name: family.name,
        inviteCode: "A5F637F7",
        memberCount: 4,
        owner: FamilyInviteOwner(
            id: currentUser.id,
            displayName: "用户 123456",
            identityLabel: "女主人",
            customIdentity: nil,
            avatarKey: "avatar_01"
        ),
        currentStatus: nil
    )

    static let pendingJoinApplication = JoinApplication(
        id: "mock-join-request",
        userId: currentUser.id,
        identityLabel: "室友",
        customIdentity: nil,
        avatarKey: "avatar_08",
        status: .pending,
        createdAt: Date().addingTimeInterval(-300),
        family: invitePreview
    )

    static let coreChores: [ChoreItem] = [
        ChoreItem(id: "mock-chore-cook", name: "做饭备餐", category: "烹饪", minutes: 45, points: 68, icon: "flame.fill", color: DSColor.coral),
        ChoreItem(id: "mock-chore-dishes", name: "洗碗收桌", category: "清洁", minutes: 15, points: 21, icon: "fork.knife", color: DSColor.yellow),
        ChoreItem(id: "mock-chore-laundry", name: "洗衣服", category: "洗护", minutes: 10, points: 13, icon: "washer.fill", color: DSColor.clay),
        ChoreItem(id: "mock-chore-put-away-clothes", name: "收叠衣物", category: "洗护", minutes: 15, points: 18, icon: "square.stack.3d.up.fill", color: DSColor.mint),
        ChoreItem(id: "mock-chore-vacuum", name: "扫地吸尘", category: "清洁", minutes: 20, points: 26, icon: "sparkles", color: DSColor.sky),
        ChoreItem(id: "mock-chore-mop", name: "拖地清洁", category: "清洁", minutes: 25, points: 40, icon: "drop.fill", color: DSColor.lavender),
        ChoreItem(id: "mock-chore-organize", name: "整理收纳", category: "整理", minutes: 20, points: 26, icon: "shippingbox.fill", color: DSColor.mint),
        ChoreItem(id: "mock-chore-bathroom", name: "卫生间清洁", category: "清洁", minutes: 20, points: 30, icon: "shower.fill", color: DSColor.lavender),
        ChoreItem(id: "mock-chore-trash", name: "倒垃圾", category: "清洁", minutes: 10, points: 10, icon: "trash.fill", color: DSColor.sky),
        ChoreItem(id: "mock-chore-shopping", name: "采购补货", category: "家庭事务", minutes: 30, points: 36, icon: "cart.fill", color: DSColor.coral),
    ]

    static let premiumChores: [ChoreItem] = [
        ChoreItem(id: "premium-change-bedding", name: "换床单", category: "洗护", minutes: 20, points: 24, icon: "bed.double.fill", color: DSColor.mint),
        ChoreItem(id: "premium-clean-stove", name: "清理灶台", category: "清洁", minutes: 10, points: 11, icon: "flame.fill", color: DSColor.yellow),
        ChoreItem(id: "premium-heavy-lifting", name: "搬重物", category: "家庭事务", minutes: 20, points: 32, icon: "chore_catalog_heavy_lifting", color: DSColor.clay),
        ChoreItem(id: "premium-walk-dog", name: "遛狗", category: "照顾", minutes: 30, points: 33, icon: "pawprint.fill", color: DSColor.sky, themeKey: ChoreTheme.pet.rawValue),
        ChoreItem(id: "premium-clean-litter", name: "清理猫砂", category: "清洁", minutes: 10, points: 12, icon: "chore_catalog_clean_litter", color: DSColor.clay, themeKey: ChoreTheme.pet.rawValue),
        ChoreItem(id: "premium-homework-help", name: "陪写作业", category: "照顾", minutes: 60, points: 90, icon: "chore_catalog_homework_help", color: DSColor.lavender, themeKey: ChoreTheme.childcare.rawValue),
        ChoreItem(id: "premium-repair-booking", name: "预约维修", category: "家庭事务", minutes: 15, points: 17, icon: "chore_catalog_repair_booking", color: DSColor.coral),
        ChoreItem(id: "premium-feed-baby", name: "喂奶", category: "照顾", minutes: 25, points: 38, icon: "chore_catalog_feed_baby", color: DSColor.mint, themeKey: ChoreTheme.childcare.rawValue),
        ChoreItem(id: "premium-walk-child", name: "遛娃", category: "照顾", minutes: 45, points: 63, icon: "chore_catalog_walk_child", color: DSColor.sky, themeKey: ChoreTheme.childcare.rawValue),
        ChoreItem(id: "premium-school-run", name: "接送孩子", category: "照顾", minutes: 40, points: 56, icon: "chore_catalog_school_run", color: DSColor.yellow, themeKey: ChoreTheme.childcare.rawValue),
    ]

    static let themedChores: [ChoreItem] = [
        ChoreItem(id: "child-diaper-change", name: "换尿布", category: "照顾", minutes: 10, points: 12, icon: "chore_theme_child_diaper", color: DSColor.sky, themeKey: ChoreTheme.childcare.rawValue),
        ChoreItem(id: "child-bath-time", name: "宝宝洗澡", category: "洗护", minutes: 20, points: 28, icon: "chore_theme_child_bath", color: DSColor.mint, themeKey: ChoreTheme.childcare.rawValue),
        ChoreItem(id: "child-food-prep", name: "准备辅食", category: "烹饪", minutes: 30, points: 39, icon: "chore_theme_child_food", color: DSColor.yellow, themeKey: ChoreTheme.childcare.rawValue),
        ChoreItem(id: "child-bedtime", name: "哄睡", category: "照顾", minutes: 30, points: 45, icon: "chore_theme_child_sleep", color: DSColor.lavender, themeKey: ChoreTheme.childcare.rawValue),
        ChoreItem(id: "pet-feeding", name: "宠物喂食", category: "照顾", minutes: 10, points: 10, icon: "chore_theme_pet_feeding", color: DSColor.yellow, themeKey: ChoreTheme.pet.rawValue),
        ChoreItem(id: "pet-bath", name: "宠物洗澡", category: "洗护", minutes: 25, points: 33, icon: "chore_theme_pet_bath", color: DSColor.sky, themeKey: ChoreTheme.pet.rawValue),
        ChoreItem(id: "pet-medicine", name: "宠物喂药", category: "照顾", minutes: 10, points: 14, icon: "chore_theme_pet_medicine", color: DSColor.coral, themeKey: ChoreTheme.pet.rawValue),
        ChoreItem(id: "pet-vet-visit", name: "宠物看诊", category: "照顾", minutes: 60, points: 84, icon: "chore_theme_pet_vet", color: DSColor.mint, themeKey: ChoreTheme.pet.rawValue),
        ChoreItem(id: "love-date-plan", name: "约会策划", category: "家庭事务", minutes: 30, points: 33, icon: "chore_theme_love_date", color: DSColor.coral, themeKey: ChoreTheme.love.rawValue),
        ChoreItem(id: "love-gift-prepare", name: "准备礼物", category: "家庭事务", minutes: 45, points: 54, icon: "chore_theme_love_gift", color: DSColor.lavender, themeKey: ChoreTheme.love.rawValue),
        ChoreItem(id: "love-reunion", name: "异地见面", category: "照顾", minutes: 60, points: 72, icon: "chore_theme_love_reunion", color: DSColor.sky, themeKey: ChoreTheme.love.rawValue),
        ChoreItem(id: "love-pickup", name: "接送对方", category: "家庭事务", minutes: 40, points: 52, icon: "chore_theme_love_pickup", color: DSColor.mint, themeKey: ChoreTheme.love.rawValue),
        ChoreItem(id: "love-cook-meal", name: "为你做饭", category: "烹饪", minutes: 45, points: 63, icon: "chore_theme_love_cook", color: DSColor.yellow, themeKey: ChoreTheme.love.rawValue),
        ChoreItem(id: "love-support", name: "情绪陪伴", category: "照顾", minutes: 30, points: 36, icon: "chore_theme_love_support", color: DSColor.coral, themeKey: ChoreTheme.love.rawValue),
        ChoreItem(id: "love-anniversary", name: "纪念日准备", category: "家庭事务", minutes: 60, points: 78, icon: "chore_theme_love_anniversary", color: DSColor.lavender, themeKey: ChoreTheme.love.rawValue),
        ChoreItem(id: "love-trip-plan", name: "旅行规划", category: "家庭事务", minutes: 45, points: 54, icon: "chore_theme_love_trip", color: DSColor.sky, themeKey: ChoreTheme.love.rawValue),
        ChoreItem(id: "daily-dust-surfaces", name: "擦桌除尘", category: "清洁", minutes: 15, points: 15, icon: "chore_custom_dust", color: DSColor.mint, themeKey: ChoreTheme.daily.rawValue),
        ChoreItem(id: "daily-clean-windows", name: "擦窗玻璃", category: "清洁", minutes: 30, points: 39, icon: "chore_custom_window", color: DSColor.sky, themeKey: ChoreTheme.daily.rawValue),
        ChoreItem(id: "daily-make-bed", name: "整理床铺", category: "整理", minutes: 10, points: 10, icon: "chore_custom_bed", color: DSColor.lavender, themeKey: ChoreTheme.daily.rawValue),
        ChoreItem(id: "love-care-plants", name: "浇花养护", category: "照顾", minutes: 10, points: 8, icon: "chore_custom_plant", color: DSColor.mint, themeKey: ChoreTheme.love.rawValue),
        ChoreItem(id: "pet-general-care", name: "宠物照料", category: "照顾", minutes: 15, points: 17, icon: "chore_custom_pet", color: DSColor.coral, themeKey: ChoreTheme.pet.rawValue),
        ChoreItem(id: "daily-wash-car", name: "清洗车辆", category: "清洁", minutes: 40, points: 56, icon: "chore_custom_car", color: DSColor.sky, themeKey: ChoreTheme.daily.rawValue),
        ChoreItem(id: "daily-clean-fridge", name: "清理冰箱", category: "清洁", minutes: 30, points: 39, icon: "chore_custom_fridge", color: DSColor.yellow, themeKey: ChoreTheme.daily.rawValue),
        ChoreItem(id: "daily-home-repair", name: "家庭维修", category: "家庭事务", minutes: 30, points: 45, icon: "chore_custom_repair", color: DSColor.clay, themeKey: ChoreTheme.daily.rawValue),
        ChoreItem(id: "child-quality-time", name: "陪伴孩子", category: "照顾", minutes: 30, points: 36, icon: "chore_custom_childcare", color: DSColor.coral, themeKey: ChoreTheme.childcare.rawValue),
        ChoreItem(id: "daily-home-admin", name: "家庭管理", category: "家庭事务", minutes: 20, points: 22, icon: "chore_custom_admin", color: DSColor.lavender, themeKey: ChoreTheme.daily.rawValue),
    ]

    static let chores = coreChores + premiumChores + themedChores

    static let todayRecords: [ChoreRecord] = [
        ChoreRecord(id: "mock-record-dishes", memberName: "我", choreName: "洗碗收桌", category: "清洁", standardMinutes: 15, actualMinutes: 15, points: 21, note: "水槽终于重见天日", createdAt: Date().addingTimeInterval(-4_200), icon: "fork.knife", color: DSColor.yellow, creatorId: currentUser.id, identityLabel: "老妈", customIdentity: nil, avatarKey: "avatar_01", likeCount: 2, likedBy: [ActivityLiker(id: currentUser.id, displayName: "我", avatarKey: "avatar_01"), ActivityLiker(id: "mock-user-xia", displayName: "小夏", avatarKey: "avatar_02")], likedByMe: true, canDelete: true),
        ChoreRecord(id: "mock-record-mop", memberName: "小夏", choreName: "拖地清洁", category: "清洁", standardMinutes: 25, actualMinutes: 30, points: 48, note: "地板亮到能照出理想", createdAt: Date().addingTimeInterval(-2_700), icon: "drop.fill", color: DSColor.lavender, creatorId: "mock-user-xia", identityLabel: "室友", customIdentity: nil, avatarKey: "avatar_02", likeCount: 1, likedBy: [ActivityLiker(id: "mock-user-doudou", displayName: "豆豆", avatarKey: "avatar_03")], likedByMe: false, canDelete: true),
        ChoreRecord(id: "mock-record-trash", memberName: "豆豆", choreName: "倒垃圾 / 垃圾分类", category: "清洁", standardMinutes: 10, actualMinutes: 10, points: 10, note: "垃圾桶暂时恢复平静", createdAt: Date().addingTimeInterval(-1_100), icon: "trash.fill", color: DSColor.sky, creatorId: "mock-user-doudou", identityLabel: "妹妹", customIdentity: nil, avatarKey: "avatar_03", likeCount: 0, likedByMe: false, canDelete: true),
    ]

    static let monthlyReport = MonthlyReport(
        month: "2026-06",
        totalPoints: members.reduce(0) { $0 + $1.monthlyPoints },
        totalRecords: todayRecords.count,
        totalMinutes: todayRecords.reduce(0) { $0 + $1.actualMinutes },
        headline: "Mock 家庭劳动广播稳定播出",
        themeStats: [
            MonthlyReportTheme(themeKey: ChoreTheme.daily.rawValue, points: 156, recordCount: 6),
            MonthlyReportTheme(themeKey: ChoreTheme.love.rawValue, points: 50, recordCount: 2),
            MonthlyReportTheme(themeKey: ChoreTheme.childcare.rawValue, points: 40, recordCount: 2),
            MonthlyReportTheme(themeKey: ChoreTheme.pet.rawValue, points: 20, recordCount: 1),
        ],
        categoryStats: [
            MonthlyReportCategory(category: "烹饪", points: 88, recordCount: 4),
            MonthlyReportCategory(category: "清洁", points: 62, recordCount: 3),
            MonthlyReportCategory(category: "洗护", points: 36, recordCount: 2),
        ]
    )
}
