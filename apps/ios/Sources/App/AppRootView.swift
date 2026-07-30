import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        Group {
            switch viewModel.sessionState {
            case .restoringSession:
                LaunchLoadingView()
            case .unauthenticated:
                NavigationStack {
                    LoginView()
                }
            case .authenticated:
                authenticatedRoot
            }
        }
        .tint(DSColor.ink)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: viewModel.rootScreen)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: viewModel.sessionState)
    }

    @ViewBuilder
    private var authenticatedRoot: some View {
        switch viewModel.rootScreen {
        case .login:
            NavigationStack {
                LoginView()
            }
        case .createFamily:
            NavigationStack {
                CreateFamilyView()
            }
        case .joinFamily:
            NavigationStack {
                JoinFamilyView()
            }
        case .home:
            MainTabView()
        }
    }
}

private struct LaunchLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在恢复家庭战况…")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum AppScreen: Hashable {
    case login
    case createFamily
    case joinFamily
    case home
}
