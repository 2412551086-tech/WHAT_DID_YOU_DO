import AudioToolbox
import SwiftUI
import UIKit

struct ChoreDurationPickerSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let chore: ChoreItem
    let onCancel: () -> Void
    let onConfirm: (_ actualMinutes: Int, _ calculatedPoints: Int, _ pointsMultiplier: Double?) -> Void

    @State private var selectedMinutes: Int
    @State private var selectedPointsMultiplier: Double
    @State private var showsPremiumUpgrade = false
    @StateObject private var wheelFeedback = ChoreDurationWheelFeedback()

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
            DSColor.pureSurface.ignoresSafeArea()
            presentation.accentColor
                .opacity(reduceTransparency ? 0.08 : 0.055)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        choreSummary

                        durationPicker

                        multiplierControl(accentColor: presentation.accentColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            confirmButton
        }
        .sheet(isPresented: $showsPremiumUpgrade) {
            PremiumUpgradeSheet(trigger: .pointsMultiplier)
                .environmentObject(viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var sheetHeader: some View {
        ZStack {
            Text("记录家务")
                .font(.headline)
                .foregroundStyle(DSColor.ink)

            HStack {
                Button("取消", action: onCancel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(DSColor.mutedInk)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var choreSummary: some View {
        HStack(spacing: 12) {
            DSChoreIconTile(chore: chore, size: 46)

            Text(chore.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(DSColor.ink)
                .lineLimit(2)

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 1) {
                Text("预计积分")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DSColor.mutedInk)

                Text("+\(estimatedPoints) 分")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(DSColor.ink)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("实际耗时")
                .font(.headline)
                .foregroundStyle(DSColor.ink)

            Picker("实际耗时", selection: $selectedMinutes) {
                ForEach(1...180, id: \.self) { minute in
                    Text("\(minute) 分钟")
                        .font(.title3.weight(.semibold))
                        .tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 132)
            .clipped()
            .onChange(of: selectedMinutes) { oldValue, newValue in
                guard oldValue != newValue else { return }
                wheelFeedback.playTick()
            }
            .onAppear {
                wheelFeedback.prepare()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(DSColor.pureSurface.opacity(reduceTransparency ? 0.96 : 0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var confirmButton: some View {
        Button {
            onConfirm(
                selectedMinutes,
                estimatedPoints,
                viewModel.hasPremiumAccess ? selectedPointsMultiplier : nil
            )
        } label: {
            Label("记录 \(selectedMinutes) 分钟 · +\(estimatedPoints) 分", systemImage: "checkmark")
                .font(.headline)
                .foregroundStyle(DSColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(DSColor.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(DSColor.pureSurface.opacity(reduceTransparency ? 1 : 0.92))
        .accessibilityLabel("记录 \(selectedMinutes) 分钟，获得 \(estimatedPoints) 分")
    }

    private func multiplierControl(accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("积分倍率")
                        .font(.headline)
                        .foregroundStyle(DSColor.ink)
                    Text("按家务难度调节倍率")
                        .font(.caption)
                        .foregroundStyle(DSColor.mutedInk)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 2) {
                    if !viewModel.hasPremiumAccess {
                        Label("高级版", systemImage: "lock.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DSColor.mutedInk)
                    }

                    Text(String(format: "%.1fx", selectedPointsMultiplier))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(DSColor.ink)
                        .monospacedDigit()
                }
            }

            DifficultyMultiplierSlider(
                value: $selectedPointsMultiplier,
                accentColor: accentColor,
                isEnabled: viewModel.hasPremiumAccess,
                onLockedInteraction: {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    showsPremiumUpgrade = true
                }
            )

            HStack {
                Text("0.5x")
                Spacer()
                Text("2.0x")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(DSColor.mutedInk)
        }
        .padding(.vertical, 3)
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

private struct DifficultyMultiplierSlider: View {
    @Binding var value: Double

    let accentColor: Color
    let isEnabled: Bool
    let onLockedInteraction: () -> Void

    @State private var hasTriggeredLockedInteraction = false

    private let range = 0.5...2.0
    private let knobSize: CGFloat = 42

    var body: some View {
        GeometryReader { proxy in
            let travel = max(1, proxy.size.width - knobSize)
            let progress = normalizedValue

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(DSColor.pureSurface.opacity(0.78))

                Capsule(style: .continuous)
                    .fill(accentColor.opacity(isEnabled ? 0.34 : 0.12))
                    .frame(width: knobSize + (travel * progress))

                Circle()
                    .fill(isEnabled ? accentColor : DSColor.pureSurface)
                    .frame(width: knobSize, height: knobSize)
                    .overlay {
                        if isEnabled {
                            Circle()
                                .fill(DSColor.pureSurface)
                                .frame(width: 8, height: 8)
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(DSColor.ink)
                        }
                    }
                    .shadow(color: DSColor.shadow.opacity(0.16), radius: 6, x: 0, y: 3)
                    .offset(x: travel * progress)
            }
            .contentShape(Capsule(style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { gesture in
                        guard abs(gesture.translation.width) > abs(gesture.translation.height) else {
                            return
                        }
                        guard isEnabled else {
                            triggerLockedInteraction()
                            return
                        }
                        updateValue(at: gesture.location.x, travel: travel)
                    }
                    .onEnded { _ in
                        hasTriggeredLockedInteraction = false
                    }
            )
            .onTapGesture {
                guard !isEnabled else { return }
                triggerLockedInteraction()
            }
        }
        .frame(height: 46)
        .accessibilityElement()
        .accessibilityLabel("积分倍率")
        .accessibilityValue(String(format: "%.1f 倍", value))
        .accessibilityHint(isEnabled ? "按家务难度调节倍率" : "高级版可按家务难度调节倍率，轻点查看")
        .accessibilityAdjustableAction { direction in
            guard isEnabled else {
                triggerLockedInteraction()
                return
            }
            switch direction {
            case .increment:
                value = min(range.upperBound, value + 0.1)
            case .decrement:
                value = max(range.lowerBound, value - 0.1)
            @unknown default:
                break
            }
        }
    }

    private var normalizedValue: Double {
        (min(range.upperBound, max(range.lowerBound, value)) - range.lowerBound)
            / (range.upperBound - range.lowerBound)
    }

    private func updateValue(at xPosition: CGFloat, travel: CGFloat) {
        let rawProgress = min(1, max(0, (xPosition - knobSize / 2) / travel))
        let rawValue = range.lowerBound + (rawProgress * (range.upperBound - range.lowerBound))
        value = (rawValue * 10).rounded() / 10
    }

    private func triggerLockedInteraction() {
        guard !hasTriggeredLockedInteraction else { return }
        hasTriggeredLockedInteraction = true
        onLockedInteraction()
    }
}

@MainActor
private final class ChoreDurationWheelFeedback: ObservableObject {
    private let selectionFeedback = UISelectionFeedbackGenerator()

    func prepare() {
        selectionFeedback.prepare()
    }

    func playTick() {
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
        AudioServicesPlaySystemSound(1104)
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
