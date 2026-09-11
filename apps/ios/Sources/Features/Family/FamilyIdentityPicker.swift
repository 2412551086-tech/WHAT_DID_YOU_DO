import SwiftUI
import UIKit

enum FamilyIdentityOptions {
    static let identities = [
        "家庭成员", "男主人", "女主人", "老公", "老婆", "老妈", "老爸", "儿子", "女儿",
        "哥哥", "姐姐", "弟弟", "妹妹", "爷爷", "奶奶", "室友", "自定义",
    ]

    static let avatarKeys = (1...13).map { String(format: "avatar_%02d", $0) }

    static func index(for key: String) -> Int {
        avatarKeys.firstIndex(of: key) ?? 0
    }

    static func actionAsset(for key: String) -> String {
        String(format: "family_avatar_action_%02d", index(for: key) + 1)
    }

    static func neutralAsset(for key: String) -> String {
        String(format: "family_avatar_neutral_%02d", index(for: key) + 1)
    }

    static func accentColor(for key: String?) -> Color {
        switch key ?? avatarKeys[0] {
        case "avatar_01": return Color(red: 0.80, green: 0.63, blue: 0.38)
        case "avatar_02": return Color(red: 0.66, green: 0.81, blue: 0.70)
        case "avatar_03": return Color(red: 0.53, green: 0.33, blue: 0.22)
        case "avatar_04": return Color(red: 0.59, green: 0.46, blue: 0.51)
        case "avatar_05": return Color(red: 0.58, green: 0.70, blue: 0.80)
        case "avatar_06": return Color(red: 0.92, green: 0.69, blue: 0.47)
        case "avatar_07": return Color(red: 0.75, green: 0.55, blue: 0.55)
        case "avatar_08": return Color(red: 0.55, green: 0.69, blue: 0.77)
        case "avatar_09": return Color(red: 0.54, green: 0.67, blue: 0.48)
        case "avatar_10": return Color(red: 0.73, green: 0.58, blue: 0.30)
        case "avatar_11": return Color(red: 0.86, green: 0.53, blue: 0.30)
        case "avatar_12": return Color(red: 0.83, green: 0.69, blue: 0.87)
        case "avatar_13": return Color(red: 0.61, green: 0.82, blue: 0.86)
        default: return DSColor.sky
        }
    }

}

struct FamilyFlowTopBar: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            Spacer()

            Text(title)
                .font(.system(size: 17, weight: .semibold))

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(DSColor.ink)
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(DSColor.quietBackground.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DSColor.subtleStroke)
                .frame(height: 0.5)
        }
    }
}

struct FamilyFlowSectionLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(DSColor.yellow)
                .frame(width: 4, height: 16)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DSColor.ink)
        }
    }
}

struct FamilyFlowTextField: View {
    let placeholder: String
    var systemImage: String?
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(DSColor.mutedInk)
            }

            TextField(placeholder, text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(DSColor.pureSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DSColor.subtleStroke, lineWidth: 1)
        )
        .shadow(color: DSColor.shadow.opacity(0.09), radius: 8, y: 3)
    }
}

struct FamilyFlowPrimaryButton: View {
    let title: String
    var systemImage: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(isEnabled ? DSColor.ink : DSColor.mutedInk.opacity(0.6))
            .background(isEnabled ? DSColor.yellow : DSColor.selectionSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct FamilyFlowSecondaryButton: View {
    let title: String
    var systemImage: String?
    var tint: Color = DSColor.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 15, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .foregroundStyle(tint)
            .background(DSColor.pureSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(0.62), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FamilyAvatarCarousel: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Binding var avatarKey: String
    @GestureState private var dragTranslation: CGFloat = 0

    private var avatarKeys: [String] { viewModel.selectableAvatarKeys }
    private var selectedIndex: Int { avatarKeys.firstIndex(of: avatarKey) ?? 0 }

    var body: some View {
        HStack(spacing: 2) {
                arrowButton(systemName: "chevron.left") { move(by: -1) }

                avatarImage(
                    at: wrappedIndex(selectedIndex - 1),
                    width: 58,
                    height: 122,
                    opacity: 0.42
                )

                ZStack(alignment: .topTrailing) {
                    avatarImage(at: selectedIndex, width: 164, height: 194, opacity: 1)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, DSColor.infoBlue)
                        .padding(4)
                }

                avatarImage(
                    at: wrappedIndex(selectedIndex + 1),
                    width: 58,
                    height: 122,
                    opacity: 0.42
                )

                arrowButton(systemName: "chevron.right") { move(by: 1) }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .offset(x: max(-18, min(18, dragTranslation)))
            .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.82), value: dragTranslation)
            .highPriorityGesture(avatarSwipeGesture)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("选择家庭形象，第 \(selectedIndex + 1) 个，共 \(avatarKeys.count) 个")
        .task { await viewModel.refreshAchievementCharacters() }
    }

    private var avatarSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .updating($dragTranslation) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                let horizontalDistance = value.translation.width
                guard abs(horizontalDistance) > abs(value.translation.height),
                      abs(horizontalDistance) > 28
                else { return }
                move(by: horizontalDistance < 0 ? 1 : -1)
            }
    }

    private func avatarImage(
        at index: Int,
        width: CGFloat,
        height: CGFloat,
        opacity: Double
    ) -> some View {
        let key = avatarKeys[index]
        return Button {
            avatarKey = key
        } label: {
            Group {
                if CollectibleCharacter.contains(key) {
                    V2CharacterArt(avatarKey: key)
                } else {
                    Image(FamilyIdentityOptions.actionAsset(for: key))
                        .resizable()
                        .scaledToFit()
                }
            }
                .frame(width: width, height: height)
                .opacity(opacity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("选择第 \(index + 1) 个家庭形象")
    }

    private func arrowButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(DSColor.pureSurface)
                .clipShape(Circle())
                .overlay(Circle().stroke(DSColor.subtleStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func move(by offset: Int) {
        avatarKey = avatarKeys[wrappedIndex(selectedIndex + offset)]
    }

    private func wrappedIndex(_ index: Int) -> Int {
        let count = avatarKeys.count
        return (index % count + count) % count
    }
}

struct FamilyIdentityPicker: View {
    @Binding var identityLabel: String
    @Binding var customIdentity: String
    @Binding var avatarKey: String
    var showsAvatar = true

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if showsAvatar {
              VStack(alignment: .leading, spacing: 12) {
                FamilyFlowSectionLabel(title: "选择你的形象")
                FamilyAvatarCarousel(avatarKey: $avatarKey)
              }
            }

            VStack(alignment: .leading, spacing: 10) {
              if !showsAvatar {
                FamilyIdentityWheel(selection: $identityLabel, options: FamilyIdentityOptions.identities)
                .padding(.top, 24)
                .accessibilityLabel("家庭身份")
              } else {
                FamilyFlowSectionLabel(title: "家庭身份")

                Menu {
                    ForEach(FamilyIdentityOptions.identities, id: \.self) { identity in
                        Button(identity) {
                            identityLabel = identity
                        }
                    }
                } label: {
                    HStack {
                        Text(identityLabel)
                            .font(.body.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DSColor.mutedInk)
                    }
                    .foregroundStyle(DSColor.ink)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(DSColor.pureSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(DSColor.subtleStroke, lineWidth: 1)
                    )
                }
              }

                if identityLabel == "自定义" {
                    FamilyFlowTextField(
                        placeholder: "输入自定义身份",
                        systemImage: "pencil",
                        text: $customIdentity
                    )
                }

            }
        }
    }
}

/// Shared only by the native family onboarding pages.
struct FamilyWizardPage<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var keyboardVisible = false
    let title: String
    let illustration: String
    let step: Int
    let total: Int
    let actionTitle: String
    let isBusy: Bool
    var canContinue = true
    var allowsBack = true
    let onBack: () -> Void
    let onNext: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            V3OnboardingBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if illustration != "avatar" {
                      V3StepIllustration(step: illustration)
                        .frame(maxWidth: .infinity)
                        .frame(height: keyboardVisible || typeSize.isAccessibilitySize ? 88 : 260)
                        .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    content()
                        .disabled(isBusy)
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .tint(.primary)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 16) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("返回")
                .foregroundStyle(.primary)
                .disabled(isBusy || !allowsBack)
                ProgressView(value: Double(step), total: Double(total))
                    .tint(V3OnboardingColor.butter)
                    .scaleEffect(x: 1, y: 2.3)
                    .frame(height: 10)
                    .accessibilityLabel("设置进度")
                    .accessibilityValue("第 \(step) 步，共 \(total) 步")
                    .padding(.trailing, 28)
            }
            .padding(.horizontal, 16)
            .background(V3OnboardingColor.surface(colorScheme))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                guard !isBusy else { return }
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                onNext()
            } label: {
                HStack {
                    if isBusy { ProgressView().tint(V3OnboardingColor.buttonInk) }
                    Text(actionTitle)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(V3PrimaryButtonStyle())
            .disabled(isBusy || !canContinue)
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(V3OnboardingColor.surface(colorScheme))
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { keyboardVisible = false }
        }
    }
}

struct FamilyWizardAvatarPicker: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var avatarKey: String

    var body: some View {
        VStack(spacing: 20) {
            Group {
                if CollectibleCharacter.contains(avatarKey) {
                    V2CharacterArt(avatarKey: avatarKey)
                } else {
                    Image(FamilyIdentityOptions.actionAsset(for: avatarKey)).resizable().scaledToFit()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: typeSize.isAccessibilitySize ? 180 : 290)
            .accessibilityHidden(true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 76 : 60), spacing: 12)], spacing: 12) {
                ForEach(viewModel.selectableAvatarKeys, id: \.self) { key in
                    Button { avatarKey = key } label: {
                        AvatarView(avatarKey: key, fallbackText: "", size: 52, presentation: .flat)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(V3OnboardingColor.buttonInk, V3OnboardingColor.butter)
                                    .opacity(avatarKey == key ? 1 : 0)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("家庭形象 \((viewModel.selectableAvatarKeys.firstIndex(of: key) ?? 0) + 1)")
                    .accessibilityAddTraits(avatarKey == key ? .isSelected : [])
                }
            }
        }
        .task { await viewModel.refreshAchievementCharacters() }
    }
}

#Preview {
    ScrollView {
        FamilyIdentityPicker(
            identityLabel: .constant("老妈"),
            customIdentity: .constant(""),
            avatarKey: .constant("avatar_07")
        )
        .padding(20)
    }
    .background(DSColor.quietBackground)
    .environmentObject(AppViewModel.previewLoggedIn())
}
