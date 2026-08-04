import Foundation
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let activityPreviewLimit = 5

    var body: some View {
        ZStack {
            DSColor.floatingPageBackground.ignoresSafeArea()

            List {
                header.homeListRow(top: 10, bottom: 10)
                familyScoreCard.homeListRow(top: 4, bottom: 14)
                personalStatsCard.homeListRow(top: 2, bottom: 16)

                Section {
                    if viewModel.isLoading {
                        loadingCard.homeListRow()
                    }

                    if viewModel.isOffline {
                        offlineCard.homeListRow()
                    }

                    if let errorMessage = viewModel.errorMessage {
                        errorCard(errorMessage).homeListRow()
                    }

                    if !viewModel.isLoading && viewModel.errorMessage == nil && displayedActivity.isEmpty {
                        emptyActivityCard.homeListRow()
                    }

                    ForEach(Array(displayedActivity.enumerated()), id: \.element.id) { index, record in
                        ActivityRow(
                            record: record,
                            presentation: .grouped(
                                isFirst: index == 0,
                                isLast: index == displayedActivity.count - 1
                            )
                        )
                        .homeListRow(top: 0, bottom: 0)
                    }
                } header: {
                    activityHeader
                        .textCase(nil)
                        .homeSectionHeaderInsets()
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(10)
            .environment(\.defaultMinListRowHeight, 1)
            .scrollContentBackground(.hidden)
            .refreshable {
                await viewModel.refreshHomeData()
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            viewModel.refreshHomeDataIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("本周战况")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(DSColor.floatingPrimaryText)

            Text("\(viewModel.familyDisplayName) · \(weekDateLabel)")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(DSColor.floatingSecondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var familyScoreCard: some View {
        DSFloatingSurface(cornerRadius: 22, padding: 18, elevation: .primary) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text("家庭本周总积分")
                        .font(.system(size: 17, weight: .regular, design: .default))
                        .foregroundStyle(DSColor.floatingSecondaryText)

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(DSColor.yellow)
                        Text(battleStatus)
                            .foregroundStyle(DSColor.floatingPrimaryText)
                    }
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .symbolRenderingMode(.monochrome)
                }

                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 12) {
                            familyScore
                            Divider()
                            battleLines
                        }
                    } else {
                        HStack(alignment: .center, spacing: 12) {
                            familyScore

                            Divider()
                                .overlay(DSColor.floatingDivider)
                                .frame(height: 88)

                            battleLines
                        }
                    }
                }

                Divider()
                    .overlay(DSColor.floatingDivider)

                HStack(spacing: 7) {
                    Text("共完成")
                    Text("\(viewModel.weekRecordCount)")
                        .foregroundStyle(DSColor.yellow)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .monospacedDigit()
                    Text("次 · 累计")
                    Text("\(totalMinutes)")
                        .foregroundStyle(DSColor.yellow)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .monospacedDigit()
                    Text("分钟")
                }
                .font(DSFont.functionalBody)
                .foregroundStyle(DSColor.floatingSecondaryText)
                .lineLimit(1)
            }
        }
    }

    private var familyScore: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(viewModel.weekPoints)")
                    .font(.system(size: 68, weight: .bold, design: .default))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .layoutPriority(1)
                Text("分")
                    .font(.system(size: 17, weight: .medium, design: .default))
                    .fixedSize()
            }
            .foregroundStyle(DSColor.floatingPrimaryText)
        }
        .frame(width: 142, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("家庭本周总积分 \(viewModel.weekPoints) 分")
    }

    private var battleLines: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("本周战线")
                .font(.system(size: 15, weight: .semibold, design: .default))
                .foregroundStyle(DSColor.floatingPrimaryText)

            ForEach(categoryBattles) { battle in
                HStack(spacing: 7) {
                    Text(battle.name)
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundStyle(DSColor.floatingSecondaryText)
                        .frame(width: 36, alignment: .leading)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(DSColor.floatingDivider.opacity(0.65))

                            Capsule()
                                .fill(battle.color)
                                .frame(
                                    width: max(
                                        battle.count == 0 ? 0 : 10,
                                        proxy.size.width * battle.fraction
                                    )
                                )
                        }
                    }
                    .frame(height: 9)

                    Text("\(battle.count)次")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundStyle(DSColor.floatingSecondaryText)
                        .monospacedDigit()
                        .frame(width: 34, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(battle.name) \(battle.count) 次")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var personalStatsCard: some View {
        DSFloatingSurface(cornerRadius: 18, padding: 11, elevation: .secondary) {
            HStack(spacing: 0) {
                personalMetric(
                    title: "本周积分",
                    value: "\(myWeekPoints)",
                    suffix: "",
                    color: DashboardPalette.metricBlue
                )

                Divider()
                    .overlay(DSColor.floatingDivider)
                    .frame(height: 46)

                personalMetric(
                    title: "完成",
                    value: "\(myWeekRecords.count)",
                    suffix: "次",
                    color: DashboardPalette.metricGreen
                )

                Divider()
                    .overlay(DSColor.floatingDivider)
                    .frame(height: 46)

                personalMetric(
                    title: "家庭第",
                    value: familyRank.map { String($0) } ?? "-",
                    suffix: familyRank == nil ? "" : "名",
                    color: DashboardPalette.metricOrange
                )
            }
        }
    }

    private func personalMetric(
        title: String,
        value: String,
        suffix: String,
        color: Color
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(DSColor.floatingSecondaryText)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .default))
                    .foregroundStyle(color)
                    .monospacedDigit()

                if !suffix.isEmpty {
                    Text(suffix)
                        .font(DSFont.functionalBody)
                        .foregroundStyle(DSColor.floatingSecondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var activityHeader: some View {
        HStack(spacing: 12) {
            Text("家庭动态")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(DSColor.floatingPrimaryText)

            Spacer()

            if !viewModel.recentRecords.isEmpty {
                NavigationLink {
                    FamilyActivityListView()
                } label: {
                    HStack(spacing: 5) {
                        Text("查看全部")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(DSColor.infoBlue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看全部家庭动态")
            } else {
                Text("共 \(viewModel.recentRecords.count) 条")
                    .font(DSFont.functionalCaption)
                    .foregroundStyle(DSColor.mutedInk)
            }
        }
    }

    private var loadingCard: some View {
        DSQuietCard(fill: DSColor.pureSurface) {
            HStack(spacing: 12) {
                ProgressView()
                Text(viewModel.loadingMessage ?? "正在同步家庭战况")
                    .font(DSFont.functionalBody)
            }
            .foregroundStyle(DSColor.mutedInk)
        }
    }

    private func errorCard(_ message: String) -> some View {
        DSRequestFailureView(
            title: "家庭动态加载失败",
            message: friendlyErrorMessage(message),
            retryAction: viewModel.retryHomeData
        )
    }

    private var offlineCard: some View {
        DSOfflineStatusView(lastUpdatedAt: viewModel.lastSuccessfulSyncAt)
    }

    private var emptyActivityCard: some View {
        DSEmptyStateView(
            title: "本周还没有人记功",
            message: "第一笔家务，等你来打响。",
            avatarKey: "home_empty_waiting_avatar",
            actionTitle: "去记一下",
            actionSystemImage: "plus.circle"
        ) {
            viewModel.showChoreSelection()
        }
    }

    private func friendlyErrorMessage(_ message: String) -> String {
        if viewModel.isOffline {
            return "网络开了个小差，请检查连接后重试。"
        }
        return message
    }

    private var displayedActivity: [ChoreRecord] {
        return Array(viewModel.recentRecords.prefix(activityPreviewLimit))
    }

    private var totalMinutes: Int {
        viewModel.weekRecords.reduce(0) { $0 + $1.actualMinutes }
    }

    private var myWeekRecords: [ChoreRecord] {
        viewModel.weekRecords.filter { record in
            if let currentUserID = viewModel.currentUser?.id,
               record.creatorId == currentUserID {
                return true
            }
            return record.memberName == viewModel.currentUserName
        }
    }

    private var myWeekPoints: Int {
        myWeekRecords.reduce(0) { $0 + $1.points }
    }

    private var familyRank: Int? {
        viewModel.weekRanking.firstIndex { member in
            if let currentUserID = viewModel.currentUser?.id,
               member.id == currentUserID {
                return true
            }
            return member.name == viewModel.currentUserName
        }.map { $0 + 1 }
    }

    private var categoryBattles: [CategoryBattle] {
        let grouped = Dictionary(grouping: viewModel.weekRecords) { record in
            ChoreCategory.resolve(record.category, choreName: record.choreName).rawValue
        }
        let battles = grouped.map { category, records in
            CategoryBattle(
                name: compactCategoryName(category),
                count: records.count,
                color: categoryColor(category)
            )
        }
        .sorted {
            if $0.count == $1.count {
                return $0.name < $1.name
            }
            return $0.count > $1.count
        }

        var visible = Array(battles.prefix(3))
        let defaults = [
            CategoryBattle(name: "烹饪", count: 0, color: DSColor.yellow),
            CategoryBattle(name: "清洁", count: 0, color: DSColor.mint),
            CategoryBattle(name: "洗护", count: 0, color: DSColor.infoBlue),
        ]

        for fallback in defaults
        where visible.count < 3 && !visible.contains(where: { $0.name == fallback.name }) {
            visible.append(fallback)
        }

        let maxCount = max(visible.map(\.count).max() ?? 1, 1)
        return visible.map {
            CategoryBattle(
                name: $0.name,
                count: $0.count,
                color: $0.color,
                fraction: CGFloat($0.count) / CGFloat(maxCount)
            )
        }
    }

    private var battleStatus: String {
        switch viewModel.weekPoints {
        case 0:
            return "战局待开"
        case 1..<60:
            return "开始升温"
        default:
            return "火力正旺"
        }
    }

    private func categoryColor(_ category: String) -> Color {
        switch ChoreCategory.resolve(category) {
        case .cooking: return DSColor.yellow
        case .cleaning: return DSColor.mint
        case .laundryCare: return DSColor.infoBlue
        case .organizing: return DSColor.lavender
        case .caregiving: return DSColor.coral
        case .household: return DSColor.accentOrange
        }
    }

    private func compactCategoryName(_ category: String) -> String {
        switch ChoreCategory.resolve(category) {
        case .cooking: return "烹饪"
        case .cleaning: return "清洁"
        case .laundryCare: return "洗护"
        case .organizing: return "收纳"
        case .caregiving: return "照护"
        case .household: return "事务"
        }
    }

    private var weekDateLabel: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.firstWeekday = 2

        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return Date().formatted(.dateTime.month().day())
        }

        let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let startText = interval.start.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
        let endText = end.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
        return "\(startText) - \(endText)"
    }
}

private struct CategoryBattle: Identifiable {
    let name: String
    let count: Int
    let color: Color
    var fraction: CGFloat = 0

    var id: String { name }
}

private enum DashboardPalette {
    static let metricBlue = Color(red: 0.08, green: 0.56, blue: 0.98)
    static let metricGreen = Color(red: 0.12, green: 0.76, blue: 0.45)
    static let metricOrange = Color(red: 1.00, green: 0.36, blue: 0.03)
}

private struct FamilyActivityListView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            List {
                ForEach(Array(viewModel.recentRecords.enumerated()), id: \.element.id) { index, record in
                    ActivityRow(
                        record: record,
                        presentation: .grouped(
                            isFirst: index == 0,
                            isLast: index == viewModel.recentRecords.count - 1
                        )
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable {
                await viewModel.refreshHomeData()
            }
        }
        .navigationTitle("家庭动态")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension View {
    func homeListRow(top: CGFloat = 7, bottom: CGFloat = 7) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    func homeSectionHeaderInsets() -> some View {
        listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 7, trailing: 20))
    }
}

#Preview("本周战况") {
    NavigationStack {
        HomeView()
            .environmentObject(AppViewModel.previewHomeAfterNewRecord())
    }
}
