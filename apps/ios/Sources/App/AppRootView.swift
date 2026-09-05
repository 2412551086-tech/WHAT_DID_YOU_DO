import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        Group {
            switch viewModel.sessionState {
            case .restoringSession:
                LaunchLoadingView()
            case .unauthenticated, .authenticated:
                activeRoot
            }
        }
        .tint(DSColor.ink)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: viewModel.rootScreen)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: viewModel.sessionState)
    }

    @ViewBuilder
    private var activeRoot: some View {
        switch viewModel.rootScreen {
        case .onboarding:
            NavigationStack {
                OnboardingChoiceView()
            }
        case .login:
            NavigationStack {
                LoginView()
            }
        case .createFamily:
            NavigationStack {
                CreateFamilyView()
            }
        case .familyCreated:
            NavigationStack {
                CreateFamilySuccessView()
            }
        case .choreSetup:
            NavigationStack {
                ChoreRoutineEditorView(isInitialSetup: true)
            }
        case .joinFamily:
            NavigationStack {
                JoinFamilyView()
            }
        case .joinStatus:
            NavigationStack {
                JoinStatusView()
            }
        case .home:
            MainTabView()
        }
    }
}

private struct LaunchLoadingView: View {
    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 30, weight: .medium))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(DSColor.ink)
                    .frame(width: 58, height: 58)
                    .background(DSColor.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: DSColor.yellow.opacity(0.28), radius: 18, x: 0, y: 8)

                ProgressView()
                    .controlSize(.large)
                    .tint(DSColor.mutedInk)

                Text("正在恢复家庭战况…")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(DSColor.mutedInk)
            }
            .offset(y: -18)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("正在恢复家庭战况")
        .accessibilityIdentifier("launch-session-restoring")
    }
}

enum AppScreen: Hashable {
    case onboarding
    case login
    case createFamily
    case familyCreated
    case choreSetup
    case joinFamily
    case joinStatus
    case home
}
