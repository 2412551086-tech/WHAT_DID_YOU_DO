import SwiftUI

@main
struct WhatDidYouDoApp: App {
    @StateObject private var viewModel = AppViewModel()
    @AppStorage(AppAppearance.storageKey) private var appearanceRawValue = AppAppearance.system.rawValue

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(viewModel)
                .preferredColorScheme(appearance.preferredColorScheme)
        }
    }

    private var appearance: AppAppearance {
        AppAppearance.resolve(appearanceRawValue)
    }
}
