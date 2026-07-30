import SwiftUI

struct JoinRequestsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("加入审核")
                        .font(.appTitle())
                        .foregroundStyle(DSColor.ink)

                    statusBanner

                    if viewModel.joinRequests.isEmpty && !viewModel.isLoading {
                        DSEmptyStateView(
                            title: "暂无待审核成员",
                            message: "家庭门口暂时很安静。",
                            systemImage: "checkmark.seal.fill"
                        )
                    }

                    ForEach(viewModel.joinRequests) { request in
                        requestCard(request)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("加入审核")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.loadJoinRequests()
        }
    }

    private func requestCard(_ request: JoinRequestItem) -> some View {
        DSCard(fill: DSColor.surface) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    AvatarView(avatarKey: request.avatarKey, fallbackText: request.displayName, size: 54)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(request.displayName)
                            .font(.appHeadline(19))
                        Text(request.displayIdentity)
                            .font(.appBody(14))
                            .foregroundStyle(DSColor.mutedInk)
                    }

                    Spacer()
                    DSBadge(text: "待审核")
                }

                HStack(spacing: 12) {
                    DSButton(title: "拒绝", systemImage: "xmark.circle.fill", style: .danger) {
                        viewModel.reviewJoinRequest(request, approve: false)
                    }
                    DSButton(title: "通过", systemImage: "checkmark.circle.fill", style: .primary) {
                        viewModel.reviewJoinRequest(request, approve: true)
                    }
                }
                .disabled(viewModel.isLoading)
            }
            .foregroundStyle(DSColor.ink)
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if viewModel.isLoading {
            DSLoadingStateView(message: viewModel.loadingMessage ?? "正在处理")
        }

        if let errorMessage = viewModel.errorMessage {
            DSErrorBanner(message: errorMessage)
        }
    }
}

#Preview {
    NavigationStack {
        JoinRequestsView()
            .environmentObject(AppViewModel.previewLoggedIn())
    }
}
