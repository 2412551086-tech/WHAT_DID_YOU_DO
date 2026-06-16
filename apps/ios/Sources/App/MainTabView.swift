import SwiftUI

enum MainTab: Hashable {
    case today
    case record
    case family
    case profile
}

struct MainTabView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("今日战况", systemImage: "sun.max.fill")
            }
            .tag(MainTab.today)

            NavigationStack {
                ChoreSelectionView()
            }
            .tabItem {
                Label("记一下", systemImage: "plus.circle.fill")
            }
            .tag(MainTab.record)

            NavigationStack {
                FamilyDashboardView()
            }
            .tabItem {
                Label("家庭战况", systemImage: "person.3.fill")
            }
            .tag(MainTab.family)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("我的", systemImage: "person.crop.circle.fill")
            }
            .tag(MainTab.profile)
        }
        .tint(DSColor.ink)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppViewModel.previewHomeAfterNewRecord())
}
