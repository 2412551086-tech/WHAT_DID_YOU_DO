import SwiftUI

struct CreateFamilyView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("创建家庭")
                        .font(.appTitle())
                        .foregroundStyle(DSColor.ink)
                        .padding(.top, 16)

                    DSCard(fill: DSColor.mint) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("给家务现场起个响亮名字")
                                .font(.appHeadline())
                            Text("比如“周末厨房保卫处”或者“沙发塌陷研究所”。")
                                .font(.appBody(15))
                                .foregroundStyle(DSColor.mutedInk)
                        }
                    }

                    VStack(spacing: 16) {
                        DSTextField(title: "家庭名称", systemImage: "house.fill", text: $viewModel.familyName)

                        DSCard {
                            Toggle(isOn: $viewModel.requiresPhotoProof) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("需要图片凭证")
                                        .font(.appHeadline(18))
                                    Text("默认关闭，先相信家人，不先审讯家人。")
                                        .font(.appBody(14))
                                        .foregroundStyle(DSColor.mutedInk)
                                }
                            }
                            .tint(DSColor.coral)
                        }

                        DSButton(title: "创建并进入首页", systemImage: "arrow.right.circle.fill", style: .primary) {
                            viewModel.createFamily()
                        }
                    }

                    DSCard(fill: DSColor.sky) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("MVP 规则")
                                .font(.appHeadline(18))
                            Text("先使用核心 10 个免费家务事项，成员和记录全部来自 Mock 数据。")
                                .font(.appBody(14))
                                .foregroundStyle(DSColor.mutedInk)
                        }
                    }
                }
                .padding(20)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CreateFamilyView()
            .environmentObject(AppViewModel())
    }
}
