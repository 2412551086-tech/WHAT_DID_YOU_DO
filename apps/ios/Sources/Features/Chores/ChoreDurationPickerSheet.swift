import SwiftUI

struct ChoreDurationPickerSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel

    let chore: ChoreItem
    let onCancel: () -> Void
    let onConfirm: (_ actualMinutes: Int, _ calculatedPoints: Int, _ pointsMultiplier: Double?) -> Void

    @State private var selectedMinutes: Int
    @State private var selectedPointsMultiplier: Double
    @State private var showsPremiumUpgrade = false

    init(
        chore: ChoreItem,
        initialMinutes: Int? = nil,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (_ actualMinutes: Int, _ calculatedPoints: Int, _ pointsMultiplier: Double?) -> Void
    ) {
        self.chore = chore
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _selectedMinutes = State(initialValue: max(1, min(180, initialMinutes ?? chore.minutes)))
        _selectedPointsMultiplier = State(
            initialValue: AppViewModel.defaultPointsMultiplier(for: chore)
        )
    }

    var body: some View {
        let presentation = ChorePresentation.resolve(chore)

        ZStack {
            DSColor.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Capsule()
                        .fill(DSColor.ink.opacity(0.28))
                        .frame(width: 44, height: 5)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                DSCard(fill: presentation.cardFill) {
                    HStack(spacing: 14) {
                        DSChoreIconTile(chore: chore, size: 58)

                        Text(chore.name)
                            .font(.appHeadline(24))
                            .foregroundStyle(DSColor.ink)
                            .lineLimit(2)

                        Spacer(minLength: 0)
                    }
                }

                DSCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("实际耗时")
                            .font(.appHeadline(18))
                            .foregroundStyle(DSColor.ink)

                        Picker("实际耗时", selection: $selectedMinutes) {
                            ForEach(1...180, id: \.self) { minute in
                                Text("\(minute) 分钟")
                                    .font(.appHeadline(22))
                                    .tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 154)
                        .clipped()
                    }
                }

                    multiplierCard

                DSCard(fill: DSColor.mint) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("预计积分")
                                .font(.appBody(14))
                                .foregroundStyle(DSColor.mutedInk)
                            Text("+\(estimatedPoints)")
                                .font(.appTitle(34))
                                .foregroundStyle(DSColor.ink)
                        }

                        Spacer()

                        Text("\(selectedMinutes) 分钟")
                            .font(.appHeadline(22))
                            .foregroundStyle(DSColor.ink)
                    }
                }

                    HStack(spacing: 12) {
                        DSButton(title: "取消", systemImage: "xmark.circle.fill", style: .secondary) {
                            onCancel()
                        }

                        DSButton(title: "确认记录", systemImage: "checkmark.circle.fill", style: .primary) {
                            onConfirm(
                                selectedMinutes,
                                estimatedPoints,
                                viewModel.hasPremiumAccess ? selectedPointsMultiplier : nil
                            )
                        }
                    }
                }
                .padding(20)
            }
        }
        .sheet(isPresented: $showsPremiumUpgrade) {
            PremiumUpgradeSheet(trigger: .pointsMultiplier)
                .environmentObject(viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var multiplierCard: some View {
        DSCard(fill: DSColor.yellow.opacity(0.42)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("积分倍率")
                            .font(.appHeadline(18))
                            .foregroundStyle(DSColor.ink)
                        Text(viewModel.hasPremiumAccess ? "按这次家务的实际难度调整" : "当前使用系统默认倍率")
                            .font(.appBody(13))
                            .foregroundStyle(DSColor.mutedInk)
                    }

                    Spacer(minLength: 8)

                    Text(String(format: "%.1fx", selectedPointsMultiplier))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(DSColor.ink)
                        .monospacedDigit()
                }

                if viewModel.hasPremiumAccess {
                    Slider(value: $selectedPointsMultiplier, in: 0.5...2, step: 0.1)
                        .tint(DSColor.coral)

                    HStack {
                        Text("0.5x")
                        Spacer()
                        Text("2.0x")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DSColor.mutedInk)
                } else {
                    Button {
                        showsPremiumUpgrade = true
                    } label: {
                        Label("高级版可自定义倍率", systemImage: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DSColor.ink)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(DSColor.pureSurface.opacity(0.88))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var estimatedPoints: Int {
        if viewModel.hasPremiumAccess {
            return AppViewModel.estimatedPoints(
                for: chore,
                selectedMinutes: selectedMinutes,
                pointsMultiplier: selectedPointsMultiplier
            )
        }
        return AppViewModel.estimatedPoints(for: chore, selectedMinutes: selectedMinutes)
    }
}

#Preview {
    ChoreDurationPickerSheet(
        chore: MockData.chores[0],
        onCancel: {},
        onConfirm: { _, _, _ in }
    )
    .environmentObject(AppViewModel.previewLoggedIn())
}
