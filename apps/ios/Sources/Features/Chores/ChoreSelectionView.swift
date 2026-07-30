import SwiftUI

struct ChoreSelectionView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var choreForDurationPicker: ChoreItem?
    @State private var premiumChore: ChoreItem?
    @State private var isEditingCards = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("选择家务")
                                .font(.appTitle())
                            Text("\(viewModel.modeLabel)：先选家务，再按实际耗时记一笔。")
                                .font(.appBody())
                                .foregroundStyle(DSColor.mutedInk)
                        }

                        Spacer(minLength: 4)

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                isEditingCards.toggle()
                            }
                        } label: {
                            Label(
                                isEditingCards ? "完成" : "编辑",
                                systemImage: isEditingCards ? "checkmark.circle.fill" : "slider.horizontal.3"
                            )
                            .font(.appBody(14))
                            .foregroundStyle(DSColor.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(isEditingCards ? DSColor.mint : DSColor.sky)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(DSColor.ink, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isLoading)
                    }
                    .foregroundStyle(DSColor.ink)
                    .padding(.top, 16)

                    statusBanner

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(viewModel.displayedChores) { chore in
                            choreCard(chore)
                        }
                    }
                }
                .padding(20)
            }
        }
        .sheet(item: $choreForDurationPicker) { chore in
            ChoreDurationPickerSheet(
                chore: chore,
                initialMinutes: viewModel.getDefaultDuration(for: chore),
                onCancel: {
                    choreForDurationPicker = nil
                },
                onConfirm: { actualMinutes, calculatedPoints in
                    viewModel.saveLastDuration(choreId: chore.id, minutes: actualMinutes)
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
        .alert(
            "解锁高级家务",
            isPresented: Binding(
                get: { premiumChore != nil },
                set: { isPresented in
                    if !isPresented {
                        premiumChore = nil
                    }
                }
            ),
            presenting: premiumChore
        ) { _ in
            Button("暂不开通", role: .cancel) {
                premiumChore = nil
            }
            Button("开通高级会员") {
                premiumChore = nil
            }
        } message: { chore in
            Text("「\(chore.name)」属于高级家务。开通高级会员后即可记录实际耗时并获得积分。")
        }
    }

    @ViewBuilder
    private func choreCard(_ chore: ChoreItem) -> some View {
        if isEditingCards && !chore.isLocked {
            DSChoreCard(chore: chore)
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            viewModel.toggleChorePinned(chore)
                        }
                    } label: {
                        Image(systemName: viewModel.isChorePinned(chore) ? "pin.fill" : "pin")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(DSColor.ink)
                            .frame(width: 36, height: 36)
                            .background(viewModel.isChorePinned(chore) ? DSColor.yellow : DSColor.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(DSColor.ink, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .accessibilityLabel(viewModel.isChorePinned(chore) ? "取消置顶" : "置顶")
                }
                .draggable(chore.id) {
                    DSChoreCard(chore: chore, showsPinnedBadge: viewModel.isChorePinned(chore))
                        .frame(width: 180)
                        .opacity(0.9)
                }
                .dropDestination(for: String.self) { draggedIDs, _ in
                    guard let sourceID = draggedIDs.first else {
                        return false
                    }

                    return withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        viewModel.moveUnlockedChore(sourceID, to: chore.id)
                    }
                }
        } else {
            Button {
                if chore.isLocked {
                    premiumChore = chore
                } else {
                    choreForDurationPicker = chore
                }
            } label: {
                DSChoreCard(
                    chore: chore,
                    showsPinnedBadge: viewModel.isChorePinned(chore)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if viewModel.isLoading {
            DSLoadingStateView(message: viewModel.loadingMessage ?? "正在处理")
        }

        if let errorMessage = viewModel.errorMessage {
            DSErrorBanner(message: errorMessage)
        }
    }
}

#Preview {
    NavigationStack {
        ChoreSelectionView()
            .environmentObject(AppViewModel.previewLoggedIn())
    }
}
