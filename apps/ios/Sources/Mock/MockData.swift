import SwiftUI

enum MockData {
    static let members: [FamilyMember] = [
        FamilyMember(name: "阿氧", points: 126, badge: "厨房战神", color: DSColor.yellow),
        FamilyMember(name: "小夏", points: 98, badge: "地板守护者", color: DSColor.mint),
        FamilyMember(name: "豆豆", points: 42, badge: "浇花小队长", color: DSColor.sky),
    ]

    static let chores: [ChoreItem] = [
        ChoreItem(name: "洗碗", category: "厨房类", minutes: 15, points: 15, icon: "fork.knife", color: DSColor.yellow),
        ChoreItem(name: "做饭", category: "厨房类", minutes: 45, points: 59, icon: "flame.fill", color: DSColor.coral),
        ChoreItem(name: "倒垃圾", category: "清洁类", minutes: 5, points: 5, icon: "trash.fill", color: DSColor.mint),
        ChoreItem(name: "扫地", category: "清洁类", minutes: 15, points: 15, icon: "sparkles", color: DSColor.sky),
        ChoreItem(name: "拖地", category: "清洁类", minutes: 20, points: 22, icon: "drop.fill", color: DSColor.lavender),
        ChoreItem(name: "洗衣服", category: "洗护类", minutes: 10, points: 10, icon: "washer.fill", color: DSColor.clay),
        ChoreItem(name: "晾衣服", category: "洗护类", minutes: 10, points: 10, icon: "wind", color: DSColor.mint),
        ChoreItem(name: "叠衣服", category: "洗护类", minutes: 20, points: 22, icon: "square.stack.3d.up.fill", color: DSColor.sky),
        ChoreItem(name: "清理卫生间", category: "清洁类", minutes: 30, points: 45, icon: "shower.fill", color: DSColor.lavender),
        ChoreItem(name: "浇花", category: "照顾类", minutes: 8, points: 8, icon: "leaf.fill", color: DSColor.mint),
    ]

    static let logs: [ChoreLog] = [
        ChoreLog(memberName: "阿氧", choreName: "洗碗", points: 15, note: "水槽终于重见天日"),
        ChoreLog(memberName: "小夏", choreName: "拖地", points: 22, note: "地板亮到能照出理想"),
        ChoreLog(memberName: "豆豆", choreName: "浇花", points: 8, note: "植物表示情绪稳定"),
    ]
}
