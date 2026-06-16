import SwiftUI

struct FamilyDashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    monthlySummary
                    leaderboard
                    todayActivity
                }
                .padding(20)
            }
        }
        .navigationTitle("家庭战况")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("家庭战况")
                .font(.appTitle())
                .foregroundStyle(DSColor.ink)
            Text("\(viewModel.familyDisplayName) 的本月劳动播报。")
                .font(.appBody())
                .foregroundStyle(DSColor.mutedInk)
        }
    }

    private var monthlySummary: some View {
        DSCard(fill: DSColor.yellow) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 34, weight: .black))
                    .frame(width: 58, height: 58)
                    .background(DSColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DSColor.ink, lineWidth: 2)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(monthlyTotalPoints) 分")
                        .font(.appHeadline(28))
                    Text("本月全家总积分，先记账，后邀功。")
                        .font(.appBody(14))
                        .foregroundStyle(DSColor.mutedInk)
                }
            }
        }
    }

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本月排行榜")
                .font(.appHeadline())
                .foregroundStyle(DSColor.ink)

            ForEach(Array(viewModel.monthlyRanking.enumerated()), id: \.element.id) { index, member in
                DSCard(fill: member.color) {
                    HStack(spacing: 14) {
                        Text("#\(index + 1)")
                            .font(.appHeadline(20))
                            .frame(width: 52, height: 44)
                            .background(DSColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(DSColor.ink, lineWidth: 2)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name)
                                .font(.appHeadline(18))
                            Text(member.badge)
                                .font(.appBody(13))
                                .foregroundStyle(DSColor.mutedInk)
                        }

                        Spacer()

                        Text("\(member.monthlyPoints)")
                            .font(.appHeadline(24))
                    }
                    .foregroundStyle(DSColor.ink)
                }
            }
        }
    }

    private var todayActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日动态")
                .font(.appHeadline())
                .foregroundStyle(DSColor.ink)

            ForEach(viewModel.todayRecords) { record in
                DSCard {
                    HStack(spacing: 13) {
                        Image(systemName: record.icon)
                            .font(.system(size: 20, weight: .black))
                            .frame(width: 42, height: 42)
                            .background(record.color)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(DSColor.ink, lineWidth: 2)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(record.memberName) 完成 \(record.choreName)")
                                .font(.appHeadline(17))
                            Text("\(record.minutes) 分钟 · +\(record.points) 分")
                                .font(.appBody(13))
                                .foregroundStyle(DSColor.mutedInk)
                        }

                        Spacer()
                    }
                    .foregroundStyle(DSColor.ink)
                }
            }
        }
    }

    private var monthlyTotalPoints: Int {
        viewModel.monthlyRanking.reduce(0) { $0 + $1.monthlyPoints }
    }
}

#Preview {
    NavigationStack {
        FamilyDashboardView()
            .environmentObject(AppViewModel.previewHomeAfterNewRecord())
    }
}
