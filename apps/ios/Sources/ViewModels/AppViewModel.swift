import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published var phoneNumber = ""
    @Published var familyName = "今日劳动观察站"
    @Published var requiresPhotoProof = false
    @Published private(set) var members = MockData.members
    @Published private(set) var chores = MockData.chores
    @Published private(set) var logs = MockData.logs
    @Published var selectedChore: ChoreItem?

    var todayPoints: Int {
        logs.reduce(0) { $0 + $1.points }
    }

    var leader: FamilyMember? {
        members.max { $0.points < $1.points }
    }

    func continueFromLogin() {
        path.append(.createFamily)
    }

    func createFamily() {
        path.append(.home)
    }

    func showChoreSelection() {
        path.append(.choreSelection)
    }

    func record(_ chore: ChoreItem) {
        selectedChore = chore
        logs.insert(
            ChoreLog(memberName: "我", choreName: chore.name, points: chore.points, note: "刚刚完成，家务宇宙记一笔"),
            at: 0
        )
        path.removeAll { $0 == .choreSelection }
    }
}
