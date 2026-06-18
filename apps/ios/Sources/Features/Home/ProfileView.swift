import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    packageCard
                    familySettings
                    logoutCard
                }
                .padding(20)
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        DSCard(fill: DSColor.sky) {
            HStack(spacing: 16) {
                Text(viewModel.currentUser?.avatarInitial ?? "我")
                    .font(.appTitle(32))
                    .frame(width: 64, height: 64)
                    .background(DSColor.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(DSColor.ink, lineWidth: 2.5))

                VStack(alignment: .leading, spacing: 7) {
                    Text(viewModel.currentUserName)
                        .font(.appHeadline(24))
                    Text(viewModel.currentUser?.badge ?? "Mock 家务观察员")
                        .font(.appBody(14))
                        .foregroundStyle(DSColor.mutedInk)
                    Text(viewModel.familyDisplayName)
                        .font(.appBody(14))
                        .foregroundStyle(DSColor.ink)
                }
            }
        }
    }

    private var packageCard: some View {
        DSCard(fill: DSColor.yellow) {
            VStack(alignment: .leading, spacing: 10) {
                Label("当前套餐", systemImage: "crown.fill")
                    .font(.appHeadline())
                Text("免费版 · 核心 10 个家务已解锁")
                    .font(.appBody(16))
                Text("高级家务库、自定义常干事项和更多报告模板先放在 Mock 展示里。")
                    .font(.appBody(14))
                    .foregroundStyle(DSColor.mutedInk)
            }
            .foregroundStyle(DSColor.ink)
        }
    }

    private var familySettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("家庭设置")
                .font(.appHeadline())
                .foregroundStyle(DSColor.ink)

            DSCard {
                VStack(alignment: .leading, spacing: 12) {
                    settingRow(title: "家庭名称", value: viewModel.familyDisplayName, icon: "house.fill")
                    settingRow(title: "邀请码", value: viewModel.currentFamily?.inviteCode ?? MockData.family.inviteCode, icon: "number.square.fill")
                    settingRow(title: "图片凭证", value: viewModel.currentFamily?.requiresPhotoProof == true ? "需要" : "不需要", icon: "photo.fill")
                }
            }

            DSButton(title: "进入家庭设置", systemImage: "slider.horizontal.3", style: .secondary) {
            }
        }
    }

    private var logoutCard: some View {
        DSCard(fill: DSColor.coral) {
            VStack(alignment: .leading, spacing: 12) {
                Text("今天先撤")
                    .font(.appHeadline())
                Text("退出会清空本地登录态；API 模式不会删除后端数据。")
                    .font(.appBody(14))
                    .foregroundStyle(DSColor.mutedInk)
                DSButton(title: "退出登录", systemImage: "rectangle.portrait.and.arrow.right", style: .danger) {
                    viewModel.logout()
                }
            }
        }
    }

    private func settingRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .black))
                .frame(width: 30, height: 30)
                .background(DSColor.mint)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(DSColor.ink, lineWidth: 1.5)
                )

            Text(title)
                .font(.appBody(15))

            Spacer()

            Text(value)
                .font(.appBody(15))
                .foregroundStyle(DSColor.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(DSColor.ink)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppViewModel.previewLoggedIn())
    }
}
