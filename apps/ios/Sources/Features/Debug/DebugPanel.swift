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

#Preview {
    ScrollView {
        DebugPanel()
            .environmentObject(AppViewModel.previewLoggedIn())
            .padding(20)
    }
    .background(DSColor.background)
}
#endif
