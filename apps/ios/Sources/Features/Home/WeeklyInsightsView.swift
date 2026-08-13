import SwiftUI

enum WeeklyInsightsScope {
    case family
    case member(userId: String?, name: String, avatarKey: String?)
}

struct WeeklyInsightsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let scope: WeeklyInsightsScope

    var body: some View {
        ZStack {
            DSColor.floatingPageBackground.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    overviewCard
                    dailyTrendCard

                    if isFamilyScope, !memberContributions.isEmpty {
                        memberContributionCard
                    } else if !isFamilyScope, !records.isEmpty {
                        personalAnalysisCard
                    }

                    if !categoryStats.isEmpty {
                        categoryCard
                    }

                    activitySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .refreshable {
                await viewModel.refreshHomeData()
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var overviewCard: some View {
        DSFloatingSurface(cornerRadius: 22, padding: 18, elevation: .primary) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 12) {
                    if case let .member(_, name, avatarKey) = scope {
                        AvatarView(
                            avatarKey: avatarKey,
                            fallbackText: name,
                            size: 52,
                            presentation: .flat
                        )
                    } else {
                        Image(systemName: "house.fill")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(DSColor.yellow)
                            .frame(width: 44, height: 44)
                            .background(DSColor.yellow.opacity(0.12))
                            .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(overviewTitle)
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(DSColor.floatingPrimaryText)
                        Text(viewModel.selectedWeekAccessibilityLabel)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(DSColor.floatingSecondaryText)
                    }

                    Spacer()
                }

                Divider().overlay(DSColor.floatingDivider)

                HStack(spacing: 0) {
                    metric(title: "积分", value: "\(totalPoints)", suffix: "分", color: DSColor.infoBlue)
                    Divider().frame(height: 46).overlay(DSColor.floatingDivider)
                    metric(title: "完成", value: "\(records.count)", suffix: "次", color: DSColor.mint)
                    Divider().frame(height: 46).overlay(DSColor.floatingDivider)
                    metric(
                        title: overviewThirdMetric.title,
                        value: overviewThirdMetric.value,
                        suffix: overviewThirdMetric.suffix,
                        color: DSColor.accentOrange
                    )
                }

                Text(summarySentence)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(DSColor.floatingSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var dailyTrendCard: some View {
        insightCard(title: "每日走势", subtitle: busiestDaySummary) {
            HStack(alignment: .bottom, spacing: 9) {
                ForEach(dailyStats) { day in
                    VStack(spacing: 7) {
                        Text(day.points == 0 ? "" : "\(day.points)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DSColor.mutedInk)
                            .frame(height: 13)

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(day.points == 0 ? DSColor.floatingDivider : DSColor.infoBlue.opacity(0.82))
                            .frame(height: max(8, 72 * day.fraction))

                        Text(day.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(day.isToday ? DSColor.infoBlue : DSColor.mutedInk)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("周\(day.label)，\(day.recordCount) 次，\(day.points) 分")
                }
            }
            .frame(height: 108, alignment: .bottom)
        }
    }

    private var memberContributionCard: some View {
        insightCard(title: "成员贡献", subtitle: "看看这一周是谁把功劳簿写得最满") {
            VStack(spacing: 13) {
                ForEach(memberContributions) { contribution in
                    HStack(spacing: 11) {
                        AvatarView(
                            avatarKey: contribution.avatarKey,
                            fallbackText: contribution.name,
                            size: 38,
                            presentation: .flat
                        )

                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(contribution.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(DSColor.ink)
                                Spacer()
                                Text("\(contribution.points) 分 · \(contribution.recordCount) 次")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DSColor.mutedInk)
                            }

                            GeometryReader { proxy in
                                Capsule()
                                    .fill(DSColor.floatingDivider)
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(contribution.color)
                                            .frame(width: proxy.size.width * contribution.fraction)
                                    }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
        }
    }

    private var personalAnalysisCard: some View {
        insightCard(title: "个人分析", subtitle: personalSummary) {
            HStack(spacing: 0) {
                analysisMetric(title: "最常做", value: topChoreName, systemImage: "repeat")
                Divider().frame(height: 48).overlay(DSColor.floatingDivider)
                analysisMetric(title: "主要投入", value: topCategoryName, systemImage: "chart.pie.fill")
                Divider().frame(height: 48).overlay(DSColor.floatingDivider)
                analysisMetric(title: "平均每次", value: "\(averageMinutes) 分钟", systemImage: "clock.fill")
            }
        }
    }

    private var categoryCard: some View {
        insightCard(title: "家务结构", subtitle: "按本周积分查看投入方向") {
            VStack(spacing: 12) {
                ForEach(categoryStats) { category in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(category.color)
                            .frame(width: 9, height: 9)
                        Text(category.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DSColor.ink)
                            .frame(width: 42, alignment: .leading)
                        GeometryReader { proxy in
                            Capsule()
                                .fill(DSColor.floatingDivider)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(category.color)
                                        .frame(width: proxy.size.width * category.fraction)
                                }
                        }
                        .frame(height: 8)
                        Text("\(category.points) 分")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DSColor.mutedInk)
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(isFamilyScope ? "本周家庭动态" : "我的本周动态")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(DSColor.ink)
                Spacer()
                Text("\(records.count) 条")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DSColor.mutedInk)
            }

            if records.isEmpty {
                DSEmptyStateView(
                    title: "这一周还没有记录",
                    message: isFamilyScope ? "家庭功劳簿正在等第一笔。" : "做都做了，下次记得把功劳领走。",
                    systemImage: "calendar.badge.plus"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        ActivityRow(
                            record: record,
                            presentation: .grouped(
                                isFirst: index == 0,
                                isLast: index == records.count - 1
                            )
                        )
                    }
                }
            }
        }
    }

    private func insightCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        DSFloatingSurface(cornerRadius: 18, padding: 16, elevation: .secondary) {
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(DSColor.ink)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(DSColor.mutedInk)
                }
                content()
            }
        }
    }

    private func metric(title: String, value: String, suffix: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(DSColor.mutedInk)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
                Text(suffix)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(DSColor.mutedInk)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func analysisMetric(title: String, value: String, systemImage: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DSColor.infoBlue)
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(DSColor.mutedInk)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DSColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }

    private var records: [ChoreRecord] {
        switch scope {
        case .family:
            return viewModel.weekRecords
        case let .member(userId, name, _):
            return viewModel.weekRecords.filter { record in
                if let userId, let creatorId = record.creatorId {
                    return creatorId == userId
                }
                return record.memberName == name
            }
        }
    }

    private var isFamilyScope: Bool {
        if case .family = scope { return true }
        return false
    }

    private var navigationTitle: String {
        isFamilyScope ? "家庭周报" : "个人周报"
    }

    private var overviewTitle: String {
        switch scope {
        case .family: return viewModel.familyDisplayName
        case let .member(_, name, _): return "\(name)的本周"
        }
    }

    private var totalPoints: Int { records.reduce(0) { $0 + $1.points } }
    private var totalMinutes: Int { records.reduce(0) { $0 + $1.actualMinutes } }
    private var averageMinutes: Int { records.isEmpty ? 0 : Int((Double(totalMinutes) / Double(records.count)).rounded()) }

    private var overviewThirdMetric: (title: String, value: String, suffix: String) {
        guard !isFamilyScope else {
            return ("投入", "\(totalMinutes)", "分钟")
        }
        return ("家庭第", personalFamilyRank.map(String.init) ?? "-", personalFamilyRank == nil ? "" : "名")
    }

    private var personalFamilyRank: Int? {
        guard case let .member(userId, name, _) = scope else { return nil }
        return viewModel.weekRanking.firstIndex { member in
            if let userId { return member.id == userId }
            return member.name == name
        }.map { $0 + 1 }
    }

    private var summarySentence: String {
        guard !records.isEmpty else {
            return isFamilyScope ? "这一周还没开战，第一笔功劳正在等人认领。" : "这一周还没有个人记录。"
        }
        if isFamilyScope {
            return "全家共投入 \(totalMinutes) 分钟，完成 \(records.count) 项家务，功劳都记在账上了。"
        }
        return "平均每次投入 \(averageMinutes) 分钟，主要精力放在\(topCategoryName)。"
    }

    private var dailyStats: [WeeklyDayStat] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.firstWeekday = 2
        calendar.timeZone = viewModel.currentFamily?.timezone.flatMap(TimeZone.init(identifier:)) ?? .autoupdatingCurrent
        let anchor = calendar.date(byAdding: .weekOfYear, value: viewModel.selectedWeekOffset, to: Date()) ?? Date()
        let start = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start ?? anchor
        let grouped = Dictionary(grouping: records) { calendar.startOfDay(for: $0.createdAt) }
        let raw = (0..<7).map { offset -> (Date, [ChoreRecord]) in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return (date, grouped[calendar.startOfDay(for: date)] ?? [])
        }
        let maxPoints = max(raw.map { $0.1.reduce(0) { $0 + $1.points } }.max() ?? 1, 1)
        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        return raw.enumerated().map { index, entry in
            let points = entry.1.reduce(0) { $0 + $1.points }
            return WeeklyDayStat(
                date: entry.0,
                label: labels[index],
                points: points,
                recordCount: entry.1.count,
                fraction: CGFloat(points) / CGFloat(maxPoints),
                isToday: calendar.isDateInToday(entry.0)
            )
        }
    }

    private var busiestDaySummary: String {
        guard let day = dailyStats.max(by: { $0.points < $1.points }), day.points > 0 else {
            return "每天的投入会在这里形成一条战线"
        }
        return "周\(day.label)最忙，拿下 \(day.points) 分"
    }

    private var memberContributions: [WeeklyMemberContribution] {
        let grouped = Dictionary(grouping: records) { $0.creatorId ?? $0.memberName }
        let raw = grouped.map { key, memberRecords in
            let member = viewModel.familyMembers.first { $0.userId == key }
            return WeeklyMemberContribution(
                id: key,
                name: member?.name ?? memberRecords.first?.memberName ?? "家庭成员",
                avatarKey: member?.avatarKey ?? memberRecords.first?.avatarKey,
                points: memberRecords.reduce(0) { $0 + $1.points },
                recordCount: memberRecords.count,
                color: FamilyIdentityOptions.accentColor(for: member?.avatarKey ?? memberRecords.first?.avatarKey)
            )
        }
        .sorted { $0.points == $1.points ? $0.name < $1.name : $0.points > $1.points }
        let maxPoints = max(raw.map(\.points).max() ?? 1, 1)
        return raw.map {
            var copy = $0
            copy.fraction = CGFloat($0.points) / CGFloat(maxPoints)
            return copy
        }
    }

    private var categoryStats: [WeeklyCategoryStat] {
        let grouped = Dictionary(grouping: records) {
            ChoreCategory.resolve($0.category, choreName: $0.choreName)
        }
        let raw = grouped.map { category, categoryRecords in
            WeeklyCategoryStat(
                category: category,
                points: categoryRecords.reduce(0) { $0 + $1.points },
                recordCount: categoryRecords.count
            )
        }
        .sorted { $0.points > $1.points }
        let maxPoints = max(raw.map(\.points).max() ?? 1, 1)
        return raw.map {
            var copy = $0
            copy.fraction = CGFloat($0.points) / CGFloat(maxPoints)
            return copy
        }
    }

    private var topCategoryName: String { categoryStats.first?.name ?? "暂无" }

    private var topChoreName: String {
        Dictionary(grouping: records, by: \.choreName)
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
            .first?.0 ?? "暂无"
    }

    private var personalSummary: String {
        guard !records.isEmpty else { return "有记录后会生成个人习惯分析" }
        return "本周最常做“\(topChoreName)”，累计投入 \(totalMinutes) 分钟"
    }
}

private struct WeeklyDayStat: Identifiable {
    let date: Date
    let label: String
    let points: Int
    let recordCount: Int
    let fraction: CGFloat
    let isToday: Bool
    var id: Date { date }
}

private struct WeeklyMemberContribution: Identifiable {
    let id: String
    let name: String
    let avatarKey: String?
    let points: Int
    let recordCount: Int
    let color: Color
    var fraction: CGFloat = 0
}

private struct WeeklyCategoryStat: Identifiable {
    let category: ChoreCategory
    let points: Int
    let recordCount: Int
    var fraction: CGFloat = 0
    var id: String { category.rawValue }
    var name: String { category.rawValue }

    var color: Color {
        switch category {
        case .cooking: return DSColor.yellow
        case .cleaning: return DSColor.mint
        case .laundryCare: return DSColor.infoBlue
        case .organizing: return DSColor.lavender
        case .caregiving: return DSColor.coral
        case .household: return DSColor.accentOrange
        }
    }
}

#Preview("家庭周报") {
    NavigationStack {
        WeeklyInsightsView(scope: .family)
            .environmentObject(AppViewModel.previewHomeAfterNewRecord())
    }
}

#Preview("个人周报") {
    NavigationStack {
        WeeklyInsightsView(scope: .member(userId: "user-1", name: "小林", avatarKey: "avatar_01"))
            .environmentObject(AppViewModel.previewHomeAfterNewRecord())
    }
}
