import SwiftUI

#if DEBUG
struct DebugPanel: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("DebugPanel", systemImage: "wrench.and.screwdriver.fill")
                .font(.appHeadline())
                .foregroundStyle(DSColor.ink)

            DSCard(fill: DSColor.lavender) {
                VStack(alignment: .leading, spacing: 12) {
                    row("当前模式", viewModel.modeLabel)
                    row("环境", viewModel.debugAPIEnvironment)
                    row("baseURL", viewModel.debugBaseURL, allowsWrapping: true)
                    row("家庭时区", viewModel.debugFamilyTimezone, allowsWrapping: true)
                    row("Token", viewModel.hasAccessToken ? "已保存" : "不存在")
                    row("最后请求", viewModel.lastRequestPath ?? "无", allowsWrapping: true)
                    row("状态码", viewModel.lastStatusCode.map(String.init) ?? "无")
                    row("最后错误", viewModel.lastAPIErrorMessage ?? "无", allowsWrapping: true)
                    row("安全存储", viewModel.lastSecureStorageErrorMessage ?? "正常", allowsWrapping: true)
                }
            }
        }
    }

    private func row(_ title: String, _ value: String, allowsWrapping: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appBody(12))
                .foregroundStyle(DSColor.mutedInk)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(DSColor.ink)
                .lineLimit(allowsWrapping ? 3 : 1)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
