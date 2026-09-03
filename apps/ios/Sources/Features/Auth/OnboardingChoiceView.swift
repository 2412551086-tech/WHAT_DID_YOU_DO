import SwiftUI

struct OnboardingChoiceView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("家庭保卫战")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(DSColor.ink)
                        Text("先把家务记起来，需要和家人同步时再登录。")
                            .font(.system(size: 16))
                            .foregroundStyle(DSColor.mutedInk)
                    }

                    if horizontalSizeClass == .regular {
                        HStack(spacing: 16) { choices }
                    } else {
                        VStack(spacing: 14) { choices }
                    }
                }
                .frame(maxWidth: 820, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 42)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private var choices: some View {
        choiceCard(
            title: "创建新家庭",
            subtitle: "先选 6 项常用家务，马上开始记录",
            systemImage: "house.fill",
            fill: DSColor.yellow,
            isPrimary: true,
            action: viewModel.beginLocalFamilyOnboarding
        )

        choiceCard(
            title: "加入已有家庭",
            subtitle: "先输入邀请码，确认家庭后再登录",
            systemImage: "person.2.fill",
            fill: DSColor.sky.opacity(0.42),
            isPrimary: false,
            action: viewModel.beginJoinFamilyOnboarding
        )
    }

    private func choiceCard(
        title: String,
        subtitle: String,
        systemImage: String,
        fill: Color,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .frame(width: 58, height: 58)
                    .background(DSColor.pureSurface.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 23, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(DSColor.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Text(isPrimary ? "开始设置" : "输入邀请码")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(DSColor.ink)
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            .padding(22)
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
