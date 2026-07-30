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
                    Text(viewModel.monthlyReport?.headline ?? "本月全家总积分，先记账，后邀功。")
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
                DSRankingRow(index: index, member: member)
            }
        }
    }

    private var todayActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日动态")
                .font(.appHeadline())
                .foregroundStyle(DSColor.ink)

            ForEach(viewModel.todayRecords) { record in
                ActivityRow(record: record)
            }
        }
    }

    private var monthlyTotalPoints: Int {
        viewModel.monthlyReport?.totalPoints ?? viewModel.monthlyRanking.reduce(0) { $0 + $1.monthlyPoints }
    }
}

#Preview {
    NavigationStack {
        FamilyDashboardView()
            .environmentObject(AppViewModel.previewHomeAfterNewRecord())
    }
}
