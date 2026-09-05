import SwiftUI

struct AccountSecurityView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var confirmation: AccountConfirmation?
    @State private var showsOwnerTransferPicker = false
    @State private var showsOwnerWithoutSuccessorAlert = false

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let errorMessage = viewModel.errorMessage {
                        DSErrorBanner(message: errorMessage)
                    }

                    securitySection("当前家庭") {
                        accountSummary
                        Divider()
                        familyAction
                    }

                    securitySection("登录状态") {
                        Button {
                            confirmation = .logout
                        } label: {
                            actionRow(
                                title: "退出登录",
                                systemImage: "arrow.backward.circle",
                                color: DSColor.ink
                            )
                        }
                        .buttonStyle(.plain)
                        Divider()
                        Button {
                            confirmation = .logoutAll
                        } label: {
                            actionRow(
                                title: "退出所有设备",
                                systemImage: "iphone.gen3.slash",
                                color: .red
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    securitySection("数据与隐私") {
                        NavigationLink {
                            DeleteAccountView()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                actionRow(
                                    title: "永久注销账户",
                                    systemImage: "person.crop.circle.badge.xmark",
                                    color: .red,
                                    showsChevron: true
                                )
                                Text("删除账号、个人记录与本机登录信息，此操作不可恢复。")
                                    .font(.system(size: 13))
                                    .foregroundStyle(DSColor.mutedInk)
                                    .padding(.leading, 48)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("账户与安全")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(viewModel.isLoading)
        .confirmationDialog(
            confirmation?.title ?? "",
            isPresented: Binding(
                get: { confirmation != nil },
                set: { if !$0 { confirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if confirmation == .leaveFamily {
                Button("退出当前家庭", role: .destructive) {
                    Task { _ = await viewModel.leaveCurrentFamily() }
                }
            } else if confirmation == .logout {
                Button("退出登录", role: .destructive) {
                    viewModel.logout()
                }
            } else if confirmation == .logoutAll {
                Button("退出所有设备", role: .destructive) {
                    viewModel.logout(allDevices: true)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(confirmation?.message ?? "")
        }
        .confirmationDialog(
            "选择新的一家之主",
            isPresented: $showsOwnerTransferPicker,
            titleVisibility: .visible
        ) {
            ForEach(viewModel.transferableFamilyMembers) { member in
                Button("\(member.name) · \(member.displayIdentity)") {
                    Task { _ = await viewModel.transferOwnership(to: member) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("转让完成后，你就可以退出当前家庭。")
        }
        .alert("当前没有可转让成员", isPresented: $showsOwnerWithoutSuccessorAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("邀请并通过至少一位家庭成员后，才能转让一家之主并退出家庭。永久注销账户时，单人成立的家庭会随账户一并删除。")
        }
    }

    private var accountSummary: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "house.fill")
                .font(.system(size: 19, weight: .medium))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.familyDisplayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DSColor.ink)
                Text(viewModel.isCurrentUserOwner
                    ? "你是一家之主，退出前需要先完成转让"
                    : "退出后历史记录仍保留在家庭战况中")
                    .font(.system(size: 13))
                    .foregroundStyle(DSColor.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var familyAction: some View {
        if viewModel.isCurrentUserOwner {
            Button {
                if viewModel.transferableFamilyMembers.isEmpty {
                    showsOwnerWithoutSuccessorAlert = true
                } else {
                    showsOwnerTransferPicker = true
                }
            } label: {
                actionRow(
                    title: "先转让一家之主",
                    systemImage: "person.2.badge.gearshape.fill",
                    color: DSColor.accentOrange
                )
            }
            .buttonStyle(.plain)
        } else {
            Button {
                confirmation = .leaveFamily
            } label: {
                actionRow(
                    title: "退出当前家庭",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    color: DSColor.accentOrange
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func securitySection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DSColor.mutedInk)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 13) {
                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DSColor.pureSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(DSColor.subtleStroke.opacity(0.65), lineWidth: 1)
            )
        }
    }

    private func actionRow(
        title: String,
        systemImage: String,
        color: Color,
        showsChevron: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .medium))
                .frame(width: 36, height: 36)
            Text(title)
                .font(.system(size: 16, weight: .medium))
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DSColor.mutedInk)
            }
        }
        .foregroundStyle(color)
        .contentShape(Rectangle())
    }
}

struct DeleteAccountView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var confirmationText = ""
    @State private var showsFinalConfirmation = false

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    consequenceCard
                    confirmationField

                    if let errorMessage = viewModel.errorMessage {
                        DSErrorBanner(message: errorMessage)
                    }

                    Button {
                        showsFinalConfirmation = true
                    } label: {
                        Text("永久注销账户")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(canDelete ? Color.red : DSColor.mutedInk.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canDelete || viewModel.isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("注销账户")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "最后确认永久注销？",
            isPresented: $showsFinalConfirmation,
            titleVisibility: .visible
        ) {
            Button("永久删除全部账号数据", role: .destructive) {
                Task { _ = await viewModel.deleteAccount() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("注销完成后不能撤销。\(ownershipConsequence)")
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 46, weight: .medium))
                .foregroundStyle(.red)
            Text("永久注销账户")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(DSColor.ink)
            Text("这不是退出登录。确认后，账号和关联个人数据将无法恢复。")
                .font(.system(size: 15))
                .foregroundStyle(DSColor.mutedInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var consequenceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            consequence("删除账号资料、个人家务记录、点赞和个人成就", icon: "trash.fill")
            consequence("清除本机 Keychain 登录凭证、缓存和待同步记录", icon: "iphone.gen3.slash")
            consequence(ownershipConsequence, icon: "house.fill")
            consequence("法律要求必须保留的数据除外；当前开发版没有此类保留项", icon: "doc.text.fill")
        }
        .padding(18)
        .background(DSColor.redSoft)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.red.opacity(0.18), lineWidth: 1)
        )
    }

    private var confirmationField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("输入“注销账户”继续")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DSColor.mutedInk)
            TextField("注销账户", text: $confirmationText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(DSColor.pureSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DSColor.subtleStroke, lineWidth: 1)
                )
        }
    }

    private func consequence(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(DSColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ownershipConsequence: String {
        guard viewModel.isCurrentUserOwner else {
            return "从当前家庭中永久移除你的成员身份"
        }
        if let successor = viewModel.transferableFamilyMembers.first {
            return "一家之主将自动转让给最早加入的活跃成员（当前预计为 \(successor.name)）"
        }
        return "当前家庭没有其他活跃成员，家庭及其中数据将一并删除"
    }

    private var canDelete: Bool {
        confirmationText.trimmingCharacters(in: .whitespacesAndNewlines) == "注销账户"
    }
}

private enum AccountConfirmation: Equatable {
    case leaveFamily
    case logout
    case logoutAll

    var title: String {
        switch self {
        case .leaveFamily: "确认退出当前家庭？"
        case .logout: "确认退出登录？"
        case .logoutAll: "确认退出所有设备？"
        }
    }

    var message: String {
        switch self {
        case .leaveFamily: "退出后将看不到该家庭的战况；已经创建的家务记录仍会保留。"
        case .logout: "只清除本机登录状态，不会删除账号或家庭数据。"
        case .logoutAll: "包括当前手机在内的所有设备都会退出，之后需要重新登录。"
        }
    }
}

#Preview {
    NavigationStack {
        AccountSecurityView()
            .environmentObject(AppViewModel.previewLoggedIn())
    }
}

#Preview("注销账户") {
    NavigationStack {
        DeleteAccountView()
            .environmentObject(AppViewModel.previewLoggedIn())
    }
}
