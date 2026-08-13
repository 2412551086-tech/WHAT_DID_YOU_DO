import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(AppAppearance.storageKey) private var appearanceRawValue = AppAppearance.system.rawValue
    @State private var didCopyInviteCode = false
    @State private var isDebugExpanded = false
    @State private var isShowingLogoutConfirmation = false
    @State private var isShowingLeaveFamilyConfirmation = false
    @State private var isShowingOwnerLeaveGuidance = false
    @State private var isShowingPremiumRedemption = false
    @State private var isEditingFamilyName = false
    @State private var familyNameDraft = ""
    @State private var isEditingDisplayName = false
    @State private var displayNameDraft = ""

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    identityCard
                    familySection
                    if let errorMessage = viewModel.errorMessage {
                        DSErrorBanner(message: errorMessage)
                    }
                    membersSection
                    accountSection
                    appearanceSection

                    #if DEBUG
                    debugSection
                    #endif

                    leaveFamilyButton
                    logoutButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 108)
            }
            .refreshable {
                await viewModel.refreshCurrentFamilyMembership()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .confirmationDialog(
            "确认退出登录？",
            isPresented: $isShowingLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("退出登录", role: .destructive) {
                viewModel.logout()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("退出后会清除本机登录状态，不会删除家庭数据。")
        }
        .confirmationDialog(
            "确认退出当前家庭？",
            isPresented: $isShowingLeaveFamilyConfirmation,
            titleVisibility: .visible
        ) {
            Button("退出当前家庭", role: .destructive) {
                Task { _ = await viewModel.leaveCurrentFamily() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("退出后将看不到该家庭的战况；已经创建的家务记录仍会保留。")
        }
        .alert("暂时不能退出家庭", isPresented: $isShowingOwnerLeaveGuidance) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("一家之主需要先在家庭成员详情中把身份转让给另一位成员，然后才能退出当前家庭。")
        }
        .sheet(isPresented: $isShowingPremiumRedemption) {
            PremiumUpgradeSheet(trigger: .profile)
                .environmentObject(viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("修改家庭名称", isPresented: $isEditingFamilyName) {
            TextField("家庭名称", text: $familyNameDraft)
            Button("取消", role: .cancel) {}
            Button("保存") {
                Task { _ = await viewModel.updateFamilyName(familyNameDraft) }
            }
        } message: {
            Text("家庭名称最多 30 个字，修改后所有家庭成员都会看到新名称。")
        }
        .alert("修改昵称", isPresented: $isEditingDisplayName) {
            TextField("昵称", text: $displayNameDraft)
            Button("取消", role: .cancel) {}
            Button("保存") {
                Task { _ = await viewModel.updateDisplayName(displayNameDraft) }
            }
        } message: {
            Text("昵称最多 30 个字，修改后会同步显示在家庭动态和成员列表中。")
        }
    }

    private var identityCard: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) {
                    userIdentity
                }
            } else {
                HStack(spacing: 16) {
                    profileAvatar
                    identityCopy
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 112)
        .background(identityCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DSColor.raisedHighlight, lineWidth: 1)
        )
    }

    private var identityCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(ProfilePalette.identitySurface)
            .overlay(alignment: .bottomTrailing) {
                ProfilePetalDecoration()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .shadow(color: DSColor.shadow.opacity(0.10), radius: 13, x: 0, y: 7)
    }

    private var userIdentity: some View {
        HStack(spacing: 16) {
            profileAvatar
            identityCopy
        }
    }

    private var profileAvatar: some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarView(
                avatarKey: viewModel.currentMembership?.avatarKey,
                fallbackText: viewModel.currentUser?.avatarInitial ?? "我",
                size: 88,
                presentation: .flat
            )
            .padding(4)
            .background(DSColor.pureSurface.opacity(0.92))
            .clipShape(Circle())

            if viewModel.isCurrentUserOwner {
                OwnerRoleBadge(compact: true)
                    .offset(x: 8, y: 3)
            }
        }
        .accessibilityLabel("我的头像")
    }

    private var identityCopy: some View {
        VStack(alignment: .leading, spacing: 7) {
            familyNameControl

            Text(viewModel.currentIdentityDisplayName)
                .font(.system(size: 17, weight: .medium, design: .default))
                .foregroundStyle(DSColor.ink)

            Button {
                displayNameDraft = viewModel.currentUserName
                isEditingDisplayName = true
            } label: {
                HStack(spacing: 6) {
                    Text(viewModel.currentUserName)
                        .lineLimit(1)
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundStyle(DSColor.mutedInk)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("昵称，\(viewModel.currentUserName)，点击修改")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var familyNameControl: some View {
        if viewModel.isCurrentUserOwner {
            Button {
                familyNameDraft = viewModel.familyDisplayName
                isEditingFamilyName = true
            } label: {
                HStack(spacing: 6) {
                    Text(viewModel.familyDisplayName)
                        .lineLimit(2)
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DSColor.mutedInk)
                }
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundStyle(DSColor.ink)
                .multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("家庭名称，\(viewModel.familyDisplayName)，点击修改")
        } else {
            Text(viewModel.familyDisplayName)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundStyle(DSColor.ink)
                .lineLimit(2)
        }
    }

    private var familySection: some View {
        ProfileGroupCard {
            inviteCodeRow

            Divider().padding(.leading, 48)

            NavigationLink {
                AppearanceSelectionView()
            } label: {
                ProfileAppearanceRow(
                    avatarKey: viewModel.currentMembership?.avatarKey,
                    fallbackText: viewModel.currentUserName
                )
            }
            .buttonStyle(.plain)

            if viewModel.isCurrentUserOwner {
                Divider().padding(.leading, 48)

                NavigationLink {
                    JoinRequestsView()
                } label: {
                    ProfileNavigationRow(
                        title: "审核加入申请",
                        systemImage: "person.badge.plus",
                        badge: viewModel.joinRequests.isEmpty ? nil : "\(viewModel.joinRequests.count)"
                    )
                }
                .buttonStyle(.plain)

            }
        }
        .padding(.horizontal, 6)
    }

    private var inviteCodeRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "ticket")
                .font(.system(size: 20, weight: .medium))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text("家庭邀请码")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DSColor.ink)

                Text(inviteCode)
                    .font(.system(size: 19, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DSColor.ink)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 4)

            Button {
                guard let code = viewModel.currentFamily?.inviteCode, !code.isEmpty else { return }
                UIPasteboard.general.string = code
                didCopyInviteCode = true
            } label: {
                Image(systemName: didCopyInviteCode ? "checkmark" : "doc.on.doc")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ProfileToolButtonStyle())
            .disabled(viewModel.currentFamily?.inviteCode.isEmpty ?? true)
            .accessibilityLabel(didCopyInviteCode ? "邀请码已复制" : "复制邀请码")

            ShareLink(item: inviteShareText) {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ProfileToolButtonStyle())
            .disabled(viewModel.currentFamily?.inviteCode.isEmpty ?? true)
            .accessibilityLabel("分享家庭邀请码")
        }
        .padding(.vertical, 4)
    }

    private var membersSection: some View {
        ProfileGroupCard {
            HStack {
                Text("家庭成员")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DSColor.ink)

                Spacer()

                Text("\(displayedMembers.count) 人")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(DSColor.mutedInk)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(displayedMembers) { member in
                        if member.userId == viewModel.currentUser?.id {
                            memberItem(member)
                        } else {
                            NavigationLink {
                                MemberActivityDetailView(member: member)
                            } label: {
                                memberItem(member)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func memberItem(_ member: FamilyMemberProfile) -> some View {
        VStack(spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(
                    avatarKey: member.avatarKey,
                    fallbackText: member.name,
                    size: 68,
                    presentation: .flat
                )

                if member.memberRole == .owner {
                    OwnerRoleBadge(compact: true)
                        .offset(x: 8, y: 2)
                }
            }

            Text(member.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DSColor.ink)
                .lineLimit(1)
                .frame(width: 72)

            Text(member.displayIdentity)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(DSColor.mutedInk)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private var accountSection: some View {
        ProfileGroupCard {
            NavigationLink {
                AchievementsView()
            } label: {
                ProfileNavigationRow(
                    title: "我的成就",
                    systemImage: "medal.fill",
                    badge: viewModel.achievementSummary.map {
                        "\($0.unlockedCount)/\($0.totalCount)"
                    }
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 48)

            ProfileInfoRow(
                title: "家庭套餐",
                value: viewModel.hasPremiumAccess ? "家庭高级版" : "免费版",
                systemImage: "diamond"
            )
            .id(viewModel.hasPremiumAccess)

            if viewModel.hasPremiumAccess {
                Text("家庭中任意一位成员开通，全家都能共享高级权益。")
                    .font(DSFont.functionalCaption)
                    .foregroundStyle(DSColor.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !viewModel.hasPremiumAccess {
                Button {
                    isShowingPremiumRedemption = true
                } label: {
                    Label("查看高级版权益", systemImage: "crown.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DSColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(DSColor.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.hasPremiumAccess)
    }

    private var appearanceSection: some View {
        ProfileGroupCard {
            HStack(spacing: 12) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("显示与外观")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DSColor.ink)

                    Text("深夜记功也不刺眼")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(DSColor.mutedInk)
                }
            }

            Picker("显示模式", selection: appearanceBinding) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.title)
                        .tag(appearance)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityHint("选择跟随系统、浅色或深色外观")
        }
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { AppAppearance.resolve(appearanceRawValue) },
            set: { appearanceRawValue = $0.rawValue }
        )
    }

    #if DEBUG
    private var debugSection: some View {
        DisclosureGroup(isExpanded: $isDebugExpanded) {
            DebugPanel()
                .padding(.top, 14)
        } label: {
            Label("开发信息 · 仅 Debug", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DSColor.ink)
        }
        .tint(DSColor.mutedInk)
        .padding(18)
        .background(DSColor.pureSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DSColor.subtleStroke, lineWidth: 1)
        )
    }
    #endif

    private var leaveFamilyButton: some View {
        Button {
            if viewModel.isCurrentUserOwner {
                isShowingOwnerLeaveGuidance = true
            } else {
                isShowingLeaveFamilyConfirmation = true
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "rectangle.portrait.and.arrow.forward")
                Text("退出当前家庭")
            }
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(DSColor.coral)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(DSColor.pureSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DSColor.coral.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .accessibilityHint(viewModel.isCurrentUserOwner ? "需要先转让一家之主" : "退出后保留历史记录")
    }

    private var logoutButton: some View {
        Button {
            isShowingLogoutConfirmation = true
        } label: {
            Text("退出登录")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(DSColor.pureSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(DSColor.subtleStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var inviteCode: String {
        guard let code = viewModel.currentFamily?.inviteCode, !code.isEmpty else {
            return "暂无邀请码"
        }
        return code
    }

    private var inviteShareText: String {
        "加入“\(viewModel.familyDisplayName)”的家庭战况，邀请码：\(inviteCode)"
    }

    private var displayedMembers: [FamilyMemberProfile] {
        let activeMembers = viewModel.orderedActiveFamilyMembers
        if !activeMembers.isEmpty {
            return activeMembers
        }

        guard let user = viewModel.currentUser, let membership = viewModel.currentMembership else {
            return []
        }

        return [
            FamilyMemberProfile(
                id: membership.id,
                userId: user.id,
                name: user.displayName,
                identityLabel: membership.identityLabel,
                customIdentity: membership.customIdentity,
                avatarKey: membership.avatarKey,
                memberRole: membership.memberRole,
                status: membership.status,
                joinedAt: .distantPast
            ),
        ]
    }
}

private struct OwnerRoleBadge: View {
    var compact = false

    var body: some View {
        Text("一家之主")
            .font(.system(size: compact ? 9 : 11, weight: .semibold))
            .foregroundStyle(DSColor.ink)
            .lineLimit(1)
            .padding(.horizontal, compact ? 6 : 8)
            .frame(height: compact ? 19 : 23)
            .background(DSColor.pureSurface)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 6 : 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 6 : 7, style: .continuous)
                    .stroke(DSColor.mutedInk.opacity(0.42), lineWidth: 0.75)
            )
            .accessibilityLabel("一家之主")
    }
}

private struct AppearanceSelectionView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draftAvatarKey = FamilyIdentityOptions.avatarKeys[0]

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("选择你的家庭形象")
                            .font(DSFont.functionalPageTitle)
                            .foregroundStyle(DSColor.ink)
                        Text("立绘与头像一一配套，保存后会在个人页、家庭成员和动态里同步更新。")
                            .font(DSFont.functionalBody)
                            .foregroundStyle(DSColor.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    DSQuietCard(fill: DSColor.pureSurface, cornerRadius: 22, padding: 16) {
                        FamilyAvatarCarousel(avatarKey: $draftAvatarKey)
                    }

                    pairedAvatarPreview

                    if let errorMessage = viewModel.errorMessage {
                        DSErrorBanner(message: errorMessage)
                    }

                    Button {
                        Task {
                            if await viewModel.updateAppearance(avatarKey: draftAvatarKey) {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack(spacing: 9) {
                            if viewModel.isLoading {
                                ProgressView().tint(DSColor.ink)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(hasChanges ? "保存家庭形象" : "当前形象已在使用")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DSColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(hasChanges ? DSColor.yellow : DSColor.pureSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(hasChanges ? DSColor.yellow : DSColor.subtleStroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasChanges || viewModel.isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("家庭形象")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            draftAvatarKey = currentAvatarKey
        }
    }

    private var pairedAvatarPreview: some View {
        DSQuietCard(fill: DSColor.infoBlue.opacity(0.08), cornerRadius: 18, padding: 16) {
            HStack(spacing: 14) {
                AvatarView(
                    avatarKey: draftAvatarKey,
                    fallbackText: viewModel.currentUserName,
                    size: 64,
                    presentation: .quiet
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("头像同步更新")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DSColor.ink)
                    Text("无需再次选择头像")
                        .font(DSFont.functionalCaption)
                        .foregroundStyle(DSColor.mutedInk)
                }

                Spacer()

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(DSColor.infoBlue)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("头像将随家庭形象同步更新")
    }

    private var currentAvatarKey: String {
        viewModel.currentMembership?.avatarKey ?? FamilyIdentityOptions.avatarKeys[0]
    }

    private var hasChanges: Bool {
        draftAvatarKey != currentAvatarKey
    }
}

private struct MemberActivityDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let member: FamilyMemberProfile
    @State private var showsTransferConfirmation = false

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    memberHeader
                    activitySummary

                    Text("近 30 天家务动态")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(DSColor.ink)

                    if viewModel.isLoading && records.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("正在读取家务动态…")
                                .font(DSFont.functionalBody)
                                .foregroundStyle(DSColor.mutedInk)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                    } else if records.isEmpty {
                        DSEmptyStateView(
                            title: "近一个月还没有记录",
                            message: "完成家务后，动态会出现在这里。",
                            systemImage: "calendar.badge.clock"
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                                ActivityRow(
                                    record: record,
                                    presentation: .grouped(
                                        isFirst: index == 0,
                                        isLast: index == records.count - 1
                                    )
                                )
                            }
                        }
                        .background(DSColor.pureSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(DSColor.subtleStroke, lineWidth: 1)
                        )
                        .shadow(color: DSColor.shadow.opacity(0.09), radius: 12, x: 0, y: 6)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        DSErrorBanner(message: errorMessage)
                    }

                    if canTransferOwnership {
                        Button {
                            showsTransferConfirmation = true
                        } label: {
                            HStack(spacing: 9) {
                                if viewModel.isLoading {
                                    ProgressView().tint(DSColor.ink)
                                } else {
                                    Image(systemName: "arrow.left.arrow.right")
                                }
                                Text("将一家之主转让给此成员")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DSColor.ink)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(DSColor.yellow)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(DSColor.subtleStroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isLoading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .refreshable {
                await viewModel.loadMemberActivity(for: member)
            }
        }
        .navigationTitle("成员动态")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task(id: member.id) {
            await viewModel.loadMemberActivity(for: member)
        }
        .confirmationDialog(
            "确认将一家之主转让给\(member.name)？",
            isPresented: $showsTransferConfirmation,
            titleVisibility: .visible
        ) {
            Button("确认转让", role: .destructive) {
                Task {
                    if await viewModel.transferOwnership(to: member) {
                        dismiss()
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("操作成功后，你将不再是一家之主。")
        }
    }

    private var memberHeader: some View {
        ProfileGroupCard {
            HStack(spacing: 16) {
                AvatarView(
                    avatarKey: member.avatarKey,
                    fallbackText: member.name,
                    size: 76,
                    presentation: .flat
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(member.name)
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(DSColor.ink)
                    Text(member.displayIdentity)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(DSColor.mutedInk)
                    if member.memberRole == .owner {
                        OwnerRoleBadge()
                    }
                }

                Spacer()
            }
        }
    }

    private var activitySummary: some View {
        ProfileGroupCard {
            HStack(spacing: 0) {
                summaryMetric(title: "完成", value: "\(records.count)", suffix: "次", color: DSColor.infoBlue)
                Divider().frame(height: 42)
                summaryMetric(title: "耗时", value: "\(totalMinutes)", suffix: "分钟", color: DSColor.mint)
                Divider().frame(height: 42)
                summaryMetric(title: "积分", value: "\(totalPoints)", suffix: "分", color: DSColor.coral)
            }
        }
    }

    private func summaryMetric(title: String, value: String, suffix: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(DSColor.mutedInk)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(suffix)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(DSColor.mutedInk)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var records: [ChoreRecord] {
        viewModel.memberActivity(for: member)
    }

    private var totalMinutes: Int {
        records.reduce(0) { $0 + $1.actualMinutes }
    }

    private var totalPoints: Int {
        records.reduce(0) { $0 + $1.points }
    }

    private var canTransferOwnership: Bool {
        viewModel.isCurrentUserOwner &&
            member.memberRole == .member &&
            member.status == .active &&
            member.userId != viewModel.currentUser?.id
    }
}

private struct ProfileAppearanceRow: View {
    let avatarKey: String?
    let fallbackText: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.square")
                .font(.system(size: 20, weight: .medium))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text("家庭形象")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DSColor.ink)
            }

            Spacer()

            AvatarView(
                avatarKey: avatarKey,
                fallbackText: fallbackText,
                size: 42,
                presentation: .quiet
            )

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DSColor.mutedInk)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(avatarKey == nil ? "家庭形象，未选择" : "家庭形象，已选择")
    }
}

private enum ProfilePalette {
    static let identitySurface = DSColor.choreBlueSurface
    static let petal = DSColor.sky
}

private struct ProfilePetalDecoration: View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(ProfilePalette.petal.opacity(0.32))
                .frame(width: 78, height: 78)
                .offset(x: 18, y: 22)

            Circle()
                .fill(ProfilePalette.petal.opacity(0.26))
                .frame(width: 58, height: 58)
                .offset(x: -36, y: 27)

            Circle()
                .fill(ProfilePalette.petal.opacity(0.22))
                .frame(width: 45, height: 45)
                .offset(x: -74, y: 34)
        }
        .frame(width: 144, height: 78)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ProfileGroupCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSColor.pureSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DSColor.subtleStroke.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: DSColor.shadow.opacity(0.07), radius: 14, x: 0, y: 7)
    }
}

private struct ProfileInfoRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 36, height: 36)

            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(DSColor.ink)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(DSColor.mutedInk)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileNavigationRow: View {
    let title: String
    let systemImage: String
    var badge: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 36, height: 36)

            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(DSColor.ink)

            Spacer()

            if let badge {
                Text(badge)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DSColor.infoBlue)
                    .frame(minWidth: 30, minHeight: 30)
                    .background(DSColor.infoBlue.opacity(0.10))
                    .clipShape(Circle())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DSColor.mutedInk)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct ProfileToolButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(DSColor.ink)
            .background(DSColor.pureSurface)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(DSColor.subtleStroke, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.62 : 1)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppViewModel.previewLoggedIn())
    }
}


#Preview("我的 · 深色") {
    NavigationStack {
        ProfileView()
            .environmentObject(AppViewModel.previewLoggedIn())
    }
    .preferredColorScheme(.dark)
}
