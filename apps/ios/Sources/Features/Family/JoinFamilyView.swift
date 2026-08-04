import SwiftUI
import UIKit

struct JoinFamilyView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private var inviteCodeBinding: Binding<String> {
        Binding(
            get: { viewModel.joinInviteCode },
            set: { value in
                viewModel.joinInviteCode = String(
                    value
                        .uppercased()
                        .filter { $0.isLetter || $0.isNumber }
                        .prefix(8)
                )
            }
        )
    }

    private var canSubmit: Bool {
        guard case .valid = viewModel.inviteValidationState else { return false }
        return !viewModel.isLoading
    }

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                FamilyFlowTopBar(title: "加入家庭") {
                    viewModel.showCreateFamily()
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("输入家人分享的邀请码，申请加入家庭")
                            .font(.system(size: 13))
                            .foregroundStyle(DSColor.mutedInk)

                        invitationSection
                        nicknameSection

                        FamilyIdentityPicker(
                            identityLabel: $viewModel.selectedIdentityLabel,
                            customIdentity: $viewModel.customIdentity,
                            avatarKey: $viewModel.selectedAvatarKey
                        )

                        statusBanner

                        FamilyFlowPrimaryButton(
                            title: "提交加入申请",
                            isEnabled: canSubmit
                        ) {
                            viewModel.submitJoinRequest()
                        }

                        Button("切换账号") {
                            viewModel.logout()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DSColor.mutedInk)
                        .frame(maxWidth: .infinity)
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task(id: viewModel.joinInviteCode) {
            guard viewModel.joinInviteCode.count == 8 else {
                viewModel.validateJoinInviteCode()
                return
            }

            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }
            viewModel.validateJoinInviteCode()
        }
    }

    private var invitationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FamilyFlowSectionLabel(title: "家庭邀请码")

            HStack(spacing: 8) {
                TextField("8 位邀请码", text: inviteCodeBinding)
                    .font(.system(size: 19, weight: .medium, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                Button("粘贴") {
                    if let value = UIPasteboard.general.string {
                        inviteCodeBinding.wrappedValue = value
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DSColor.infoBlue)

                if !viewModel.joinInviteCode.isEmpty {
                    Button {
                        viewModel.joinInviteCode = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DSColor.mutedInk.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清空邀请码")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(DSColor.pureSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(inviteBorderColor, lineWidth: 1)
            )
            .shadow(color: DSColor.ink.opacity(0.06), radius: 8, y: 3)

            inviteValidationView
        }
    }

    @ViewBuilder
    private var inviteValidationView: some View {
        switch viewModel.inviteValidationState {
        case .idle:
            EmptyView()
        case .validating:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("正在查找家庭…")
            }
            .font(.system(size: 12))
            .foregroundStyle(DSColor.mutedInk)
        case let .valid(family):
            DSQuietCard(fill: Color(red: 0.96, green: 0.99, blue: 0.95), cornerRadius: 8, padding: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(family.name)
                            .font(.system(size: 15, weight: .semibold))
                        if let owner = family.owner {
                            Text("一家之主：\(owner.displayName)")
                                .font(.system(size: 12))
                                .foregroundStyle(DSColor.mutedInk)
                        }
                        Text("\(family.memberCount) 位成员")
                            .font(.system(size: 12))
                            .foregroundStyle(DSColor.mutedInk)
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(red: 0.12, green: 0.62, blue: 0.28))
                        Text("邀请码有效")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(red: 0.12, green: 0.62, blue: 0.28))
                    }
                }
            }
        case let .invalid(message):
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.78, green: 0.18, blue: 0.17))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 1.0, green: 0.91, blue: 0.91))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FamilyFlowSectionLabel(title: "你的昵称")

            HStack(spacing: 10) {
                Image(systemName: "person")
                    .foregroundStyle(DSColor.mutedInk)
                Text(viewModel.currentUserName)
                    .font(.system(size: 16))
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(DSColor.pureSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DSColor.subtleStroke, lineWidth: 1)
            )
        }
    }

    private var inviteBorderColor: Color {
        switch viewModel.inviteValidationState {
        case .valid:
            return Color(red: 0.30, green: 0.68, blue: 0.36)
        case .invalid:
            return Color(red: 0.84, green: 0.31, blue: 0.29)
        default:
            return DSColor.subtleStroke
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if viewModel.isLoading {
            DSLoadingStateView(message: viewModel.loadingMessage ?? "正在提交申请")
        }
        if let errorMessage = viewModel.errorMessage {
            DSErrorBanner(message: errorMessage)
        }
    }
}

struct JoinStatusView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                FamilyFlowTopBar(title: pageTitle) {
                    viewModel.logout()
                }

                ScrollView {
                    VStack(spacing: 18) {
                        if let application = viewModel.currentJoinApplication {
                            applicationCard(application)
                            statusActions(application)
                        } else if viewModel.isLoading {
                            DSLoadingStateView(message: viewModel.loadingMessage ?? "正在查询审核状态")
                        } else {
                            DSEmptyStateView(
                                title: "没有找到加入申请",
                                message: "可以返回重新输入家庭邀请码。",
                                systemImage: "person.crop.circle.badge.questionmark"
                            )
                            FamilyFlowSecondaryButton(title: "重新申请") {
                                viewModel.showJoinFamily()
                            }
                        }

                        if let errorMessage = viewModel.errorMessage {
                            DSErrorBanner(message: errorMessage)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 26)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            if viewModel.currentJoinApplication?.status == .pending {
                viewModel.refreshJoinStatus()
            }
        }
    }

    private var pageTitle: String {
        switch viewModel.currentJoinApplication?.status {
        case .active: return "审核通过"
        case .rejected: return "申请未通过"
        default: return "等待审核"
        }
    }

    private func applicationCard(_ application: JoinApplication) -> some View {
        DSQuietCard(cornerRadius: 10, padding: 18) {
            VStack(spacing: 14) {
                Image(
                    application.status == .pending
                        ? "join_status_pending_illustration"
                        : FamilyIdentityOptions.actionAsset(for: application.avatarKey ?? "avatar_01")
                )
                    .resizable()
                    .scaledToFit()
                    .frame(height: 220)
                    .accessibilityHidden(true)

                HStack(spacing: 10) {
                    AvatarView(
                        avatarKey: application.avatarKey,
                        fallbackText: viewModel.currentUserName,
                        size: 44
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.currentUserName)
                            .font(.system(size: 16, weight: .semibold))
                        Text("申请于 \(application.createdAt.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 11))
                            .foregroundStyle(DSColor.mutedInk)
                    }
                    Spacer()
                }

                Divider()

                detailRow(systemImage: "house.fill", title: "家庭名称", value: application.family.name)
                Divider()
                detailRow(systemImage: "person.text.rectangle", title: "所选身份", value: application.displayIdentity)
                Divider()

                statusContent(application.status)
            }
        }
    }

    private func detailRow(systemImage: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(DSColor.mutedInk)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(DSColor.mutedInk)
                Text(value)
                    .font(.system(size: 14, weight: .medium))
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func statusContent(_ status: FamilyMemberStatus) -> some View {
        switch status {
        case .pending:
            VStack(alignment: .leading, spacing: 10) {
                Label("等待一家之主审核", systemImage: "clock")
                    .foregroundStyle(Color(red: 0.56, green: 0.42, blue: 0.12))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color(red: 1.0, green: 0.96, blue: 0.81))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text("回到 App 前台时会自动刷新，也可以手动检查。")
                    .font(.system(size: 11))
                    .foregroundStyle(DSColor.mutedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .active:
            VStack(alignment: .leading, spacing: 7) {
                Label("已加入家庭", systemImage: "checkmark.circle")
                    .foregroundStyle(Color(red: 0.12, green: 0.62, blue: 0.28))
                Text("一家之主已通过你的申请。")
                    .font(.system(size: 15, weight: .semibold))
                Text("现在可以查看家庭战况并记录家务了。")
                    .font(.system(size: 12))
                    .foregroundStyle(DSColor.mutedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .rejected:
            VStack(alignment: .leading, spacing: 7) {
                Label("已拒绝", systemImage: "xmark.circle")
                    .foregroundStyle(Color(red: 0.78, green: 0.18, blue: 0.17))
                Text("这次申请没有通过。")
                    .font(.system(size: 15, weight: .semibold))
                Text("可以确认邀请码和身份后重新申请，或切换账号。")
                    .font(.system(size: 12))
                    .foregroundStyle(DSColor.mutedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func statusActions(_ application: JoinApplication) -> some View {
        switch application.status {
        case .pending:
            FamilyFlowSecondaryButton(title: "刷新状态", systemImage: "arrow.clockwise") {
                viewModel.refreshJoinStatus()
            }
            .disabled(viewModel.isLoading)
            Button("切换账号") { viewModel.logout() }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DSColor.mutedInk)
        case .active:
            FamilyFlowPrimaryButton(title: "进入本周战况", isEnabled: !viewModel.isLoading) {
                viewModel.enterApprovedFamily()
            }
            Button("稍后进入") { viewModel.enterApprovedFamily() }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DSColor.mutedInk)
        case .rejected:
            FamilyFlowSecondaryButton(title: "重新申请", systemImage: "arrow.clockwise") {
                viewModel.retryRejectedJoinRequest()
            }
            Button("切换账号") { viewModel.logout() }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DSColor.mutedInk)
        }
    }
}

#Preview("加入家庭") {
    JoinFamilyView()
        .environmentObject(AppViewModel(forceMockData: true))
}

#Preview("等待审核") {
    JoinStatusView()
        .environmentObject(AppViewModel.previewJoinStatus(.pending))
}

#Preview("审核通过") {
    JoinStatusView()
        .environmentObject(AppViewModel.previewJoinStatus(.active))
}

#Preview("申请被拒") {
    JoinStatusView()
        .environmentObject(AppViewModel.previewJoinStatus(.rejected))
}
