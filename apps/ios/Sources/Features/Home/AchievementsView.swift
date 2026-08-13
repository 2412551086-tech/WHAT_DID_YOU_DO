import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var selectedAchievement: AchievementItem?
    @State private var sharingUpdateInFlight = false

    var body: some View {
        ZStack {
            DSColor.floatingPageBackground.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header

                    if viewModel.achievementSyncState == .pending {
                        syncBanner
                    } else if viewModel.achievementSyncState == .failed {
                        syncFailureBanner
                    }

                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .refreshable {
                await viewModel.refreshAchievements()
            }
        }
        .navigationTitle("成就")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refreshAchievements()
        }
        .sheet(item: $selectedAchievement) { achievement in
            AchievementDetailSheet(achievement: achievement)
                .environmentObject(viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("每一枚，都是认真生活留下的证据。")
                .font(DSFont.functionalBody)
                .foregroundStyle(DSColor.floatingSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            compactSharingToggle
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactSharingToggle: some View {
        VStack(spacing: 4) {
            Toggle("", isOn: Binding(
                get: { viewModel.showAchievementsToFamily },
                set: { newValue in
                    guard !sharingUpdateInFlight else { return }
                    sharingUpdateInFlight = true
                    Task {
                        await viewModel.updateAchievementSharing(showToFamily: newValue)
                        sharingUpdateInFlight = false
                    }
                }
            ))
            .labelsHidden()
            .controlSize(.mini)
            .tint(DSColor.infoBlue)
            .disabled(sharingUpdateInFlight)

            Text("家庭可见")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DSColor.floatingSecondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("向家庭成员展示成就")
        .accessibilityValue(viewModel.showAchievementsToFamily ? "已开启" : "已关闭")
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.achievementDataState {
        case .idle where viewModel.achievementItems.isEmpty,
             .loading where viewModel.achievementItems.isEmpty:
            DSLoadingStateView(message: "正在翻开功劳簿…")
        case let .failed(message) where viewModel.achievementItems.isEmpty:
            DSRequestFailureView(
                title: "成就暂时没同步上",
                message: message,
                retryAction: { Task { await viewModel.refreshAchievements() } }
            )
        default:
            loadedContent
        }
    }

    private var loadedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.achievementDataState == .cached {
                DSOfflineStatusView(lastUpdatedAt: viewModel.achievementLastUpdatedAt)
            } else if case let .failed(message) = viewModel.achievementDataState {
                Button {
                    Task { await viewModel.refreshAchievements() }
                } label: {
                    DSErrorBanner(message: "\(message) 点按重试。")
                }
                .buttonStyle(.plain)
            }

            if !viewModel.upcomingAchievements.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("即将完成")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    AchievementNextEntry(
                        achievements: viewModel.upcomingAchievements,
                        syncState: viewModel.achievementSyncState,
                        onSelect: { selectedAchievement = $0 }
                    )
                }
            }

            if displayedAchievements.isEmpty {
                DSEmptyStateView(
                    title: "成就正在路上",
                    message: "记下家务后，这里会出现你的第一枚成就。",
                    systemImage: "sparkles"
                )
            } else {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(minimum: 0), spacing: 10, alignment: .top),
                        count: 3
                    ),
                    spacing: 24
                ) {
                    ForEach(displayedAchievements) { achievement in
                        Button {
                            selectedAchievement = achievement
                        } label: {
                            AchievementTile(achievement: achievement)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let updatedAt = viewModel.achievementLastUpdatedAt {
                Text("更新于 \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(DSFont.functionalCaption)
                    .foregroundStyle(DSColor.floatingSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var syncBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("功劳已入账，成就正在同步…")
                .font(.system(size: 14, weight: .medium))
            Spacer()
        }
        .foregroundStyle(DSColor.floatingSecondaryText)
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .background(DSColor.choreYellowSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var syncFailureBanner: some View {
        Button {
            Task { await viewModel.refreshAchievements() }
        } label: {
            DSErrorBanner(message: "家务已经记下，成就暂时没同步上。点按重试。")
        }
        .buttonStyle(.plain)
        .accessibilityHint("重新获取成就进度")
    }

    private var displayedAchievements: [AchievementItem] {
        viewModel.orderedAchievements
    }
}

struct AchievementNextEntry: View {
    let achievements: [AchievementItem]
    let syncState: AchievementSyncState
    var onSelect: ((AchievementItem) -> Void)?
    @State private var selectedPage = 0

    init(
        achievements: [AchievementItem],
        syncState: AchievementSyncState,
        onSelect: ((AchievementItem) -> Void)? = nil
    ) {
        self.achievements = achievements
        self.syncState = syncState
        self.onSelect = onSelect
    }

    var body: some View {
        DSFloatingSurface(cornerRadius: 18, padding: 14, elevation: .secondary) {
            if achievements.isEmpty {
                HStack(spacing: 13) {
                    AchievementArtwork(achievement: nil, size: 48)
                    Text(syncState == .pending ? "成就正在同步" : "查看我的成就")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.right")
                }
            } else {
                TabView(selection: $selectedPage) {
                    ForEach(Array(achievements.enumerated()), id: \.element.id) { index, achievement in
                        upcomingPage(achievement)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: achievements.count > 1 ? .always : .never))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))
                .frame(height: 96)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard achievements.indices.contains(selectedPage) else { return }
            onSelect?(achievements[selectedPage])
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(achievements.count > 1 ? "左右滑动查看另外两项即将完成的成就" : "打开成就页面")
    }

    private func upcomingPage(_ achievement: AchievementItem) -> some View {
        HStack(spacing: 13) {
            AchievementArtwork(achievement: achievement, size: 52)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(syncState == .pending ? "正在同步" : "即将完成")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DSColor.floatingSecondaryText)
                    if achievement.reward != nil {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DSColor.infoBlue)
                    }
                }
                Text(achievement.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(DSColor.floatingPrimaryText)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    ProgressView(value: achievement.clampedProgress)
                        .tint(DSColor.infoBlue)
                    Text("\(achievement.displayCurrentValue)/\(achievement.targetValue)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(DSColor.infoBlue)
                        .monospacedDigit()
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColor.floatingSecondaryText)
        }
        .padding(.bottom, achievements.count > 1 ? 12 : 0)
    }
}

struct AchievementCelebrationOverlay: View {
    let celebration: AchievementCelebration
    let dismiss: () -> Void
    @State private var selectedPage = 0

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(celebration.achievements.count > 1 ? "一次解锁 \(celebration.achievements.count) 项成就" : "新成就已收藏")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(DSColor.floatingPageBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭成就提示")
            }

            if celebration.achievements.isEmpty {
                Image(systemName: "sparkles")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(DSColor.yellow)
                    .frame(height: 220)
            } else {
                TabView(selection: $selectedPage) {
                    ForEach(Array(celebration.achievements.enumerated()), id: \.element.id) { index, achievement in
                        celebrationPage(achievement)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: celebration.achievements.count > 1 ? .always : .never))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(height: 270)
                .accessibilityHint(celebration.achievements.count > 1 ? "左右滑动查看其他新成就" : "")
            }

            if !celebration.rewards.isEmpty {
                Label(
                    celebration.rewards.map(\.displayText).joined(separator: "，"),
                    systemImage: "gift.fill"
                )
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DSColor.infoBlue)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
            }

            Button("收下成就", action: dismiss)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DSColor.ink)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(DSColor.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .buttonStyle(.plain)
        }
        .foregroundStyle(DSColor.floatingPrimaryText)
        .padding(17)
        .frame(maxWidth: 350)
        .background(DSColor.floatingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DSColor.floatingStroke, lineWidth: 0.8)
        )
        .shadow(color: DSColor.shadow.opacity(0.13), radius: 22, x: 0, y: 10)
        .accessibilityElement(children: .contain)
    }

    private func celebrationPage(_ achievement: AchievementItem) -> some View {
        VStack(spacing: 10) {
            AchievementArtwork(achievement: achievement, size: 156)

            Text(achievement.name)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(DSColor.floatingPrimaryText)
                .multilineTextAlignment(.center)

            Text(achievement.unlockCopy)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(DSColor.floatingSecondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct AchievementTile: View {
    let achievement: AchievementItem

    var body: some View {
        VStack(spacing: 7) {
            AchievementArtwork(achievement: achievement, size: 88)

            Text(achievement.name)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(DSColor.floatingPrimaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(minHeight: 34, alignment: .top)

            if !achievement.isUnlocked {
                HStack(spacing: 4) {
                    if achievement.reward != nil {
                        Image(systemName: "gift.fill")
                            .foregroundStyle(DSColor.infoBlue)
                    }
                    Text("\(achievement.displayCurrentValue)/\(achievement.targetValue)")
                        .monospacedDigit()
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(DSColor.floatingSecondaryText)
            } else if let reward = achievement.reward {
                Label(reward.displayText, systemImage: "checkmark.seal.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DSColor.infoBlue)
                    .lineLimit(1)
            } else {
                Text("已获得")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColor.floatingSecondaryText)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 146, alignment: .top)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if achievement.isUnlocked {
            return "已解锁，\(achievement.name)"
        }
        return "进行中，\(achievement.name)，进度 \(achievement.displayCurrentValue) 共 \(achievement.targetValue)"
    }
}

private struct AchievementDetailSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let achievement: AchievementItem

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AchievementArtwork(achievement: achievement, size: 140)

                    VStack(spacing: 8) {
                        Text(achievement.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))

                        VStack(spacing: 5) {
                            Text("获取条件")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DSColor.infoBlue)
                            Text(achievement.description)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(DSColor.mutedInk)
                                .multilineTextAlignment(.center)
                        }
                    }

                    if achievement.isUnlocked {
                        unlockedContent
                    } else {
                        progressContent
                    }
                }
                .foregroundStyle(DSColor.ink)
                .padding(24)
            }
            .background(DSColor.floatingPageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var progressContent: some View {
        VStack(spacing: 10) {
            ProgressView(value: achievement.clampedProgress)
                .tint(DSColor.infoBlue)
            Text("当前 \(achievement.displayCurrentValue) / \(achievement.targetValue)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if let reward = achievement.reward {
                Label("完成后全家获得 \(reward.displayText)", systemImage: "gift.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DSColor.infoBlue)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(DSColor.floatingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var unlockedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let date = achievement.unlockedAt {
                Label(
                    "解锁于 \(date.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "calendar"
                )
                .font(.system(size: 14, weight: .medium))
            }

            if let reward = achievement.reward {
                Label("家庭奖励：\(reward.displayText)", systemImage: "gift.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DSColor.infoBlue)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSColor.floatingSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AchievementArtwork: View {
    let achievement: AchievementItem?
    let size: CGFloat

    var body: some View {
        Group {
            if let assetName = achievement?.artworkAssetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .saturation(achievement?.isUnlocked == false ? 0 : 1)
                    .opacity(achievement?.isUnlocked == false ? 0.48 : 1)
            } else {
                Image(systemName: achievement?.systemImage ?? "medal.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.24)
                    .foregroundStyle(achievement?.isUnlocked == true ? DSColor.yellow : DSColor.infoBlue)
                    .background(achievement?.isUnlocked == true ? DSColor.choreYellowSurface : DSColor.choreBlueSurface)
                    .clipShape(Circle())
            }
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if achievement?.isUnlocked == false {
                Image(systemName: "lock.fill")
                    .font(.system(size: max(9, size * 0.16), weight: .bold))
                    .foregroundStyle(DSColor.floatingPrimaryText)
                    .padding(max(4, size * 0.07))
                    .background(DSColor.floatingSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(DSColor.floatingStroke, lineWidth: 0.8))
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Achievements") {
    NavigationStack {
        AchievementsView()
            .environmentObject(AppViewModel.previewLoggedIn())
    }
}
