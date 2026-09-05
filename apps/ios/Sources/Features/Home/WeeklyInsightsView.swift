import SwiftUI

enum WeeklyInsightsScope {
    case family
    case member(userId: String?, name: String, avatarKey: String?)
}

struct WeeklyInsightsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var expandedCategoryID: String?
    @State private var categoryPage = 0
    let scope: WeeklyInsightsScope

    var body: some View {
        ZStack {
            DSColor.floatingPageBackground.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    overviewCard
                    dailyTrendCard

                    if isFamilyScope, let leadingCategory = categoryStats.first {
                        enemyBriefCard(leadingCategory)
                    }

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

    private func enemyBriefCard(_ category: WeeklyCategoryStat) -> some View {
        let enemy = HouseholdBattleNarrative.profile(for: category.category)
        let seed = viewModel.selectedWeekOffset + HouseholdBattleNarrative.index(of: category.category)

        return DSFloatingSurface(cornerRadius: 18, padding: 16, elevation: .secondary) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 12) {
                    Image(systemName: enemy.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(category.color)
                        .frame(width: 42, height: 42)
                        .background(category.color.opacity(0.13))
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("本周头号敌人")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(DSColor.mutedInk)
                        Text(enemy.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(DSColor.ink)
                    }

                    Spacer(minLength: 8)

                    Text(HouseholdBattleNarrative.status(for: category.recordCount))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(category.color)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(category.color.opacity(0.11))
                        .clipShape(Capsule())
                }

                Text(HouseholdBattleNarrative.rotatingLine(for: category.category, seed: seed))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(DSColor.floatingSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    Label("出没 \(category.recordCount) 次", systemImage: "scope")
                    Label("反击 \(category.points) 分", systemImage: "bolt.fill")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DSColor.mutedInk)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "本周头号敌人，\(enemy.name)，出没 \(category.recordCount) 次，反击 \(category.points) 分，\(HouseholdBattleNarrative.status(for: category.recordCount))"
            )
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
            if isFamilyScope {
                VStack(spacing: 12) {
                    TabView(selection: $categoryPage) {
                        categoryOverviewPage
                            .tag(0)

                        categoryMemberPage
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: categoryPagerHeight)
                    .animation(.easeInOut(duration: 0.22), value: categoryPagerHeight)

                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            ForEach(0..<2, id: \.self) { page in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        categoryPage = page
                                    }
                                } label: {
                                    Circle()
                                        .fill(page == categoryPage ? DSColor.infoBlue : DSColor.floatingDivider)
                                        .frame(width: page == categoryPage ? 8 : 6, height: page == categoryPage ? 8 : 6)
                                        .frame(width: 24, height: 24)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(page == 0 ? "查看类别总览" : "查看成员占比")
                            }
                        }

                        Label(categoryPage == 0 ? "类别总览" : "成员占比", systemImage: "arrow.left.and.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DSColor.mutedInk)
                    }
                }
            } else {
                categoryOverviewPage
            }
        }
    }

    private var categoryMemberLegend: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10, alignment: .leading),
                GridItem(.flexible(), spacing: 10, alignment: .leading)
            ],
            alignment: .leading,
            spacing: 4
        ) {
            ForEach(categoryChartMembers) { member in
                HStack(spacing: 6) {
                    if member.isAggregate {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DSColor.floatingSecondaryText)
                            .frame(width: 24, height: 24)
                            .background(DSColor.floatingDivider)
                            .clipShape(Circle())
                    } else {
                        AvatarView(
                            avatarKey: member.avatarKey,
                            fallbackText: member.name,
                            size: 24,
                            presentation: .flat
                        )
                    }

                    Circle()
                        .fill(member.color)
                        .frame(width: 7, height: 7)

                    Text(member.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DSColor.floatingSecondaryText)
                        .lineLimit(1)
                }
                .frame(height: 28, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(member.name)的贡献颜色")
            }
        }
        .padding(.vertical, 2)
    }

    private var categoryOverviewPage: some View {
        VStack(spacing: 0) {
            ForEach(categoryStats) { category in
                personalCategoryRow(category)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var categoryMemberPage: some View {
        VStack(spacing: 10) {
            categoryMemberLegend

            VStack(spacing: 0) {
                ForEach(categoryStats) { category in
                    familyCategoryRow(category)

                    if category.id != categoryStats.last?.id {
                        Divider()
                            .overlay(DSColor.floatingDivider)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var categoryPagerHeight: CGFloat {
        let legendRows = max(1, Int(ceil(Double(categoryChartMembers.count) / 2.0)))
        let legendHeight = CGFloat(legendRows * 32)
        let dividerHeight = CGFloat(max(categoryStats.count - 1, 0))
        let overviewHeight = CGFloat(categoryStats.count) * 40
        let memberRowsHeight = CGFloat(categoryStats.count) * 40 + dividerHeight
        let expandedRows = categoryStats
            .first(where: { $0.id == expandedCategoryID })
            .map { CGFloat($0.memberContributions.count * 34 + 10) } ?? 0
        let memberPageHeight = legendHeight + 10 + memberRowsHeight + expandedRows

        // Both pages share the larger content height so paging never jumps or clips.
        return max(48, max(overviewHeight, memberPageHeight) + 4)
    }

    private func familyCategoryRow(_ category: WeeklyCategoryStat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                expandedCategoryID = expandedCategoryID == category.id ? nil : category.id
            } label: {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(category.color)
                            .frame(width: 9, height: 9)
                        Text(category.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DSColor.ink)
                    }
                    .frame(width: 82, alignment: .leading)

                    memberContributionBar(for: category)

                    Text("\(category.points) 分")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DSColor.mutedInk)
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)

                    Image(systemName: expandedCategoryID == category.id ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DSColor.floatingSecondaryText)
                        .frame(width: 14)
                }
                .frame(height: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(category.name)，共 \(category.points) 分")
            .accessibilityHint(expandedCategoryID == category.id ? "收起成员贡献" : "展开成员贡献")

            if expandedCategoryID == category.id {
                VStack(spacing: 9) {
                    ForEach(category.memberContributions) { contribution in
                        HStack(spacing: 8) {
                            if contribution.isAggregate {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(DSColor.floatingSecondaryText)
                                    .frame(width: 25, height: 25)
                                    .background(DSColor.floatingDivider)
                                    .clipShape(Circle())
                            } else {
                                AvatarView(
                                    avatarKey: contribution.avatarKey,
                                    fallbackText: contribution.name,
                                    size: 25,
                                    presentation: .flat
                                )
                            }

                            Circle()
                                .fill(contribution.color)
                                .frame(width: 7, height: 7)
                            Text(contribution.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(DSColor.ink)
                            Spacer()
                            Text("\(contribution.points) 分 · \(contribution.recordCount) 次")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(DSColor.mutedInk)
                                .monospacedDigit()
                        }
                    }
                }
                .padding(.leading, 18)
                .padding(.top, 2)
            }
        }
    }

    private func memberContributionBar(for category: WeeklyCategoryStat) -> some View {
        GeometryReader { proxy in
            let segmentCount = category.memberContributions.count
            let spacing = CGFloat(max(segmentCount - 1, 0)) * 2
            let availableWidth = max(proxy.size.width - spacing, 0)
            let total = max(category.points, 1)

            HStack(spacing: 2) {
                ForEach(category.memberContributions) { contribution in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(contribution.color)
                        .frame(
                            width: availableWidth * CGFloat(contribution.points) / CGFloat(total),
                            height: 10
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DSColor.floatingDivider)
            .clipShape(Capsule())
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }

    private func personalCategoryRow(_ category: WeeklyCategoryStat) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(category.color)
                    .frame(width: 9, height: 9)
                Text(category.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DSColor.ink)
            }
            .frame(width: 82, alignment: .leading)

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

            Color.clear
                .frame(width: 14, height: 14)
        }
        .frame(height: 40)
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
        var grouped: [String: [ChoreRecord]] = [:]
        for record in records {
            let key = record.creatorId ?? record.memberName
            grouped[key, default: []].append(record)
        }

        var contributions: [WeeklyMemberContribution] = []
        for (key, memberRecords) in grouped {
            let member: FamilyMemberProfile? = viewModel.familyMembers.first(where: { profile in
                profile.userId == key
            })
            let points = memberRecords.reduce(0) { partialResult, record in
                partialResult + record.points
            }
            contributions.append(WeeklyMemberContribution(
                id: key,
                name: member?.name ?? memberRecords.first?.memberName ?? "家庭成员",
                avatarKey: member?.avatarKey ?? memberRecords.first?.avatarKey,
                points: points,
                recordCount: memberRecords.count,
                color: FamilyIdentityOptions.accentColor(for: member?.avatarKey ?? memberRecords.first?.avatarKey)
            ))
        }

        let raw = contributions.sorted { lhs, rhs in
            lhs.points == rhs.points ? lhs.name < rhs.name : lhs.points > rhs.points
        }
        let highestPoints = raw.map { contribution in contribution.points }.max() ?? 1
        let maxPoints = max(highestPoints, 1)
        return raw.map {
            var copy = $0
            copy.fraction = CGFloat($0.points) / CGFloat(maxPoints)
            return copy
        }
    }

    private var categoryStats: [WeeklyCategoryStat] {
        var grouped: [ChoreCategory: [ChoreRecord]] = [:]
        for record in records {
            let category = ChoreCategory.resolve(record.category, choreName: record.choreName)
            grouped[category, default: []].append(record)
        }

        var stats: [WeeklyCategoryStat] = []
        for (category, categoryRecords) in grouped {
            let points = categoryRecords.reduce(0) { partialResult, record in
                partialResult + record.points
            }
            stats.append(WeeklyCategoryStat(
                category: category,
                points: points,
                recordCount: categoryRecords.count,
                memberContributions: isFamilyScope
                    ? categoryChartMembers.compactMap { member in
                        let matchingRecords = categoryRecords.filter { record in
                            member.memberIDs.contains(record.creatorId ?? record.memberName)
                        }
                        guard !matchingRecords.isEmpty else { return nil }
                        return WeeklyCategoryMemberContribution(
                            id: member.id,
                            name: member.name,
                            avatarKey: member.avatarKey,
                            points: matchingRecords.reduce(0) { $0 + $1.points },
                            recordCount: matchingRecords.count,
                            color: member.color,
                            isAggregate: member.isAggregate
                        )
                    }
                    : []
            ))
        }

        let raw = stats.sorted { lhs, rhs in lhs.points > rhs.points }
        let highestPoints = raw.map { stat in stat.points }.max() ?? 1
        let maxPoints = max(highestPoints, 1)
        return raw.map {
            var copy = $0
            copy.fraction = CGFloat($0.points) / CGFloat(maxPoints)
            return copy
        }
    }

    private var topCategoryName: String { categoryStats.first?.name ?? "暂无" }

    private var categoryChartMembers: [WeeklyCategoryChartMember] {
        guard memberContributions.count > 4 else {
            return memberContributions.map { member in
                WeeklyCategoryChartMember(
                    id: member.id,
                    name: member.name,
                    avatarKey: member.avatarKey,
                    color: member.color,
                    memberIDs: [member.id],
                    isAggregate: false
                )
            }
        }

        var members = memberContributions.prefix(3).map { member in
            WeeklyCategoryChartMember(
                id: member.id,
                name: member.name,
                avatarKey: member.avatarKey,
                color: member.color,
                memberIDs: [member.id],
                isAggregate: false
            )
        }
        members.append(WeeklyCategoryChartMember(
            id: "weekly-category-other-members",
            name: "其他",
            avatarKey: nil,
            color: DSColor.floatingSecondaryText.opacity(0.55),
            memberIDs: memberContributions.dropFirst(3).map(\.id),
            isAggregate: true
        ))
        return members
    }

    private var topChoreName: String {
        var counts: [String: Int] = [:]
        for record in records {
            counts[record.choreName, default: 0] += 1
        }
        let sortedCounts = counts.sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
        }
        return sortedCounts.first?.key ?? "暂无"
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
    let memberContributions: [WeeklyCategoryMemberContribution]
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

private struct WeeklyCategoryChartMember: Identifiable {
    let id: String
    let name: String
    let avatarKey: String?
    let color: Color
    let memberIDs: [String]
    let isAggregate: Bool
}

private struct WeeklyCategoryMemberContribution: Identifiable {
    let id: String
    let name: String
    let avatarKey: String?
    let points: Int
    let recordCount: Int
    let color: Color
    let isAggregate: Bool
}

struct HouseholdEnemyProfile {
    let name: String
    let systemImage: String
    let assetName: String
    let territory: String
    let lines: [String]
}

enum HouseholdBattleNarrative {
    static func profile(for category: ChoreCategory) -> HouseholdEnemyProfile {
        switch category {
        case .cleaning:
            HouseholdEnemyProfile(
                name: "灰尘军团",
                systemImage: "sparkles",
                assetName: "monthly_enemy_dust",
                territory: "客厅和那些自以为隐身成功的角落",
                lines: [
                    "它们一度占领角落，但没能撑过这周的联合清场。",
                    "灰尘以为自己隐身成功，结果全家都看见了。",
                    "敌军擅长原地不动，仍然被逐一请出了家门。",
                    "地板重新夺回了反光权，灰尘军团暂时撤退。",
                    "它们来得悄无声息，走的时候倒是整整齐齐。"
                ]
            )
        case .cooking:
            HouseholdEnemyProfile(
                name: "饿肚子魔王",
                systemImage: "fork.knife",
                assetName: "monthly_enemy_hunger",
                territory: "厨房与全家的饭点",
                lines: [
                    "饿肚子魔王多次敲门，厨房防线一次也没失守。",
                    "饭点警报刚响，锅碗瓢盆已经先一步集合。",
                    "本周厨房持续开火，饥饿只能在门外排队。",
                    "魔王试图用外卖诱惑大家，家里的香味先赢了一局。",
                    "每一次开火都算有效反击，盘子已经提供证词。"
                ]
            )
        case .laundryCare:
            HouseholdEnemyProfile(
                name: "脏衣服沼泽",
                systemImage: "tshirt.fill",
                assetName: "monthly_enemy_laundry",
                territory: "衣柜和最后一双干净袜子",
                lines: [
                    "脏衣服试图堆成一座山，最终只留下空篮子。",
                    "袜子失踪案仍在调查，但洗护战线已经守住。",
                    "衣物轮番上阵，晾衣区本周相当繁忙。",
                    "沼泽水位一度上涨，好在洗衣机及时接管局面。",
                    "干净衣服重新占领衣柜，皱褶势力正在收缩。"
                ]
            )
        case .organizing:
            HouseholdEnemyProfile(
                name: "杂物迷宫",
                systemImage: "shippingbox.fill",
                assetName: "monthly_enemy_clutter",
                territory: "桌面与失踪物品的回家路线",
                lines: [
                    "迷路的物品陆续回到岗位，桌面终于能看见自己。",
                    "杂物试图建立临时据点，最后都领到了固定座位。",
                    "本周成功打通多条通道，找东西不再像探险。",
                    "迷宫入口正在关闭，随手一放势力暂时退场。",
                    "每归位一件东西，家里就少一桩悬案。"
                ]
            )
        case .caregiving:
            HouseholdEnemyProfile(
                name: "夜班守关人",
                systemImage: "heart.fill",
                assetName: "monthly_enemy_care",
                territory: "家里的照顾防线",
                lines: [
                    "照顾没有下班铃，但本周每一班都有人稳稳接住。",
                    "小状况轮番来访，守关人始终没有离岗。",
                    "这条战线不一定热闹，却最需要耐心和接力。",
                    "被照顾的小事没有上头条，但都被认真接住了。",
                    "本周的温柔值持续在线，防线运行良好。"
                ]
            )
        case .household:
            HouseholdEnemyProfile(
                name: "琐事小队",
                systemImage: "checklist",
                assetName: "monthly_enemy_errands",
                territory: "日历、采购单和容易被忘掉的小事",
                lines: [
                    "它们专挑忙的时候出现，好在本周没有一件成功溜走。",
                    "采购、缴费和预约轮番上场，功劳簿全都记得。",
                    "琐事看起来不大，排起队来倒很有气势。",
                    "本周成功清空多条待办，脑内缓存终于腾出位置。",
                    "容易被忘记的小事，这次一件也没躲过记录。"
                ]
            )
        }
    }

    static func status(for recordCount: Int) -> String {
        switch recordCount {
        case 8...: "大获全胜"
        case 4...: "基本肃清"
        default: "持续追击"
        }
    }

    static func rotatingLine(for category: ChoreCategory, seed: Int) -> String {
        let lines = profile(for: category).lines
        guard !lines.isEmpty else { return "家庭防线持续运转。" }
        return lines[positiveModulo(seed, lines.count)]
    }

    static func index(of category: ChoreCategory) -> Int {
        ChoreCategory.allCases.firstIndex(of: category) ?? 0
    }

    private static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
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
