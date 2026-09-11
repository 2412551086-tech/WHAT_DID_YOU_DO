import SwiftUI

struct OnboardingChoiceView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        AuthIllustratedPage {
            VStack(spacing: 12) {
                Button(action: viewModel.beginLocalFamilyOnboarding) {
                    Text("创建新家庭").frame(maxWidth: .infinity)
                }
                .buttonStyle(V3PrimaryButtonStyle())

                Button(action: viewModel.beginJoinFamilyOnboarding) {
                    Text("加入已有家庭").frame(maxWidth: .infinity)
                }
                .buttonStyle(V3SecondaryButtonStyle())

                Button(action: viewModel.beginExistingAccountLogin) {
                    Label("登录已有账号", systemImage: "person.crop.circle.fill")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSColor.ink)
                .buttonStyle(.plain)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

/// Preserve the original poster composition with live controls in its empty lower area.
struct AuthIllustratedPage<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var compact = false
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { viewport in
            let posterHeight = max(viewport.size.height, viewport.size.width * 1844 / 853)
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: posterHeight * 0.68)
                        .accessibilityLabel("家庭保卫战")
                        .accessibilityAddTraits(.isHeader)
                    content
                        .frame(maxWidth: 440)
                        .padding(.horizontal, 24)
                        .padding(.bottom, max(48, viewport.safeAreaInsets.bottom + 24))
                    Spacer(minLength: 0)
                }
                .frame(minHeight: posterHeight)
                .frame(maxWidth: .infinity)
                .background(alignment: .top) {
                    Image(colorScheme == .dark ? "auth_v3_poster_dark" : "auth_v3_poster")
                        .resizable()
                        .frame(width: viewport.size.width, height: posterHeight)
                        .accessibilityHidden(true)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .ignoresSafeArea()
        .background(colorScheme == .dark ? Color(white: 0.095) : Color(red: 0.98, green: 0.97, blue: 0.93))
        .foregroundStyle(DSColor.ink)
    }
}
