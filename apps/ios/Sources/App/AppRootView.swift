import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            LoginView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .createFamily:
                        CreateFamilyView()
                    case .home:
                        MainTabView()
                    case .choreSelection:
                        ChoreSelectionView()
                    }
                }
        }
        .tint(DSColor.ink)
    }
}

enum AppRoute: Hashable {
    case createFamily
    case home
    case choreSelection
}
