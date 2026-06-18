import SwiftUI

struct ChoreSelectionView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var choreForDurationPicker: ChoreItem?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择家务")
                            .font(.appTitle())
                        Text("\(viewModel.modeLabel)：先选家务，再按实际耗时记一笔。")
                            .font(.appBody())
                            .foregroundStyle(DSColor.mutedInk)
                    }
                    .foregroundStyle(DSColor.ink)
                    .padding(.top, 16)

                    statusBanner

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(viewModel.chores) { chore in
                            Button {
                                if !chore.isLocked {
                                    choreForDurationPicker = chore
                                }
                            } label: {
                                ChoreTile(chore: chore)
                            }
                            .buttonStyle(.plain)
                            .disabled(chore.isLocked || viewModel.isLoading)
                        }
                    }
                }
                .padding(20)
            }
        }
        .sheet(item: $choreForDurationPicker) { chore in
            ChoreDurationPickerSheet(
                chore: chore,
                onCancel: {
                    choreForDurationPicker = nil
                },
                onConfirm: { actualMinutes, calculatedPoints in
                    viewModel.record(
                        chore,
                        actualMinutes: actualMinutes,
                        calculatedPoints: calculatedPoints
                    )
                    choreForDurationPicker = nil
                }
            )
            .presentationDetents([.height(620), .large])
            .presentationDragIndicator(.hidden)
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if viewModel.isLoading {
            DSCard(fill: DSColor.sky) {
                Label(viewModel.loadingMessage ?? "正在处理", systemImage: "arrow.triangle.2.circlepath")
                    .font(.appBody(15))
                    .foregroundStyle(DSColor.ink)
            }
        }

        if let errorMessage = viewModel.errorMessage {
            DSCard(fill: DSColor.coral) {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.appBody(15))
                    .foregroundStyle(DSColor.ink)
            }
        }
    }
}

private struct ChoreTile: View {
    let chore: ChoreItem

    var body: some View {
        DSCard(fill: chore.color) {
            VStack(alignment: .leading, spacing: 11) {
                Image(systemName: chore.icon)
                    .font(.system(size: 27, weight: .black))
                    .frame(width: 44, height: 44)
                    .background(DSColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DSColor.ink, lineWidth: 2)
                    )
                Text(chore.name)
                    .font(.appHeadline(19))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(chore.category)
                    .font(.appBody(13))
                    .foregroundStyle(DSColor.mutedInk)
                HStack {
                    Label("\(chore.minutes)分", systemImage: "clock.fill")
                    Spacer()
                    Text(chore.isLocked ? "锁定" : "+\(chore.points)")
                }
                .font(.appBody(13))
            }
            .foregroundStyle(chore.isLocked ? DSColor.mutedInk : DSColor.ink)
            .overlay(alignment: .topTrailing) {
                if chore.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .black))
                        .padding(8)
                        .background(DSColor.surface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(DSColor.ink, lineWidth: 1.5))
                }
            }
        }
        .opacity(chore.isLocked ? 0.72 : 1)
    }
}

#Preview {
    NavigationStack {
        ChoreSelectionView()
            .environmentObject(AppViewModel.previewLoggedIn())
    }
}
