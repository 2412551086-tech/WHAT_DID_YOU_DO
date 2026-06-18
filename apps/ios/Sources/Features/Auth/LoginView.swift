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
                            Label("\(viewModel.modeLabel) 已就位", systemImage: "person.crop.circle.badge.checkmark")
                                .font(.appHeadline())
                            Text("点击任意登录按钮，会进入创建家庭流程；API 模式会调用本地后端。")
                                .font(.appBody(15))
                                .foregroundStyle(DSColor.mutedInk)
                        }
                    }

                    statusBanner

                    VStack(spacing: 14) {
                        DSTextField(title: "手机号", systemImage: "iphone", text: $viewModel.phoneNumber)
                        DSButton(title: "手机号登录", systemImage: "message.fill", style: .primary) {
                            viewModel.mockLogin()
                        }
                        DSButton(title: "Apple ID 登录", systemImage: "apple.logo", style: .secondary) {
                            viewModel.mockLogin()
                        }
                        DSButton(title: "微信登录", systemImage: "bubble.left.and.bubble.right.fill", style: .secondary) {
                            viewModel.mockLogin()
                        }
                    }
                    .disabled(viewModel.isLoading)

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

    @ViewBuilder
    private var statusBanner: some View {
        if viewModel.isLoading {
            DSCard(fill: DSColor.sky) {
                Label(viewModel.loadingMessage ?? "正在处理", systemImage: "arrow.triangle.2.circlepath")
                    .font(.appBody(15))
                    .foregroundStyle(DSColor.ink)
            }
        }

        if let errorMessage = viewModel.errorMessage {
            DSCard(fill: DSColor.coral) {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.appBody(15))
                    .foregroundStyle(DSColor.ink)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppViewModel(forceMockData: true))
}
