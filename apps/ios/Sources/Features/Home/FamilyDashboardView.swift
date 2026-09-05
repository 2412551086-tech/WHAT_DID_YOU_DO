import Foundation
import Charts
import SwiftUI

struct FamilyDashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var leaderPointSize: CGFloat = 52
    @ScaledMetric(relativeTo: .body) private var leaderIllustrationWidth: CGFloat = 166
    @State private var copySeed = Int.random(in: 0..<10_000)
    @State private var selectedBattleIndex = 0

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
                        DSOfflineStatusView(
                            lastUpdatedAt: viewModel.lastSuccessfulSyncAt,
                            pendingUploadCount: viewModel.pendingUploadCount
                        )
                    }

                    if let errorMessage = viewModel.errorMessage {
                        errorCard(errorMessage)
                    }

                    if viewModel.isLoadingMonthlyReport {
                        reportLoadingState
                    } else {
                        leaderCard

                        if showsFamilyRanking {
                            leaderboardSection
                        }

                        if !monthlyTrend.isEmpty {
                            sixMonthTrendCard
                        }

                        distributionSection

                        if monthlyRecordCount > 0, !battleCategories.isEmpty {
                            battleReportSection
                        }
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
        .onAppear {
            copySeed = Int.random(in: 0..<10_000)
        }
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
        .overlay(Capsule().stroke(DSColor.raisedHighlight, lineWidth: 1))
    }

    private var leaderCard: some View {
        DSFloatingSurface(
            cornerRadius: 22,
            padding: 16,
            elevation: .primary
        ) {
            VStack(spacing: 12) {
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
                .frame(maxWidth: .infinity, minHeight: 174, alignment: .leading)

                Divider()
                    .overlay(DSColor.floatingDivider)

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        heroSummaryItem(title: "家庭总积分", value: "\(monthlyTotalPoints) 分")
                        heroSummaryItem(title: "本月完成", value: "\(monthlyRecordCount) 次")
                        heroSummaryItem(title: "总耗时", value: "\(monthlyTotalMinutes) 分钟")
                    }
                } else {
                    HStack(spacing: 0) {
                        heroSummaryItem(title: "家庭总积分", value: "\(monthlyTotalPoints) 分")
                        Divider().frame(height: 30)
                        heroSummaryItem(title: "完成", value: "\(monthlyRecordCount) 次")
                        Divider().frame(height: 30)
                        heroSummaryItem(title: "总耗时", value: "\(monthlyTotalMinutes) 分钟")
                    }
                }
            }
        }
    }

    private func heroSummaryItem(title: String, value: String) -> some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(DSColor.mutedInk)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSColor.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center)
        .accessibilityElement(children: .combine)
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
                Text("成员贡献排行榜")
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
        DSFloatingSurface(cornerRadius: 18, padding: 16, elevation: .secondary) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("家务类型结构")
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
        }
    }

    private var themeDistribution: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("主题投入")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSColor.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(themeRows) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(themeColor(item.themeKey))
                                .frame(width: 8, height: 8)
                            Text(themeTitle(item.themeKey))
                                .font(.caption)
                                .foregroundStyle(DSColor.mutedInk)
                            Text("\(themePercentage(item))%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(DSColor.ink)
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
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

    private func monthComparisonCard(_ comparison: MonthlyReportComparison) -> some View {
        DSFloatingSurface(cornerRadius: 18, padding: 14, elevation: .none) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("较上月")
                            .font(.headline)
                            .foregroundStyle(DSColor.ink)
                        Text(monthDisplayName(comparison.previousMonth))
                            .font(.caption)
                            .foregroundStyle(DSColor.mutedInk)
                    }
                    Spacer()
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DSColor.infoBlue)
                        .accessibilityHidden(true)
                }

                HStack(spacing: 0) {
                    comparisonMetric(
                        title: "积分",
                        current: monthlyTotalPoints,
                        previous: comparison.totalPoints
                    )
                    Divider().frame(height: 44)
                    comparisonMetric(
                        title: "完成",
                        current: monthlyRecordCount,
                        previous: comparison.totalRecords
                    )
                    Divider().frame(height: 44)
                    comparisonMetric(
                        title: "投入",
                        current: monthlyTotalMinutes,
                        previous: comparison.totalMinutes
                    )
                }
            }
        }
    }

    private func comparisonMetric(title: String, current: Int, previous: Int) -> some View {
        let change = comparisonChange(current: current, previous: previous)

        return VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DSColor.mutedInk)
            HStack(spacing: 4) {
                Image(systemName: change.systemImage)
                    .font(.system(size: 10, weight: .bold))
                Text(change.text)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(change.color)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)较上月\(change.accessibilityText)")
    }

    private var sixMonthTrendCard: some View {
        DSFloatingSurface(cornerRadius: 18, padding: 16, elevation: .secondary) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("近 6 个月趋势")
                            .font(.headline)
                            .foregroundStyle(DSColor.ink)
                        Text("按整月比较，不再拆分残缺周")
                            .font(.caption)
                            .foregroundStyle(DSColor.mutedInk)
                    }

                    Spacer()

                    Text(monthOverMonthText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(monthOverMonthColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(monthOverMonthColor.opacity(0.09))
                        .clipShape(Capsule())
                }

                Chart(monthlyTrend) { item in
                    AreaMark(
                        x: .value("月份", item.month),
                        y: .value("积分", item.points)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [MonthlyReportPalette.gold.opacity(0.18), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("月份", item.month),
                        y: .value("积分", item.points)
                    )
                    .foregroundStyle(MonthlyReportPalette.gold)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("月份", item.month),
                        y: .value("积分", item.points)
                    )
                    .foregroundStyle(item.month == viewModel.selectedReportMonth ? MonthlyReportPalette.gold : DSColor.pureSurface)
                    .symbolSize(item.month == viewModel.selectedReportMonth ? 72 : 42)
                    .annotation(position: .top, spacing: 4) {
                        if item.month == viewModel.selectedReportMonth {
                            Text("\(item.points)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(MonthlyReportPalette.deepGold)
                                .monospacedDigit()
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(DSColor.floatingDivider)
                        AxisValueLabel()
                            .font(.system(size: 9))
                            .foregroundStyle(DSColor.mutedInk)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: monthlyTrend.map(\.month)) { value in
                        AxisValueLabel {
                            if let month = value.as(String.self) {
                                Text(shortMonthLabel(month))
                                    .font(.caption2)
                                    .foregroundStyle(
                                        month == viewModel.selectedReportMonth
                                            ? MonthlyReportPalette.deepGold
                                            : DSColor.mutedInk
                                    )
                            }
                        }
                    }
                }
                .frame(height: 166)
                .accessibilityLabel(monthlyTrendAccessibilityLabel)
            }
        }
    }

    private var monthlyMemberContributionCard: some View {
        DSFloatingSurface(cornerRadius: 18, padding: 16, elevation: .none) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("成员贡献构成")
                        .font(.headline)
                        .foregroundStyle(DSColor.ink)
                    Text("积分占比之外，也看看每个人投入了多少时间")
                        .font(.caption)
                        .foregroundStyle(DSColor.mutedInk)
                }

                monthlyMemberShareBar

                VStack(spacing: 11) {
                    ForEach(Array(monthlyMemberContributions.enumerated()), id: \.element.id) { index, member in
                        monthlyMemberContributionRow(member, index: index)
                    }
                }
            }
        }
    }

    private var monthlyMemberShareBar: some View {
        GeometryReader { proxy in
            let gaps = CGFloat(max(monthlyMemberContributions.count - 1, 0)) * 3
            let availableWidth = max(proxy.size.width - gaps, 0)
            let total = max(monthlyMemberContributions.reduce(0) { $0 + $1.points }, 1)

            HStack(spacing: 3) {
                ForEach(Array(monthlyMemberContributions.enumerated()), id: \.element.id) { index, member in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(monthlyMemberColor(member, index: index))
                        .frame(width: availableWidth * CGFloat(member.points) / CGFloat(total))
                }
            }
        }
        .frame(height: 11)
        .background(DSColor.floatingDivider)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    private func monthlyMemberContributionRow(
        _ member: MonthlyMemberContribution,
        index: Int
    ) -> some View {
        let profile = viewModel.familyMembers.first { $0.userId == member.userId }
        let total = max(monthlyMemberContributions.reduce(0) { $0 + $1.points }, 1)
        let percentage = Int((Double(member.points) * 100 / Double(total)).rounded())

        return HStack(spacing: 10) {
            AvatarView(
                avatarKey: profile?.avatarKey,
                fallbackText: member.displayName,
                size: 34,
                presentation: .flat
            )

            Circle()
                .fill(monthlyMemberColor(member, index: index))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DSColor.ink)
                    .lineLimit(1)
                Text("\(member.recordCount) 次 · \(member.totalMinutes) 分钟")
                    .font(.caption)
                    .foregroundStyle(DSColor.mutedInk)
                    .monospacedDigit()
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(member.points) 分")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DSColor.ink)
                    .monospacedDigit()
                Text("\(percentage)%")
                    .font(.caption)
                    .foregroundStyle(DSColor.mutedInk)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var battleReportSection: some View {
        DSFloatingSurface(cornerRadius: 18, padding: 0, elevation: .secondary) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("战报解读")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DSColor.ink)

                    Spacer()

                    Text("\(min(selectedBattleIndex + 1, battleCategories.count))/\(battleCategories.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DSColor.mutedInk)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                TabView(selection: $selectedBattleIndex) {
                    ForEach(Array(battleCategories.enumerated()), id: \.element.category) { index, category in
                        battleReportPage(category)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .tag(index)
                            .padding(.horizontal, 12)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: battleCategories.count > 1 ? .always : .never))
                .frame(height: 206)
                .onChange(of: battleCategories.count) {
                    selectedBattleIndex = 0
                }
            }
        }
    }

    private func battleReportPage(_ category: MonthlyReportCategory) -> some View {
        let resolvedCategory = ChoreCategory.resolve(category.category)
        let enemy = HouseholdBattleNarrative.profile(for: resolvedCategory)
        let contributor = battleContributor(for: category)
        let categoryTitle = category.category.replacingOccurrences(of: "类", with: "")

        return VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 2) {
                neutralPortrait(for: contributor)

                VStack(spacing: 7) {
                    MonthlySpeechBubble(side: .leading) {
                        Text("这个月\(categoryTitle)阵地，我守住了。")
                    }

                    MonthlySpeechBubble(side: .trailing) {
                        Text(enemyRetreatLine(enemy: enemy, category: category))
                    }
                }
                .font(.caption)
                .foregroundStyle(DSColor.ink)
                .frame(maxWidth: .infinity)

                Image(enemy.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 82, height: 126, alignment: .bottom)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .bottom)

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(battleColor(for: resolvedCategory))
                Text(battleResultLine(contributor: contributor, enemy: enemy, category: category))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DSColor.mutedInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityElement(children: .combine)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(monthlyBattleSummary(enemy: enemy, category: category))
    }

    private func neutralPortrait(for contributor: MonthlyMemberContribution?) -> some View {
        let avatarKey = battleAvatarKey(for: contributor)

        return Image(FamilyIdentityOptions.neutralAsset(for: avatarKey))
            .resizable()
            .scaledToFit()
            .scaleEffect(1.58, anchor: .top)
            .offset(y: -2)
            .frame(width: 82, height: 142, alignment: .top)
            .clipped()
            .accessibilityHidden(true)
    }

    private func battleContributor(for category: MonthlyReportCategory) -> MonthlyMemberContribution? {
        category.memberContributions
            .filter { $0.points > 0 }
            .sorted {
                $0.points == $1.points
                    ? $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
                    : $0.points > $1.points
            }
            .first
            ?? monthlyMemberContributions.first
    }

    private func battleAvatarKey(for contributor: MonthlyMemberContribution?) -> String {
        guard let contributor else { return FamilyIdentityOptions.avatarKeys[0] }
        if let key = viewModel.familyMembers.first(where: { $0.userId == contributor.userId })?.avatarKey {
            return key
        }
        if contributor.userId == viewModel.currentUser?.id {
            return viewModel.currentMembership?.avatarKey ?? FamilyIdentityOptions.avatarKeys[0]
        }
        return FamilyIdentityOptions.avatarKeys[0]
    }

    private func enemyRetreatLine(
        enemy: HouseholdEnemyProfile,
        category: MonthlyReportCategory
    ) -> String {
        switch HouseholdBattleNarrative.status(for: category.recordCount) {
        case "大获全胜": "可恶，这次被你们清得太彻底了。"
        case "基本肃清": "先撤一步，我还会悄悄回来。"
        default: "这局还没结束，下个月再见。"
        }
    }

    private func battleResultLine(
        contributor: MonthlyMemberContribution?,
        enemy: HouseholdEnemyProfile,
        category: MonthlyReportCategory
    ) -> String {
        let name = contributor?.displayName ?? "全家"
        let points = contributor?.points ?? category.points
        return "\(name)在这条战线贡献 \(points) 分，击退\(enemy.name)。"
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
            return viewModel.monthlyReport?.headline
                ?? RotatingCopy.value(from: RotatingCopy.monthlyEmpty, seed: copySeed)
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

    private func monthlyBattleSummary(
        enemy: HouseholdEnemyProfile,
        category: MonthlyReportCategory
    ) -> String {
        "本月\(enemy.name)发动了 \(category.recordCount) 次进攻。全家携手投入 \(monthlyTotalMinutes) 分钟，拿下 \(monthlyTotalPoints) 分，守住了\(enemy.territory)。"
    }

    private func battleColor(for category: ChoreCategory) -> Color {
        switch category {
        case .cooking: DSColor.yellow
        case .cleaning: DSColor.mint
        case .laundryCare: DSColor.infoBlue
        case .organizing: DSColor.lavender
        case .caregiving: DSColor.coral
        case .household: DSColor.accentOrange
        }
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

    private var monthlyWeeklyTrend: [MonthlyReportWeek] {
        viewModel.monthlyReport?.weeklyTrend ?? []
    }

    private var monthlyTrend: [MonthlyReportMonth] {
        if let trend = viewModel.monthlyReport?.monthlyTrend, !trend.isEmpty {
            return trend
        }

        guard let report = viewModel.monthlyReport else { return [] }
        var knownMonths: [String: MonthlyReportMonth] = [:]
        if let comparison = report.comparison {
            knownMonths[comparison.previousMonth] = MonthlyReportMonth(
                month: comparison.previousMonth,
                points: comparison.totalPoints,
                recordCount: comparison.totalRecords,
                totalMinutes: comparison.totalMinutes
            )
        }
        knownMonths[report.month] = MonthlyReportMonth(
            month: report.month,
            points: report.totalPoints,
            recordCount: report.totalRecords,
            totalMinutes: report.totalMinutes
        )

        return (-5...0).compactMap { offset in
            guard let month = monthIdentifier(report.month, offsetBy: offset) else { return nil }
            return knownMonths[month] ?? MonthlyReportMonth(
                month: month,
                points: 0,
                recordCount: 0,
                totalMinutes: 0
            )
        }
    }

    private func monthIdentifier(_ month: String, offsetBy offset: Int) -> String? {
        let parts = month.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let monthNumber = Int(parts[1]),
              let date = Calendar(identifier: .gregorian).date(
                from: DateComponents(year: year, month: monthNumber, day: 1)
              ),
              let shifted = Calendar(identifier: .gregorian).date(
                byAdding: .month,
                value: offset,
                to: date
              ) else {
            return nil
        }

        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: shifted)
        guard let shiftedYear = components.year, let shiftedMonth = components.month else { return nil }
        return String(format: "%04d-%02d", shiftedYear, shiftedMonth)
    }

    private var monthOverMonthText: String {
        guard monthlyTrend.count >= 2 else { return "本月新开张" }
        let previous = monthlyTrend[monthlyTrend.count - 2].points
        let current = monthlyTrend.last?.points ?? 0
        return comparisonChange(current: current, previous: previous).text
    }

    private var monthOverMonthColor: Color {
        guard monthlyTrend.count >= 2 else { return DSColor.infoBlue }
        let previous = monthlyTrend[monthlyTrend.count - 2].points
        let current = monthlyTrend.last?.points ?? 0
        return comparisonChange(current: current, previous: previous).color
    }

    private var monthlyTrendAccessibilityLabel: String {
        monthlyTrend
            .map { "\(shortMonthLabel($0.month))，\($0.points) 分，\($0.recordCount) 次" }
            .joined(separator: "；")
    }

    private func shortMonthLabel(_ month: String) -> String {
        guard let number = Int(month.split(separator: "-").last ?? "") else { return month }
        return "\(number)月"
    }

    private var displayedWeeklyTrend: [MonthlyReportWeek] {
        guard let lastRecordedIndex = monthlyWeeklyTrend.lastIndex(where: {
            $0.points > 0 || $0.recordCount > 0
        }) else {
            return Array(monthlyWeeklyTrend.prefix(4))
        }
        return Array(monthlyWeeklyTrend[...lastRecordedIndex].suffix(4))
    }

    private var latestWeekPoints: Int {
        monthlyWeeklyTrend.last?.points ?? 0
    }

    private var latestWeekRecordCount: Int {
        monthlyWeeklyTrend.last?.recordCount ?? 0
    }

    private var weekOverWeekText: String {
        guard monthlyWeeklyTrend.count >= 2 else { return "本月新开张" }
        let previous = monthlyWeeklyTrend[monthlyWeeklyTrend.count - 2].points
        let current = latestWeekPoints
        guard previous > 0 else { return current > 0 ? "较上周新开张" : "较上周持平" }
        let delta = current - previous
        return delta == 0 ? "较上周持平" : "较上周 \(delta > 0 ? "+" : "")\(delta) 分"
    }

    private var weekOverWeekColor: Color {
        guard monthlyWeeklyTrend.count >= 2 else { return DSColor.infoBlue }
        let previous = monthlyWeeklyTrend[monthlyWeeklyTrend.count - 2].points
        if latestWeekPoints > previous { return MonthlyReportPalette.deepGold }
        if latestWeekPoints < previous { return DSColor.mutedInk }
        return DSColor.infoBlue
    }

    private var battleCategories: [MonthlyReportCategory] {
        Array(categoryRows.prefix(3))
    }

    private var monthlyMemberContributions: [MonthlyMemberContribution] {
        viewModel.monthlyReport?.memberContributions
            .filter { $0.points > 0 }
            .sorted {
                $0.points == $1.points
                    ? $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
                    : $0.points > $1.points
            } ?? []
    }

    private var weeklyTrendSummary: String {
        guard let strongestWeek = monthlyWeeklyTrend.max(by: { $0.points < $1.points }), strongestWeek.points > 0 else {
            return "本月各周的投入会在这里排成战线"
        }
        return "\(strongestWeek.label)火力最旺，拿下 \(strongestWeek.points) 分"
    }

    private var weeklyTrendAccessibilityLabel: String {
        monthlyWeeklyTrend
            .map { "\($0.label)，\($0.points) 分，\($0.recordCount) 次" }
            .joined(separator: "；")
    }

    private func shortWeekLabel(_ label: String) -> String {
        let compact = label.replacingOccurrences(of: "–", with: "-")
        let parts = compact.split(separator: "-")
        guard parts.count == 2 else { return label }
        let start = parts[0].split(separator: "/")
        let end = parts[1].split(separator: "/")
        guard start.count == 2, end.count == 2 else { return label }
        if start[0] == end[0] {
            return "\(start[0])/\(start[1])–\(end[1])"
        }
        return "\(start[0])/\(start[1])–\(end[0])/\(end[1])"
    }

    private func monthlyMemberColor(_ member: MonthlyMemberContribution, index: Int) -> Color {
        if let avatarKey = viewModel.familyMembers.first(where: { $0.userId == member.userId })?.avatarKey {
            return FamilyIdentityOptions.accentColor(for: avatarKey)
        }
        return Self.memberContributionPalette[index % Self.memberContributionPalette.count]
    }

    private func comparisonChange(current: Int, previous: Int) -> (
        text: String,
        accessibilityText: String,
        systemImage: String,
        color: Color
    ) {
        guard previous > 0 else {
            if current > 0 {
                return ("新开张", "新增记录", "sparkles", DSColor.infoBlue)
            }
            return ("持平", "持平", "minus", DSColor.mutedInk)
        }

        let percent = Int((Double(current - previous) * 100 / Double(previous)).rounded())
        if percent > 0 {
            return ("+\(percent)%", "增加 \(percent)%", "arrow.up.right", DSColor.mint)
        }
        if percent < 0 {
            return ("\(percent)%", "减少 \(abs(percent))%", "arrow.down.right", DSColor.accentOrange)
        }
        return ("持平", "持平", "minus", DSColor.mutedInk)
    }

    private func monthDisplayName(_ month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count == 2, let monthNumber = Int(parts[1]) else { return month }
        return "\(monthNumber) 月数据"
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

private enum MonthlyBubbleSide {
    case leading
    case trailing
}

private struct MonthlySpeechBubble<Content: View>: View {
    let side: MonthlyBubbleSide
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .padding(side == .leading ? .leading : .trailing, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                MonthlyBubbleShape(side: side)
                    .fill(DSColor.pureSurface.opacity(0.94))
            )
            .overlay(
                MonthlyBubbleShape(side: side)
                    .stroke(DSColor.ink.opacity(0.18), lineWidth: 0.8)
            )
            .overlay(
                MonthlyBubbleShape(side: side)
                    .stroke(Color.white.opacity(0.72), lineWidth: 0.55)
                    .padding(1)
            )
            .shadow(color: Color.black.opacity(0.07), radius: 10, y: 5)
    }
}

private struct MonthlyBubbleShape: Shape {
    let side: MonthlyBubbleSide

    func path(in rect: CGRect) -> Path {
        let tailWidth: CGFloat = 9
        let bodyRect = side == .leading
            ? CGRect(x: tailWidth, y: 0, width: rect.width - tailWidth, height: rect.height)
            : CGRect(x: 0, y: 0, width: rect.width - tailWidth, height: rect.height)
        let tailY = rect.height * 0.70

        var path = Path()
        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: 15, height: 15))

        if side == .leading {
            path.move(to: CGPoint(x: bodyRect.minX + 1, y: tailY - 8))
            path.addLine(to: CGPoint(x: 0, y: tailY + 2))
            path.addLine(to: CGPoint(x: bodyRect.minX + 2, y: tailY + 6))
        } else {
            path.move(to: CGPoint(x: bodyRect.maxX - 1, y: tailY - 8))
            path.addLine(to: CGPoint(x: rect.maxX, y: tailY + 2))
            path.addLine(to: CGPoint(x: bodyRect.maxX - 2, y: tailY + 6))
        }
        path.closeSubpath()
        return path
    }
}

private extension FamilyDashboardView {
    static let memberContributionPalette: [Color] = [
        Color(red: 0.84, green: 0.64, blue: 0.38),
        Color(red: 0.48, green: 0.68, blue: 0.43),
        DSColor.infoBlue,
        DSColor.coral,
        DSColor.lavender,
    ]
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


#Preview("月度战报 · 深色") {
    NavigationStack {
        FamilyDashboardView()
            .environmentObject(AppViewModel.previewHomeAfterNewRecord())
    }
    .preferredColorScheme(.dark)
}
