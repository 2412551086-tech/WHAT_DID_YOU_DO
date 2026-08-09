import SwiftUI

struct JoinRequestsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var rejectionCandidate: JoinRequestItem?

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                FamilyFlowTopBar(title: "加入申请") {
                    dismiss()
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        statusBanner

                        if viewModel.joinRequests.isEmpty && !viewModel.isLoading {
                            emptyState
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.joinRequests) { request in
                                    requestRow(request)
                                }
                            }

                            Text("已处理的申请不会继续显示在这里。")
                                .font(.system(size: 11))
                                .foregroundStyle(DSColor.mutedInk)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
                .refreshable {
                    viewModel.loadJoinRequests()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .task {
            viewModel.loadJoinRequests()
        }
        .confirmationDialog(
            rejectionCandidate.map { "拒绝\($0.displayName)的加入申请？" } ?? "拒绝加入申请？",
            isPresented: Binding(
                get: { rejectionCandidate != nil },
                set: { isPresented in
                    if !isPresented { rejectionCandidate = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("确认拒绝", role: .destructive) {
                if let request = rejectionCandidate {
                    viewModel.reviewJoinRequest(request, approve: false)
                }
                rejectionCandidate = nil
            }
            Button("取消", role: .cancel) {
                rejectionCandidate = nil
            }
        } message: {
            Text("拒绝后，对方需要重新提交申请。")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("审核通过后，成员才能查看家庭数据并记录家务。")
                    .font(.system(size: 12))
                    .foregroundStyle(DSColor.mutedInk)
                Spacer()
                Text("\(viewModel.joinRequests.count) 个待处理")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColor.ink)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(DSColor.choreYellowSurface)
                    .clipShape(Capsule())
            }
        }
    }

    private func requestRow(_ request: JoinRequestItem) -> some View {
        let isReviewing = viewModel.reviewingRequestID == request.id
        let rowError = viewModel.reviewErrors[request.id]

        return DSQuietCard(cornerRadius: 10, padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    AvatarView(
                        avatarKey: request.avatarKey,
                        fallbackText: request.displayName,
                        size: 48
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.displayName)
                            .font(.system(size: 15, weight: .semibold))
                        Text("\(request.displayIdentity) · \(relativeTime(request.createdAt))")
                            .font(.system(size: 11))
                            .foregroundStyle(DSColor.mutedInk)
                    }

                    Spacer(minLength: 8)

                    if isReviewing {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("处理中…")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(DSColor.mutedInk)
                    } else if rowError == nil {
                        reviewButtons(request)
                    }
                }

                if let rowError {
                    HStack {
                        Spacer()
                        Text("审核失败")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DSColor.coral)
                        Button("重试") {
                            viewModel.reviewJoinRequest(request, approve: true)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DSColor.coral)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(DSColor.coral.opacity(0.65), lineWidth: 1)
                        )
                    }
                    Text(rowError)
                        .font(.system(size: 10))
                        .foregroundStyle(DSColor.mutedInk)
                        .lineLimit(2)
                }
            }
        }
    }

    private func reviewButtons(_ request: JoinRequestItem) -> some View {
        HStack(spacing: 7) {
            Button {
                viewModel.reviewJoinRequest(request, approve: true)
            } label: {
                Label("通过", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(DSColor.ink)
                    .padding(.horizontal, 7)
                    .frame(height: 32)
                    .background(DSColor.choreMintSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(DSColor.mint.opacity(0.65), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Button {
                rejectionCandidate = request
            } label: {
                Label("拒绝", systemImage: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(DSColor.coral)
                    .padding(.horizontal, 7)
                    .frame(height: 32)
                    .background(DSColor.pureSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(DSColor.coral.opacity(0.45), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(DSColor.choreMintSurface)
                    .frame(width: 68, height: 68)
                Image(systemName: "checkmark")
                    .font(.system(size: 27, weight: .light))
                    .foregroundStyle(DSColor.mint)
            }

            Text("没有待审核申请")
                .font(.system(size: 20, weight: .semibold))
            Text("新的申请会显示在这里。")
                .font(.system(size: 12))
                .foregroundStyle(DSColor.mutedInk)

            FamilyFlowSecondaryButton(title: "返回我的") {
                dismiss()
            }
            .frame(maxWidth: 160)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 150)
    }

    @ViewBuilder
    private var statusBanner: some View {
        if viewModel.isLoading && viewModel.joinRequests.isEmpty {
            DSLoadingStateView(message: viewModel.loadingMessage ?? "正在获取加入申请")
        }
        if let errorMessage = viewModel.errorMessage {
            DSErrorBanner(message: errorMessage)
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview("待审核列表") {
    NavigationStack {
        JoinRequestsView()
            .environmentObject(AppViewModel.previewLoggedIn())
    }
}
