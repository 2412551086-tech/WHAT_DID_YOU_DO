import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published var selectedTab: MainTab = .today
    @Published var phoneNumber = ""
    @Published var familyName = MockData.family.name
    @Published var requiresPhotoProof = false
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var currentFamily: FamilySpace?
    @Published private(set) var chores = MockData.chores
    @Published private(set) var todayRecords = MockData.todayRecords
    @Published private(set) var monthlyRanking = MockData.members
    @Published var selectedChore: ChoreItem?

    var familyDisplayName: String {
        currentFamily?.name ?? familyName
    }

    var currentUserName: String {
        currentUser?.displayName ?? MockData.currentUser.displayName
    }

    var todayPoints: Int {
        todayRecords.reduce(0) { $0 + $1.points }
    }

    var todayRecordCount: Int {
        todayRecords.count
    }

    var leader: FamilyMember? {
        monthlyRanking.max { $0.monthlyPoints < $1.monthlyPoints }
    }

    func mockLogin() {
        currentUser = MockData.currentUser
        path = [.createFamily]
    }

    func createFamily() {
        currentFamily = FamilySpace(
            id: MockData.family.id,
            name: familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? MockData.family.name : familyName,
            inviteCode: MockData.family.inviteCode,
            requiresPhotoProof: requiresPhotoProof
        )
        selectedTab = .today
        path = [.createFamily, .home]
    }

    func showChoreSelection() {
        selectedTab = .record
    }

    func record(_ chore: ChoreItem) {
        selectedChore = chore

        let record = ChoreRecord(
            id: UUID(),
            memberName: currentUserName,
            choreName: chore.name,
            category: chore.category,
            minutes: chore.minutes,
            points: chore.points,
            note: "\(chore.name)完成，家务宇宙记一笔",
            createdAt: Date(),
            icon: chore.icon,
            color: chore.color
        )

        todayRecords.insert(record, at: 0)
        addMonthlyPoints(chore.points, to: currentUserName)
        selectedTab = .today
        path.removeAll { $0 == .choreSelection }
    }

    func logout() {
        currentUser = nil
        currentFamily = nil
        selectedChore = nil
        selectedTab = .today
        phoneNumber = ""
        path = []
    }

    private func addMonthlyPoints(_ points: Int, to memberName: String) {
        if let index = monthlyRanking.firstIndex(where: { $0.id == currentUser?.id || $0.name == memberName }) {
            monthlyRanking[index].monthlyPoints += points
        } else {
            monthlyRanking.insert(
                FamilyMember(id: currentUser?.id ?? UUID(), name: memberName, monthlyPoints: points, badge: "新晋家务选手", color: DSColor.yellow),
                at: 0
            )
        }

        monthlyRanking.sort { $0.monthlyPoints > $1.monthlyPoints }
    }

    static func previewLoggedIn() -> AppViewModel {
        let viewModel = AppViewModel()
        viewModel.currentUser = MockData.currentUser
        viewModel.currentFamily = MockData.family
        return viewModel
    }

    static func previewHomeAfterNewRecord() -> AppViewModel {
        let viewModel = previewLoggedIn()
        viewModel.record(MockData.chores[1])
        return viewModel
    }
}
