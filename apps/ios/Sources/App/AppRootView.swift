import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        Group {
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
        .tint(DSColor.ink)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: viewModel.rootScreen)
    }
}

enum AppScreen: Hashable {
    case login
    case createFamily
    case joinFamily
    case home
}
