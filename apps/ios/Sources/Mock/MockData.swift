import SwiftUI

enum MockData {
    static let currentUser = AppUser(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        displayName: "我",
        avatarInitial: "我",
        badge: "今日值班观察员"
    )

    static let family = FamilySpace(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
        name: "今日劳动观察站",
        inviteCode: "WDYD88",
        requiresPhotoProof: false
    )

    static let members: [FamilyMember] = [
        FamilyMember(id: currentUser.id, name: "我", monthlyPoints: 126, badge: "厨房战神", color: DSColor.yellow),
        FamilyMember(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "小夏", monthlyPoints: 98, badge: "地板守护者", color: DSColor.mint),
        FamilyMember(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "豆豆", monthlyPoints: 42, badge: "浇花小队长", color: DSColor.sky),
    ]

    static let chores: [ChoreItem] = [
        ChoreItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000001001")!, name: "洗碗", category: "厨房类", minutes: 15, points: 15, icon: "fork.knife", color: DSColor.yellow),
        ChoreItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000001002")!, name: "做饭", category: "厨房类", minutes: 45, points: 59, icon: "flame.fill", color: DSColor.coral),
        ChoreItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000001003")!, name: "倒垃圾", category: "清洁类", minutes: 5, points: 5, icon: "trash.fill", color: DSColor.mint),
        ChoreItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000001004")!, name: "扫地", category: "清洁类", minutes: 15, points: 15, icon: "sparkles", color: DSColor.sky),
        ChoreItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000001005")!, name: "拖地", category: "清洁类", minutes: 20, points: 22, icon: "drop.fill", color: DSColor.lavender),
        ChoreItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000001006")!, name: "洗衣服", category: "洗护类", minutes: 10, points: 10, icon: "washer.fill", color: DSColor.clay),
        ChoreItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000001007")!, name: "晾衣服", category: "洗护类", minutes: 10, points: 10, icon: "wind", color: DSColor.mint),
        ChoreItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000001008")!, name: "叠衣服", category: "洗护类", minutes: 20, points: 22, icon: "square.stack.3d.up.fill", color: DSColor.sky),
        ChoreItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000001009")!, name: "清理卫生间", category: "清洁类", minutes: 30, points: 45, icon: "shower.fill", color: DSColor.lavender),
        ChoreItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000001010")!, name: "浇花", category: "照顾类", minutes: 8, points: 8, icon: "leaf.fill", color: DSColor.mint),
    ]

    static let todayRecords: [ChoreRecord] = [
        ChoreRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000002001")!, memberName: "我", choreName: "洗碗", category: "厨房类", standardMinutes: 15, actualMinutes: 15, points: 15, note: "水槽终于重见天日", createdAt: Date().addingTimeInterval(-4_200), icon: "fork.knife", color: DSColor.yellow),
        ChoreRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000002002")!, memberName: "小夏", choreName: "拖地", category: "清洁类", standardMinutes: 20, actualMinutes: 24, points: 26, note: "地板亮到能照出理想", createdAt: Date().addingTimeInterval(-2_700), icon: "drop.fill", color: DSColor.lavender),
        ChoreRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000002003")!, memberName: "豆豆", choreName: "浇花", category: "照顾类", standardMinutes: 8, actualMinutes: 8, points: 8, note: "植物表示情绪稳定", createdAt: Date().addingTimeInterval(-1_100), icon: "leaf.fill", color: DSColor.mint),
    ]
}
