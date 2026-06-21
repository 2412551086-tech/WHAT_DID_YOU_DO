import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()

            List {
                header.homeListRow()
                metrics.homeListRow()
                quickActions.homeListRow()
                ranking.homeListRow()

                Section {
                    if viewModel.isLoading {
                        DSCard(fill: DSColor.sky) {
                            Label(viewModel.loadingMessage ?? "正在同步", systemImage: "arrow.triangle.2.circlepath")
                                .font(.appBody(15))
                                .foregroundStyle(DSColor.ink)
                        }
                        .homeListRow()
                    }

                    if let errorMessage = viewModel.errorMessage {
                        DSCard(fill: DSColor.coral) {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.appBody(15))
                                .foregroundStyle(DSColor.ink)
                        }
                        .homeListRow()
                    }

                    ForEach(viewModel.recentRecords) { record in
                        ActivityRow(record: record)
                            .homeListRow()
                    }
                } header: {
                    Text("家庭动态")
                        .font(.appHeadline())
                        .foregroundStyle(DSColor.ink)
                        .textCase(nil)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationBarBackButtonHidden(true)
        .task {
            viewModel.refreshHomeDataIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.familyDisplayName)
                .font(.appTitle(32))
                .foregroundStyle(DSColor.ink)
            Text("\(viewModel.currentIdentityDisplayName) · \(viewModel.currentUserName)，今日家庭劳动广播站已开机。")
                .font(.appBody())
                .foregroundStyle(DSColor.mutedInk)
        }
        .padding(.top, 12)
    }

    private var metrics: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            DSMetricPill(title: "今日积分", value: "\(viewModel.todayPoints)", color: DSColor.yellow)
            DSMetricPill(title: "今日记录", value: "\(viewModel.todayRecordCount) 项", color: DSColor.mint)
            DSMetricPill(title: "榜首", value: viewModel.leader?.name ?? "-", color: DSColor.sky)
            DSMetricPill(title: "图片凭证", value: "即将开放", color: DSColor.lavender)
        }
    }

    private var quickActions: some View {
        DSCard(fill: DSColor.surface) {
            VStack(alignment: .leading, spacing: 14) {
                Text("快速记一笔")
                    .font(.appHeadline())
                Text("5 到 15 秒完成一次普通家务记录，先从核心 10 项开始。")
                    .font(.appBody(14))
                    .foregroundStyle(DSColor.mutedInk)
                Label(
                    "家庭邀请码：\(viewModel.currentFamily?.inviteCode ?? MockData.family.inviteCode)",
                    systemImage: "number.square.fill"
                )
                .font(.appBody(14))
                .foregroundStyle(DSColor.ink)
                DSButton(title: "记一下", systemImage: "plus.circle.fill", style: .primary) {
                    viewModel.showChoreSelection()
                }
                .disabled(viewModel.isLoading)
            }
        }
    }

    private var ranking: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("家庭排行")
                .font(.appHeadline())
            ForEach(Array(viewModel.monthlyRanking.enumerated()), id: \.element.id) { index, member in
                DSCard(fill: member.color) {
                    HStack(spacing: 14) {
                        Text("\(index + 1)")
                            .font(.appHeadline(24))
                            .frame(width: 44, height: 44)
                            .background(DSColor.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(DSColor.ink, lineWidth: 2))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name)
                                .font(.appHeadline(18))
                            Text(member.badge)
                                .font(.appBody(13))
                                .foregroundStyle(DSColor.mutedInk)
                        }
                        Spacer()
                        Text("\(member.monthlyPoints)")
                            .font(.appHeadline(22))
                    }
                }
            }
        }
    }

}

private extension View {
    func homeListRow() -> some View {
        listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AppViewModel.previewHomeAfterNewRecord())
    }
}
