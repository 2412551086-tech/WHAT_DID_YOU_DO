import SwiftUI

enum FamilyIdentityOptions {
    static let identities = [
        "男主人", "女主人", "老公", "老婆", "老妈", "老爸", "儿子", "女儿",
        "哥哥", "姐姐", "弟弟", "妹妹", "爷爷", "奶奶", "室友", "自定义",
    ]

    static let avatarKeys = (1...13).map { String(format: "avatar_%02d", $0) }

    static let avatarNames = [
        "小葵", "小森", "小灶", "小紫", "阿窗", "阿架", "小桃",
        "阿蓝", "小青", "小碗", "大力", "小乐", "小机",
    ]

    static func index(for key: String) -> Int {
        avatarKeys.firstIndex(of: key) ?? 0
    }

    static func actionAsset(for key: String) -> String {
        String(format: "family_avatar_action_%02d", index(for: key) + 1)
    }

    static func name(for key: String) -> String {
        avatarNames[index(for: key)]
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
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            Spacer()

            Text(title)
                .font(.system(size: 17, weight: .semibold))

            Spacer()

            Color.clear.frame(width: 36, height: 36)
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
                .font(.system(size: 16, weight: .regular))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(DSColor.pureSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DSColor.subtleStroke, lineWidth: 1)
        )
        .shadow(color: DSColor.ink.opacity(0.06), radius: 8, y: 3)
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
            .background(isEnabled ? DSColor.yellow : Color(red: 0.86, green: 0.84, blue: 0.79))
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
    @Binding var avatarKey: String
    @GestureState private var dragTranslation: CGFloat = 0

    private var selectedIndex: Int { FamilyIdentityOptions.index(for: avatarKey) }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                arrowButton(systemName: "chevron.left") { move(by: -1) }

                avatarImage(at: wrappedIndex(selectedIndex - 1), size: 66, opacity: 0.46)

                ZStack(alignment: .topTrailing) {
                    avatarImage(at: selectedIndex, size: 138, opacity: 1)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, DSColor.infoBlue)
                        .padding(4)
                }

                avatarImage(at: wrappedIndex(selectedIndex + 1), size: 66, opacity: 0.46)

                arrowButton(systemName: "chevron.right") { move(by: 1) }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .offset(x: max(-18, min(18, dragTranslation)))
            .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.82), value: dragTranslation)
            .highPriorityGesture(avatarSwipeGesture)

            Text(FamilyIdentityOptions.name(for: avatarKey))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DSColor.ink)

            Text("\(selectedIndex + 1) / \(FamilyIdentityOptions.avatarKeys.count)")
                .font(.system(size: 11))
                .foregroundStyle(DSColor.mutedInk)

            Text("左右滑动选择")
                .font(.system(size: 10))
                .foregroundStyle(DSColor.mutedInk.opacity(0.75))
        }
        .accessibilityElement(children: .contain)
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

    private func avatarImage(at index: Int, size: CGFloat, opacity: Double) -> some View {
        let key = FamilyIdentityOptions.avatarKeys[index]
        return Button {
            avatarKey = key
        } label: {
            Image(FamilyIdentityOptions.actionAsset(for: key))
                .resizable()
                .scaledToFit()
                .frame(width: size, height: 152)
                .opacity(opacity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("选择形象 \(FamilyIdentityOptions.name(for: key))")
    }

    private func arrowButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(DSColor.pureSurface)
                .clipShape(Circle())
                .overlay(Circle().stroke(DSColor.subtleStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func move(by offset: Int) {
        avatarKey = FamilyIdentityOptions.avatarKeys[wrappedIndex(selectedIndex + offset)]
    }

    private func wrappedIndex(_ index: Int) -> Int {
        let count = FamilyIdentityOptions.avatarKeys.count
        return (index % count + count) % count
    }
}

struct FamilyIdentityPicker: View {
    @Binding var identityLabel: String
    @Binding var customIdentity: String
    @Binding var avatarKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                FamilyFlowSectionLabel(title: "选择你的形象")
                FamilyAvatarCarousel(avatarKey: $avatarKey)
            }

            VStack(alignment: .leading, spacing: 10) {
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
                            .font(.system(size: 16, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DSColor.mutedInk)
                    }
                    .foregroundStyle(DSColor.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(DSColor.pureSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(DSColor.subtleStroke, lineWidth: 1)
                    )
                }

                if identityLabel == "自定义" {
                    FamilyFlowTextField(
                        placeholder: "输入自定义身份",
                        systemImage: "pencil",
                        text: $customIdentity
                    )
                }

                Text("上下滑动选择")
                    .font(.system(size: 10))
                    .foregroundStyle(DSColor.mutedInk.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
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
}
