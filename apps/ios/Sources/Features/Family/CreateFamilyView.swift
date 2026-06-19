import SwiftUI

struct CreateFamilyView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("创建家庭")
                        .font(.appTitle())
                        .foregroundStyle(DSColor.ink)
                        .padding(.top, 16)

                    DSCard(fill: DSColor.mint) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("给家务现场起个响亮名字")
                                .font(.appHeadline())
                            Text("\(viewModel.modeLabel)：比如“周末厨房保卫处”或者“沙发塌陷研究所”。")
                                .font(.appBody(15))
                                .foregroundStyle(DSColor.mutedInk)
                        }
                    }

                    statusBanner

                    VStack(spacing: 16) {
                        DSTextField(title: "家庭名称", systemImage: "house.fill", text: $viewModel.familyName)

                        FamilyIdentityPicker(
                            identityLabel: $viewModel.selectedIdentityLabel,
                            customIdentity: $viewModel.customIdentity,
                            avatarKey: $viewModel.selectedAvatarKey
                        )

                        DSCard {
                            Toggle(isOn: $viewModel.requiresPhotoProof) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("需要图片凭证")
                                        .font(.appHeadline(18))
                                    Text("默认关闭，先相信家人，不先审讯家人。")
                                        .font(.appBody(14))
                                        .foregroundStyle(DSColor.mutedInk)
                                }
                            }
                            .tint(DSColor.coral)
                        }

                        DSButton(title: "创建并进入首页", systemImage: "arrow.right.circle.fill", style: .primary) {
                            viewModel.createFamily()
                        }

                        DSButton(title: "申请加入已有家庭", systemImage: "person.badge.plus", style: .secondary) {
                            viewModel.showJoinFamily()
                        }

                        DSButton(title: "切换账号", systemImage: "person.2.fill", style: .secondary) {
                            viewModel.logout()
                        }
                    }
                    .disabled(viewModel.isLoading)

                    DSCard(fill: DSColor.sky) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("MVP 规则")
                                .font(.appHeadline(18))
                            Text("先使用核心家务事项；Mock/API 模式可在 APIConfig 中切换。")
                                .font(.appBody(14))
                                .foregroundStyle(DSColor.mutedInk)
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if viewModel.isLoading {
            DSCard(fill: DSColor.sky) {
                Label(viewModel.loadingMessage ?? "正在处理", systemImage: "arrow.triangle.2.circlepath")
                    .font(.appBody(15))
                    .foregroundStyle(DSColor.ink)
            }
        }

        if let errorMessage = viewModel.errorMessage {
            DSCard(fill: DSColor.coral) {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.appBody(15))
                    .foregroundStyle(DSColor.ink)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CreateFamilyView()
            .environmentObject(AppViewModel(forceMockData: true))
    }
}
