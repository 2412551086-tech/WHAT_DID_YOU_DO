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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var commonChoreDragCoordinator = CommonChoreDragCoordinator()

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $viewModel.selectedTab) {
                NavigationStack {
                    HomeView()
                }
                .tabItem {
                    Image(systemName: "calendar.badge.clock")
                        .accessibilityLabel("本周战况")
                }
                .tag(MainTab.today)

                NavigationStack {
                    ChoreSelectionView()
                }
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                        .accessibilityLabel("记一下")
                }
                .tag(MainTab.record)

                NavigationStack {
                    FamilyDashboardView()
                }
                .tabItem {
                    Image(systemName: "trophy.fill")
                        .accessibilityLabel("月度战报")
                }
                .tag(MainTab.family)

                NavigationStack {
                    ProfileView()
                }
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                        .accessibilityLabel("我的")
                }
                .tag(MainTab.profile)
            }
            .tint(DSColor.infoBlue)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)

            if commonChoreDragCoordinator.isActive {
                CommonChoreRemovalTarget(
                    isTargeted: commonChoreDragCoordinator.isTrashTargeted
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 4)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: CommonChoreRemovalFramePreferenceKey.self,
                            value: proxy.frame(in: .global)
                        )
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }

            if let celebration = viewModel.pendingAchievementCelebration {
                ZStack {
                    Color.black.opacity(0.24)
                        .ignoresSafeArea()
                        .onTapGesture(perform: viewModel.dismissAchievementCelebration)

                    AchievementCelebrationOverlay(
                        celebration: celebration,
                        dismiss: viewModel.dismissAchievementCelebration
                    )
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .environmentObject(commonChoreDragCoordinator)
        .animation(
            reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.86),
            value: commonChoreDragCoordinator.isActive
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.88),
            value: viewModel.pendingAchievementCelebration?.id
        )
        .onPreferenceChange(CommonChoreRemovalFramePreferenceKey.self) { frame in
            commonChoreDragCoordinator.trashFrame = frame
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: viewModel.selectedTab) { _, tab in
            if tab != .record {
                commonChoreDragCoordinator.end()
            }
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
