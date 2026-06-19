import SwiftUI

enum FamilyIdentityOptions {
    static let identities = [
        "男主人", "女主人", "老公", "老婆", "老妈", "老爸", "儿子", "女儿",
        "哥哥", "姐姐", "弟弟", "妹妹", "爷爷", "奶奶", "室友", "自定义",
    ]

    static let avatarKeys = [
        "avatar_01", "avatar_02", "avatar_03", "avatar_04", "avatar_05", "avatar_06",
    ]
}

struct FamilyIdentityPicker: View {
    @Binding var identityLabel: String
    @Binding var customIdentity: String
    @Binding var avatarKey: String

    var body: some View {
        VStack(spacing: 16) {
            DSCard(fill: DSColor.yellow) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("家庭身份", systemImage: "person.text.rectangle.fill")
                        .font(.appHeadline(18))

                    Picker("家庭身份", selection: $identityLabel) {
                        ForEach(FamilyIdentityOptions.identities, id: \.self) { identity in
                            Text(identity).tag(identity)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(DSColor.ink)
                    .font(.appBody())

                    if identityLabel == "自定义" {
                        DSTextField(
                            title: "输入自定义身份",
                            systemImage: "pencil",
                            text: $customIdentity
                        )
                    }
                }
                .foregroundStyle(DSColor.ink)
            }

            DSCard(fill: DSColor.sky) {
                VStack(alignment: .leading, spacing: 14) {
                    Label("选择头像", systemImage: "person.crop.circle.fill")
                        .font(.appHeadline(18))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(FamilyIdentityOptions.avatarKeys, id: \.self) { key in
                                Button {
                                    avatarKey = key
                                } label: {
                                    AvatarView(avatarKey: key, fallbackText: identityLabel, size: 54)
                                        .padding(5)
                                        .background(avatarKey == key ? DSColor.yellow : Color.clear)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("选择头像 \(key)")
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
                .foregroundStyle(DSColor.ink)
            }
        }
    }
}

#Preview {
    FamilyIdentityPicker(
        identityLabel: .constant("老妈"),
        customIdentity: .constant(""),
        avatarKey: .constant("avatar_01")
    )
    .padding(20)
    .background(DSColor.background)
}
