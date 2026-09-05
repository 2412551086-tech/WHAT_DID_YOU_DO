import SwiftUI

struct OnboardingChoiceView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Image("login_household_battle")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)

            LinearGradient(
                colors: [
                    Color.black.opacity(colorScheme == .dark ? 0.44 : 0.16),
                    Color.black.opacity(0.04),
                    Color.black.opacity(colorScheme == .dark ? 0.58 : 0.34),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("家庭保卫战")
                        .font(.system(size: 38, weight: .bold))
                    Text("把每一份家务，都记成功劳。")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 4)
                .padding(.top, 32)

                Spacer(minLength: 260)

                VStack(spacing: 12) {
                    Button(action: viewModel.beginExistingAccountLogin) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text("登录已有账号")
                                .font(.system(size: 17, weight: .bold))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(DSColor.pureSurface)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 56)
                        .background(DSColor.ink.opacity(0.94))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { secondaryActions }
                        VStack(spacing: 10) { secondaryActions }
                    }

                    Text("第一次使用也可以先创建或加入家庭，稍后再登录。")
                        .font(.system(size: 12))
                        .foregroundStyle(DSColor.mutedInk)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(16)
                .background(DSColor.quietBackground.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: 22, x: 0, y: 10)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: 720)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private var secondaryActions: some View {
        compactAction(
            title: "创建新家庭",
            subtitle: "先体验再注册",
            systemImage: "house.fill",
            fill: DSColor.yellow,
            action: viewModel.beginLocalFamilyOnboarding
        )

        compactAction(
            title: "加入已有家庭",
            subtitle: "使用邀请码",
            systemImage: "person.2.fill",
            fill: DSColor.pureSurface,
            action: viewModel.beginJoinFamilyOnboarding
        )
    }

    private func compactAction(
        title: String,
        subtitle: String,
        systemImage: String,
        fill: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(DSColor.mutedInk)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(DSColor.ink)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DSColor.subtleStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(subtitle)
    }
}
