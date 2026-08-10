import SwiftUI
import UIKit

struct CreateFamilyView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                FamilyFlowTopBar(title: "创建家庭") {
                    viewModel.logout()
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        familyNameSection
                        nicknameSection

                        FamilyIdentityPicker(
                            identityLabel: $viewModel.selectedIdentityLabel,
                            customIdentity: $viewModel.customIdentity,
                            avatarKey: $viewModel.selectedAvatarKey
                        )

                        photoProofNotice
                        statusBanner

                        FamilyFlowPrimaryButton(
                            title: "创建家庭",
                            isEnabled: !viewModel.isLoading
                        ) {
                            viewModel.createFamily()
                        }

                        Button("已有家庭？申请加入") {
                            viewModel.showJoinFamily()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DSColor.mutedInk)
                        .frame(maxWidth: .infinity)
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var familyNameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FamilyFlowSectionLabel(title: "家庭名称")
            FamilyFlowTextField(
                placeholder: "给家庭起个名字",
                text: $viewModel.familyName
            )
        }
    }

    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FamilyFlowSectionLabel(title: "你的昵称")
            FamilyFlowTextField(
                placeholder: "输入你的昵称",
                systemImage: "person",
                text: $viewModel.displayName
            )
        }
    }

    private var photoProofNotice: some View {
        HStack(spacing: 7) {
            Image(systemName: "photo")
            Text("图片凭证 · 即将开放")
        }
        .font(.system(size: 12))
        .foregroundStyle(DSColor.mutedInk.opacity(0.72))
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var statusBanner: some View {
        if viewModel.isLoading {
            DSLoadingStateView(message: viewModel.loadingMessage ?? "正在创建家庭")
        }

        if let errorMessage = viewModel.errorMessage {
            DSErrorBanner(message: errorMessage)
        }
    }
}

struct CreateFamilySuccessView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var copied = false

    private var family: FamilySpace {
        viewModel.currentFamily ?? MockData.family
    }

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    successHeader
                    invitationCard
                    ownerCard
                    statusBanner

                    FamilyFlowPrimaryButton(
                        title: "进入本周战况",
                        isEnabled: !viewModel.isLoading
                    ) {
                        viewModel.enterCreatedFamily()
                    }

                    Button("稍后邀请") {
                        viewModel.enterCreatedFamily()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DSColor.mutedInk)
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 34)
                .padding(.bottom, 30)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var successHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(DSColor.yellow)
                    .frame(width: 58, height: 58)
                    .shadow(color: DSColor.shadow.opacity(0.10), radius: 10, y: 4)
                Image(systemName: "checkmark")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("家庭建好了")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(DSColor.ink)
            Text("第一支家庭战队，正式集合。")
                .font(.system(size: 14))
                .foregroundStyle(DSColor.mutedInk)
        }
    }

    private var invitationCard: some View {
        DSQuietCard(cornerRadius: 10, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Text(family.name)
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                    Image(systemName: "medal.fill")
                        .font(.system(size: 34))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(DSColor.yellow, Color(red: 0.97, green: 0.48, blue: 0.58))
                }

                Text(family.inviteCode)
                    .font(.system(size: 33, weight: .medium, design: .monospaced))
                    .tracking(6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(DSColor.quietBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(DSColor.subtleStroke, lineWidth: 1)
                    )

                Text("使用邀请码可申请加入，仍需一家之主审核。")
                    .font(.system(size: 12))
                    .foregroundStyle(DSColor.mutedInk)

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = family.inviteCode
                        copied = true
                    } label: {
                        Label(copied ? "已复制" : "复制邀请码", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(DSColor.pureSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(copied ? DSColor.mint : DSColor.subtleStroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: "加入我的家庭「\(family.name)」，邀请码：\(family.inviteCode)") {
                        Label("分享", systemImage: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(DSColor.pureSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(DSColor.subtleStroke, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private var ownerCard: some View {
        DSQuietCard(cornerRadius: 10, padding: 14) {
            HStack(spacing: 12) {
                AvatarView(
                    avatarKey: viewModel.currentMembership?.avatarKey,
                    fallbackText: viewModel.currentUserName,
                    size: 50
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.currentUserName)
                        .font(.system(size: 16, weight: .semibold))
                    Text(viewModel.currentIdentityDisplayName)
                        .font(.system(size: 13))
                        .foregroundStyle(DSColor.mutedInk)
                }

                Spacer()

                Label("一家之主", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DSColor.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(DSColor.redSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if viewModel.isLoading {
            DSLoadingStateView(message: viewModel.loadingMessage ?? "正在进入家庭")
        }
        if let errorMessage = viewModel.errorMessage {
            DSErrorBanner(message: errorMessage)
        }
    }
}

#Preview("创建家庭") {
    CreateFamilyView()
        .environmentObject(AppViewModel(forceMockData: true))
}

#Preview("创建成功") {
    CreateFamilySuccessView()
        .environmentObject(AppViewModel.previewLoggedIn())
}
