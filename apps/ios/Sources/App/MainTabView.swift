import SwiftUI

enum MainTab: Hashable {
    case today
    case record
    case family
    case profile
}

struct MainTabView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("本周战况", systemImage: "calendar.badge.clock")
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
                Label("月度战报", systemImage: "trophy.fill")
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
        .tint(DSColor.infoBlue)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .onChange(of: viewModel.selectedTab) { _, tab in
            guard tab == .record || tab == .profile else { return }
            Task { await viewModel.refreshCurrentFamilyMembership() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await viewModel.refreshCurrentFamilyMembership() }
        }
        .task(id: viewModel.selectedTab) {
            guard viewModel.selectedTab == .record || viewModel.selectedTab == .profile else {
                return
            }

            while !Task.isCancelled {
                await viewModel.refreshCurrentFamilyMembership()
                do {
                    try await Task.sleep(for: .seconds(8))
                } catch {
                    return
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppViewModel.previewHomeAfterNewRecord())
}
