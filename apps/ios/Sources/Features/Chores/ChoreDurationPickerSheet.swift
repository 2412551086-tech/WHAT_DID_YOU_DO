import SwiftUI

struct ChoreDurationPickerSheet: View {
    let chore: ChoreItem
    let onCancel: () -> Void
    let onConfirm: (_ actualMinutes: Int, _ calculatedPoints: Int) -> Void

    @State private var selectedMinutes: Int

    init(
        chore: ChoreItem,
        initialMinutes: Int? = nil,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (_ actualMinutes: Int, _ calculatedPoints: Int) -> Void
    ) {
        self.chore = chore
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _selectedMinutes = State(initialValue: max(1, min(180, initialMinutes ?? chore.minutes)))
    }

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Capsule()
                    .fill(DSColor.ink.opacity(0.28))
                    .frame(width: 44, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                DSCard(fill: chore.color) {
                    Label(chore.name, systemImage: chore.icon)
                        .font(.appHeadline(24))
                        .foregroundStyle(DSColor.ink)
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
                        onConfirm(selectedMinutes, estimatedPoints)
                    }
                }
            }
            .padding(20)
        }
    }

    private var estimatedPoints: Int {
        AppViewModel.estimatedPoints(for: chore, selectedMinutes: selectedMinutes)
    }
}

#Preview {
    ChoreDurationPickerSheet(
        chore: MockData.chores[0],
        onCancel: {},
        onConfirm: { _, _ in }
    )
}
