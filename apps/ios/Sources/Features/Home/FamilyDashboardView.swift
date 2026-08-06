import Foundation
import Charts
import SwiftUI

struct FamilyDashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var leaderPointSize: CGFloat = 52
    @ScaledMetric(relativeTo: .body) private var leaderIllustrationWidth: CGFloat = 166

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    header

                    if viewModel.isLoading && !viewModel.isLoadingMonthlyReport {
                        loadingCard
                    }

                    if viewModel.isOffline {
                        DSOfflineStatusView(lastUpdatedAt: viewModel.lastSuccessfulSyncAt)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        errorCard(errorMessage)
                    }

                    if viewModel.isLoadingMonthlyReport {
                        reportLoadingState
                    } else {
                        leaderCard
                        summaryMetrics
                        reportHeadline

                        if showsFamilyRanking {
                            leaderboardSection
                        }

                        distributionSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 108)
            }
            .refreshable {
                await viewModel.refreshHomeData()
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    pageTitle
                    monthPill
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    pageTitle
                    Spacer(minLength: 8)
                    monthPill
                }
            }
        }
    }

    private var pageTitle: some View {
        Text("月度战报")
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .foregroundStyle(DSColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .accessibilityAddTraits(.isHeader)
    }

    private var monthPill: some View {
        HStack(spacing: 2) {
            Button {
                viewModel.selectPreviousReportMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading || viewModel.isLoadingMonthlyReport)
            .accessibilityLabel("查看上个月")

            Text(viewModel.selectedReportMonthLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DSColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(minWidth: 88)
                .accessibilityLabel("当前月份，\(viewModel.selectedReportMonthLabel)")

            Button {
                viewModel.selectNextReportMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(
                !viewModel.canSelectNextReportMonth
                    || viewModel.isLoading
                    || viewModel.isLoadingMonthlyReport
            )
            .opacity(viewModel.canSelectNextReportMonth ? 1 : 0.28)
            .accessibilityLabel("查看下个月")
        }
        .foregroundStyle(DSColor.ink)
        .padding(.horizontal, 3)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.9), lineWidth: 1))
    }

    private var leaderCard: some View {
        DSFloatingSurface(
            cornerRadius: 22,
            padding: 16,
            elevation: .primary
        ) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 14) {
                        leaderCopy
                        leaderIllustration
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else {
                    HStack(alignment: .bottom, spacing: 4) {
                        leaderCopy
                            .frame(maxWidth: 156, alignment: .leading)

                        Spacer(minLength: 0)

                        leaderIllustration
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 184, alignment: .leading)
        }
    }

    private var leaderCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(leaderStatus)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MonthlyReportPalette.deepGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(MonthlyReportPalette.gold.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(MonthlyReportPalette.gold.opacity(0.30), lineWidth: 1)
                )

            Text(leaderName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(DSColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(leaderPoints)")
                    .font(.system(size: leaderPointSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(MonthlyReportPalette.gold)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("分")
                    .font(.body.weight(.medium))
                    .foregroundStyle(MonthlyReportPalette.deepGold)
            }

            Text(leaderCompletionText)
                .font(.subheadline)
                .foregroundStyle(DSColor.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var leaderIllustration: some View {
        Image(viewModel.monthlyLeaderIllustrationAsset)
            .resizable()
            .scaledToFit()
            .frame(
                width: dynamicTypeSize.isAccessibilitySize ? 190 : min(184, leaderIllustrationWidth),
                height: 202
            )
            .accessibilityHidden(true)
    }

    private var summaryMetrics: some View {
        DSFloatingSurface(cornerRadius: 18, padding: 14, elevation: .none) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    primarySummaryMetric
                    Divider()
                    metric(title: "完成", value: "\(monthlyRecordCount)", unit: "次")
                    Divider()
                    metric(title: "总耗时", value: "\(monthlyTotalMinutes)", unit: "分钟")
                }
            } else {
                HStack(spacing: 12) {
                    primarySummaryMetric
                    Divider().frame(height: 44)
                    metric(title: "完成", value: "\(monthlyRecordCount)", unit: "次")
                    Divider().frame(height: 44)
                    metric(title: "总耗时", value: "\(monthlyTotalMinutes)", unit: "分钟")
                }
            }
        }
    }

    @ViewBuilder
    private var primarySummaryMetric: some View {
        if showsFamilyRanking {
            metric(title: "家庭总积分", value: "\(monthlyTotalPoints)")
        } else {
            metric(title: "活跃主题", value: "\(themeRows.count)", unit: "个")
        }
    }

    private func metric(title: String, value: String, unit: String? = nil) -> some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DSColor.mutedInk)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DSColor.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(DSColor.mutedInk)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center)
        .accessibilityElement(children: .combine)
    }

    private var leaderboardSection: some View {
        DSFloatingSurface(cornerRadius: 18, padding: 0, elevation: .none) {
            VStack(alignment: .leading, spacing: 0) {
                Text("成员排行榜")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DSColor.ink)
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
                    .accessibilityAddTraits(.isHeader)

                if rankedMembers.isEmpty {
                    Divider()
                    Text("本月还没有排行，第一笔功劳等你来记。")
                        .font(DSFont.functionalBody)
                        .foregroundStyle(DSColor.mutedInk)
                        .padding(16)
                } else {
                    ForEach(Array(rankedMembers.enumerated()), id: \.element.id) { index, member in
                        if index > 0 {
                            Divider().padding(.leading, 54)
                        }

                        rankingRow(member: member, index: index)
                    }
                }
            }
        }
    }

    private func rankingRow(member: FamilyMember, index: Int) -> some View {
        let isCurrentUser = member.id == viewModel.currentUser?.id

        return HStack(spacing: 10) {
            rankMark(index: index)
                .frame(width: 30)

            AvatarView(
                avatarKey: isCurrentUser ? viewModel.currentMembership?.avatarKey : nil,
                fallbackText: member.name,
                size: 40,
                presentation: .quiet
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(DSColor.ink)
                        .lineLimit(1)

                    if isCurrentUser && member.name != "我" {
                        Text("我")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(DSColor.infoBlue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DSColor.infoBlue.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }

                if recordCount(from: member.badge) == nil {
                    Text(member.badge)
                        .font(.caption)
                        .foregroundStyle(DSColor.mutedInk)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Text("\(member.monthlyPoints) 分")
                .font(.body.weight(isCurrentUser ? .semibold : .medium))
                .foregroundStyle(isCurrentUser ? DSColor.infoBlue : DSColor.ink)
                .monospacedDigit()
                .lineLimit(1)

            Divider().frame(height: 22)

            Text(rankingDetail(for: member))
                .font(.caption)
                .foregroundStyle(DSColor.mutedInk)
                .lineLimit(1)
                .frame(minWidth: 32, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 56)
        .background(isCurrentUser ? DSColor.infoBlue.opacity(0.07) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "第 \(index + 1) 名，\(member.name)，\(member.monthlyPoints) 分，\(rankingDetail(for: member))"
        )
    }

    @ViewBuilder
    private func rankMark(index: Int) -> some View {
        if index < 3 {
            ZStack {
                Image(systemName: "medal.fill")
                    .font(.system(size: 28, weight: .medium))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(medalColor(index: index))

                Text("\(index + 1)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .offset(y: -3)
            }
            .accessibilityHidden(true)
        } else {
            Text("\(index + 1)")
                .font(.body)
                .foregroundStyle(DSColor.mutedInk)
                .monospacedDigit()
        }
    }

    private var distributionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("本月洞察")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DSColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("按积分占比查看家庭精力去向")
                    .font(.caption)
                    .foregroundStyle(DSColor.mutedInk)
            }

            if themeRows.isEmpty && categoryRows.isEmpty {
                Label(categoryEmptyMessage, systemImage: "chart.bar.xaxis")
                    .font(.body)
                    .foregroundStyle(DSColor.mutedInk)
                    .symbolRenderingMode(.hierarchical)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 10)
            } else {
                if !themeRows.isEmpty {
                    themeDistribution
                }

                if !themeRows.isEmpty && !categoryRows.isEmpty {
                    Divider()
                        .overlay(DSColor.floatingDivider)
                }

                if !categoryRows.isEmpty {
                    categoryDistribution
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 8)
    }

    private var themeDistribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("主题分布")
                .font(.headline)
                .foregroundStyle(DSColor.ink)

            if themeRows.count == 1, let theme = themeRows.first {
                singleThemeSummary(theme)
            } else {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 14) {
                            themeDonut
                                .frame(maxWidth: .infinity, alignment: .center)
                            themeLegend
                        }
                    } else {
                        HStack(spacing: 20) {
                            themeDonut
                            themeLegend
                        }
                    }
                }
            }
        }
    }

    private func singleThemeSummary(_ item: MonthlyReportTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(themeColor(item.themeKey).opacity(0.16))
                    Image(systemName: "scope")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(themeColor(item.themeKey))
                }
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("本月集中在\(themeTitle(item.themeKey))")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(DSColor.ink)
                    Text("共记录 \(item.recordCount) 次")
                        .font(.caption)
                        .foregroundStyle(DSColor.mutedInk)
                }

                Spacer(minLength: 8)

                Text("\(item.points) 分")
                    .font(.headline)
                    .foregroundStyle(DSColor.ink)
                    .monospacedDigit()
            }

            Capsule()
                .fill(themeColor(item.themeKey).opacity(0.82))
                .frame(height: 8)
                .accessibilityHidden(true)
        }
        .padding(14)
        .background(DSColor.pureSurface.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "本月集中在\(themeTitle(item.themeKey))，\(item.recordCount) 次，\(item.points) 分"
        )
    }

    private var themeDonut: some View {
        Chart(themeRows) { item in
            SectorMark(
                angle: .value("积分", max(item.points, 0)),
                innerRadius: .ratio(0.63),
                angularInset: 2
            )
            .cornerRadius(3)
            .foregroundStyle(themeColor(item.themeKey))
        }
        .chartLegend(.hidden)
        .frame(width: 132, height: 132)
        .overlay {
            VStack(spacing: 1) {
                Text("\(themeRows.count)")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DSColor.ink)
                    .monospacedDigit()
                Text("个主题")
                    .font(.caption)
                    .foregroundStyle(DSColor.mutedInk)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("本月覆盖 \(themeRows.count) 个主题")
    }

    private var themeLegend: some View {
        VStack(spacing: 9) {
            ForEach(themeRows) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(themeColor(item.themeKey))
                        .frame(width: 9, height: 9)

                    Text(themeTitle(item.themeKey))
                        .font(.subheadline)
                        .foregroundStyle(DSColor.ink)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text("\(themePercentage(item))%")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DSColor.ink)
                        .monospacedDigit()

                    Text("\(item.recordCount)次")
                        .font(.caption)
                        .foregroundStyle(DSColor.mutedInk)
                        .monospacedDigit()
                        .frame(minWidth: 30, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(themeTitle(item.themeKey))，\(themePercentage(item))%，\(item.recordCount) 次"
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var categoryDistribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("家务类型")
                .font(.headline)
                .foregroundStyle(DSColor.ink)

            if !categoryRows.isEmpty {
                categoryShareBar

                LazyVGrid(columns: categoryColumns, alignment: .leading, spacing: 12) {
                    ForEach(Array(categoryRows.enumerated()), id: \.element.category) { index, item in
                        categoryLegendItem(item, index: index)
                    }
                }
            }
        }
    }

    private var categoryShareBar: some View {
        GeometryReader { proxy in
            let gaps = CGFloat(max(0, categoryRows.count - 1)) * 3
            let availableWidth = max(0, proxy.size.width - gaps)

            HStack(spacing: 3) {
                ForEach(Array(categoryRows.enumerated()), id: \.element.category) { index, item in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(categoryColor(index).opacity(0.82))
                        .frame(width: availableWidth * categoryShare(item))
                }
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }

    private func categoryLegendItem(_ item: MonthlyReportCategory, index: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(categoryColor(index).opacity(0.82))
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.category.replacingOccurrences(of: "类", with: ""))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DSColor.ink)
                    .lineLimit(1)

                Text("\(item.recordCount) 次 · \(item.points) 分")
                    .font(.caption)
                    .foregroundStyle(DSColor.mutedInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 2)

            Text("\(categoryPercentage(item))%")
                .font(.caption.weight(.medium))
                .foregroundStyle(DSColor.ink)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(item.category)，\(categoryPercentage(item))%，\(item.points) 分，\(item.recordCount) 次"
        )
    }

    private var reportHeadline: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(MonthlyReportPalette.gold)
                .accessibilityHidden(true)

            Text(monthlyInsightText)
                .font(.body)
                .foregroundStyle(DSColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MonthlyReportPalette.gold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var reportLoadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)

            Text("正在翻阅\(viewModel.selectedReportMonthLabel)的功劳簿")
                .font(.body.weight(.medium))
                .foregroundStyle(DSColor.ink)

            Text("新月份的数据整理好后会一起出现")
                .font(.caption)
                .foregroundStyle(DSColor.mutedInk)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("正在加载\(viewModel.selectedReportMonthLabel)月度战报")
    }

    private var loadingCard: some View {
        DSQuietCard(fill: DSColor.pureSurface) {
            HStack(spacing: 12) {
                ProgressView()
                Text(viewModel.loadingMessage ?? "正在整理本月战报")
                    .font(DSFont.functionalBody)
            }
            .foregroundStyle(DSColor.mutedInk)
        }
    }

    private func errorCard(_ message: String) -> some View {
        DSRequestFailureView(
            title: "月度战报加载失败",
            message: viewModel.isOffline ? "网络开了个小差，请检查连接后重试。" : message,
            retryAction: viewModel.retryHomeData
        )
    }

    private var rankedMembers: [FamilyMember] {
        viewModel.monthlyRanking.sorted {
            if $0.monthlyPoints == $1.monthlyPoints {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.monthlyPoints > $1.monthlyPoints
        }
    }

    private var showsFamilyRanking: Bool {
        rankedMembers.count >= 2
    }

    private var leadingMember: FamilyMember? {
        rankedMembers.first(where: { $0.monthlyPoints > 0 })
    }

    private var leaderStatus: String {
        guard showsFamilyRanking else { return "个人月度小结" }
        guard let leadingMember else { return "本月战局待开启" }
        let leaders = rankedMembers.filter { $0.monthlyPoints == leadingMember.monthlyPoints }
        return leaders.count > 1 ? "并列领跑" : "本月暂居第一"
    }

    private var leaderName: String {
        if !showsFamilyRanking {
            return leadingMember?.name ?? viewModel.currentUserName
        }
        guard let leadingMember else { return viewModel.familyDisplayName }
        let leaders = rankedMembers.filter { $0.monthlyPoints == leadingMember.monthlyPoints }
        return leaders.count > 1 ? "全家并列" : leadingMember.name
    }

    private var leaderPoints: Int {
        showsFamilyRanking ? (leadingMember?.monthlyPoints ?? 0) : monthlyTotalPoints
    }

    private var leaderCompletionText: String {
        guard monthlyRecordCount > 0 else { return "等第一笔家务登场" }

        if !showsFamilyRanking {
            return "本月完成 \(monthlyRecordCount) 次 · \(monthlyTotalMinutes) 分钟"
        }

        guard let leadingMember else { return "家庭本月完成 \(monthlyRecordCount) 次" }

        if let count = recordCount(from: leadingMember.badge) {
            return "本月完成 \(count) 次"
        }

        return "家庭本月完成 \(monthlyRecordCount) 次"
    }

    private var monthlyInsightText: String {
        guard monthlyRecordCount > 0 else {
            return viewModel.monthlyReport?.headline ?? "本月战局待开启，第一笔功劳等你登场。"
        }

        if let leadingTheme = themeRows.first {
            return "本月主要精力集中在\(themeTitle(leadingTheme.themeKey))，完成 \(leadingTheme.recordCount) 次，贡献 \(leadingTheme.points) 分。"
        }

        if let leadingCategory = categoryRows.first {
            let title = leadingCategory.category.replacingOccurrences(of: "类", with: "")
            return "本月主要完成的是\(title)，共记录 \(leadingCategory.recordCount) 次。"
        }

        return viewModel.monthlyReport?.headline ?? "本月家庭战况持续更新。"
    }

    private var monthlyTotalPoints: Int {
        viewModel.monthlyReport?.totalPoints
            ?? rankedMembers.reduce(0) { $0 + $1.monthlyPoints }
    }

    private var monthlyRecordCount: Int {
        viewModel.monthlyReport?.totalRecords ?? 0
    }

    private var monthlyTotalMinutes: Int {
        viewModel.monthlyReport?.totalMinutes ?? 0
    }

    private var categoryRows: [MonthlyReportCategory] {
        viewModel.monthlyReport?.categoryStats
            .filter { $0.points > 0 }
            .sorted { $0.points > $1.points } ?? []
    }

    private var themeRows: [MonthlyReportTheme] {
        viewModel.monthlyReport?.themeStats
            .filter { $0.points > 0 }
            .sorted { $0.points > $1.points } ?? []
    }

    private var categoryEmptyMessage: String {
        monthlyRecordCount == 0
            ? "记下第一笔后，这里会出现本月分布。"
            : "本月分类战线正在整理。"
    }

    private func recordCount(from badge: String) -> Int? {
        let digits = badge.filter(\.isNumber)
        return digits.isEmpty ? nil : Int(digits)
    }

    private func rankingDetail(for member: FamilyMember) -> String {
        guard let count = recordCount(from: member.badge) else {
            return member.badge
        }
        return "\(count) 次"
    }

    private func medalColor(index: Int) -> Color {
        switch index {
        case 0: MonthlyReportPalette.gold
        case 1: MonthlyReportPalette.silver
        default: MonthlyReportPalette.bronze
        }
    }

    private func categoryPercentage(_ item: MonthlyReportCategory) -> Int {
        guard categoryTotalPoints > 0 else { return 0 }
        return Int((Double(item.points) * 100 / Double(categoryTotalPoints)).rounded())
    }

    private func categoryShare(_ item: MonthlyReportCategory) -> CGFloat {
        guard categoryTotalPoints > 0 else { return 0 }
        return CGFloat(item.points) / CGFloat(categoryTotalPoints)
    }

    private func categoryColor(_ index: Int) -> Color {
        [DSColor.coral, DSColor.mint, DSColor.infoBlue, DSColor.yellow][index % 4]
    }

    private var categoryColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: 12)]
            : [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)]
    }

    private var categoryTotalPoints: Int {
        categoryRows.reduce(0) { $0 + $1.points }
    }

    private var themeTotalPoints: Int {
        themeRows.reduce(0) { $0 + $1.points }
    }

    private func themePercentage(_ item: MonthlyReportTheme) -> Int {
        guard themeTotalPoints > 0 else { return 0 }
        return Int((Double(item.points) * 100 / Double(themeTotalPoints)).rounded())
    }

    private func themeTitle(_ themeKey: String) -> String {
        ChoreTheme(rawValue: themeKey)?.title ?? "其他"
    }

    private func themeColor(_ themeKey: String) -> Color {
        switch ChoreTheme(rawValue: themeKey) {
        case .daily: MonthlyReportPalette.gold
        case .love: DSColor.coral.opacity(0.82)
        case .childcare: DSColor.infoBlue.opacity(0.78)
        case .pet: DSColor.mint.opacity(0.90)
        case nil: DSColor.mutedInk.opacity(0.55)
        }
    }
}

private enum MonthlyReportPalette {
    static let gold = Color(red: 0.86, green: 0.59, blue: 0.17)
    static let deepGold = Color(red: 0.58, green: 0.39, blue: 0.10)
    static let silver = Color(red: 0.66, green: 0.68, blue: 0.70)
    static let bronze = Color(red: 0.76, green: 0.46, blue: 0.24)
}

#Preview {
    NavigationStack {
        FamilyDashboardView()
            .environmentObject(AppViewModel.previewHomeAfterNewRecord())
    }
}
