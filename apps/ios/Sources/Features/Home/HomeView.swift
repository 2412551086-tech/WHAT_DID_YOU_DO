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

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    metrics
                    quickActions
                    ranking
                    activityFeed
                }
                .padding(20)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.familyDisplayName)
                .font(.appTitle(32))
                .foregroundStyle(DSColor.ink)
            Text("\(viewModel.currentUserName)，今日家庭劳动广播站已开机。")
                .font(.appBody())
                .foregroundStyle(DSColor.mutedInk)
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            DSMetricPill(title: "今日积分", value: "\(viewModel.todayPoints)", color: DSColor.yellow)
            DSMetricPill(title: "今日记录", value: "\(viewModel.todayRecordCount) 项", color: DSColor.mint)
            DSMetricPill(title: "榜首", value: viewModel.leader?.name ?? "-", color: DSColor.sky)
            DSMetricPill(title: "图片凭证", value: viewModel.currentFamily?.requiresPhotoProof == true ? "需要" : "不需要", color: DSColor.lavender)
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
                DSButton(title: "记一下", systemImage: "plus.circle.fill", style: .primary) {
                    viewModel.showChoreSelection()
                }
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

    private var activityFeed: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("家庭动态")
                .font(.appHeadline())
            ForEach(viewModel.todayRecords) { record in
                DSCard {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Label("\(record.memberName) 完成 \(record.choreName)", systemImage: record.icon)
                                .font(.appHeadline(17))
                            Spacer()
                            Text("+\(record.points)")
                                .font(.appHeadline(18))
                        }
                        Text("\(record.choreName) · \(record.actualMinutes) 分钟 · +\(record.points) 分")
                            .font(.appBody(14))
                            .foregroundStyle(DSColor.mutedInk)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AppViewModel.previewHomeAfterNewRecord())
    }
}
