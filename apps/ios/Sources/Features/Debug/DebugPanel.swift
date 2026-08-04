import SwiftUI

#if DEBUG
struct DebugPanel: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("DebugPanel", systemImage: "wrench.and.screwdriver.fill")
                .font(.appHeadline())
                .foregroundStyle(DSColor.ink)

            DSDebugPanel(rows: rows)

            NavigationLink {
                FeedbackStatesView()
            } label: {
                Label("检查状态组件", systemImage: "rectangle.3.group")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DSColor.infoBlue)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private var rows: [DSDebugPanel.Row] {
        [
            DSDebugPanel.Row(title: "当前模式", value: viewModel.modeLabel),
            DSDebugPanel.Row(title: "环境", value: viewModel.debugAPIEnvironment),
            DSDebugPanel.Row(title: "baseURL", value: viewModel.debugBaseURL, allowsWrapping: true),
            DSDebugPanel.Row(title: "家庭时区", value: viewModel.debugFamilyTimezone, allowsWrapping: true),
            DSDebugPanel.Row(title: "Token", value: viewModel.hasAccessToken ? "已保存" : "不存在"),
            DSDebugPanel.Row(title: "最后请求", value: viewModel.lastRequestPath ?? "无", allowsWrapping: true),
            DSDebugPanel.Row(title: "状态码", value: viewModel.lastStatusCode.map(String.init) ?? "无"),
            DSDebugPanel.Row(title: "最后错误", value: viewModel.lastAPIErrorMessage ?? "无", allowsWrapping: true),
            DSDebugPanel.Row(title: "安全存储", value: viewModel.lastSecureStorageErrorMessage ?? "正常", allowsWrapping: true),
        ]
    }
}

struct FeedbackStatesView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var retryCount = 0

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    stateSection("请求失败") {
                        DSRequestFailureView(
                            title: "家庭动态加载失败",
                            message: "网络开了个小差，请稍后再试。"
                        ) {
                            retryCount += 1
                        }

                        if retryCount > 0 {
                            Text("已触发重试 \(retryCount) 次")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(DSColor.mutedInk)
                                .accessibilityIdentifier("state-preview-retry-result")
                        }
                    }

                    stateSection("离线模式") {
                        DSOfflineStatusView(lastUpdatedAt: Date())
                    }

                    stateSection("空状态") {
                        DSEmptyStateView(
                            title: "今天还没有人记功",
                            message: "第一笔家务，等你来打响。",
                            avatarKey: "avatar_08",
                            actionTitle: "去记一下",
                            actionSystemImage: "plus.circle"
                        ) {
                            viewModel.showChoreSelection()
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("状态组件")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func stateSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(DSColor.ink)
            content()
        }
    }
}

#Preview {
    ScrollView {
        DebugPanel()
            .environmentObject(AppViewModel.previewLoggedIn())
            .padding(20)
    }
    .background(DSColor.background)
}

#Preview("状态组件") {
    NavigationStack {
        FeedbackStatesView()
            .environmentObject(AppViewModel.previewHomeAfterNewRecord())
    }
}
#endif
