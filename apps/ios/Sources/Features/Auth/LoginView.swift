import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("你今天干啥啦")
                            .font(.appTitle(38))
                            .foregroundStyle(DSColor.ink)
                        Text("家务不是没人做，只是还没被记上功劳簿。")
                            .font(.appBody())
                            .foregroundStyle(DSColor.mutedInk)
                    }
                    .padding(.top, 34)

                    DSCard(fill: DSColor.yellow) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("先假装已经接入登录", systemImage: "person.crop.circle.badge.checkmark")
                                .font(.appHeadline())
                            Text("MVP 先用 Mock 账户走通创建家庭、首页和家务选择流程。")
                                .font(.appBody(15))
                                .foregroundStyle(DSColor.mutedInk)
                        }
                    }

                    VStack(spacing: 14) {
                        DSTextField(title: "手机号", systemImage: "iphone", text: $viewModel.phoneNumber)
                        DSButton(title: "手机号登录", systemImage: "message.fill", style: .primary) {
                            viewModel.continueFromLogin()
                        }
                        DSButton(title: "Apple ID 登录", systemImage: "apple.logo", style: .secondary) {
                            viewModel.continueFromLogin()
                        }
                        DSButton(title: "微信登录", systemImage: "bubble.left.and.bubble.right.fill", style: .secondary) {
                            viewModel.continueFromLogin()
                        }
                    }

                    DSCard {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 28, weight: .black))
                            Text("登录后进入家庭空间，开始把隐形劳动变成明晃晃的积分。")
                                .font(.appBody(15))
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    LoginView()
        .environmentObject(AppViewModel())
}
