import SwiftUI

struct JoinFamilyView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("申请加入家庭")
                        .font(.appTitle())
                        .foregroundStyle(DSColor.ink)
                        .padding(.top, 16)

                    if viewModel.joinRequestSubmitted {
                        waitingCard
                    } else {
                        formContent
                    }

                    statusBanner

                    DSButton(title: "返回创建家庭", systemImage: "arrow.left.circle.fill", style: .secondary) {
                        viewModel.showCreateFamily()
                    }
                    .disabled(viewModel.isLoading)

                    DSButton(title: "切换账号", systemImage: "person.2.fill", style: .secondary) {
                        viewModel.logout()
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding(20)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var formContent: some View {
        VStack(spacing: 16) {
            DSCard(fill: DSColor.mint) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("输入家庭邀请码")
                        .font(.appHeadline())
                    Text("请让一家之主在“我的”页面复制邀请码发给你。")
                        .font(.appBody(14))
                        .foregroundStyle(DSColor.mutedInk)
                }
            }

            DSTextField(
                title: "家庭邀请码",
                systemImage: "number.square.fill",
                text: $viewModel.joinInviteCode
            )

            FamilyIdentityPicker(
                identityLabel: $viewModel.selectedIdentityLabel,
                customIdentity: $viewModel.customIdentity,
                avatarKey: $viewModel.selectedAvatarKey
            )

            DSButton(title: "提交加入申请", systemImage: "paperplane.fill", style: .primary) {
                viewModel.submitJoinRequest()
            }
            .disabled(viewModel.isLoading)
        }
    }

    private var waitingCard: some View {
        DSCard(fill: DSColor.yellow) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "hourglass.circle.fill")
                    .font(.system(size: 42, weight: .black))
                Text("等待一家之主审核")
                    .font(.appHeadline(24))
                Text("申请已经送达。审核通过前，家庭动态和功劳簿暂时不会对你开放。")
                    .font(.appBody(15))
                    .foregroundStyle(DSColor.mutedInk)
            }
            .foregroundStyle(DSColor.ink)
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if viewModel.isLoading {
            DSCard(fill: DSColor.sky) {
                Label(viewModel.loadingMessage ?? "正在处理", systemImage: "arrow.triangle.2.circlepath")
                    .font(.appBody(15))
            }
        }

        if let errorMessage = viewModel.errorMessage {
            DSCard(fill: DSColor.coral) {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.appBody(15))
            }
        }
    }
}

#Preview {
    JoinFamilyView()
        .environmentObject(AppViewModel(forceMockData: true))
}
