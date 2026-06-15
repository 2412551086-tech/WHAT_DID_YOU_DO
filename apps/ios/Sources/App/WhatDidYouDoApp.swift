import SwiftUI

@main
struct WhatDidYouDoApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(viewModel)
        }
    }
}
