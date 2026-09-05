import SwiftUI

struct ActivityRow: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let record: ChoreRecord
    var presentation: DSActivityRowPresentation = .standalone
    @State private var recordBeingEdited: ChoreRecord?

    var body: some View {
        DSActivityRow(
            record: record,
            timeZoneIdentifier: viewModel.currentFamily?.timezone,
            onQuickReaction: { viewModel.toggleLike(record) },
            onReaction: { viewModel.react(to: record, with: $0) },
            onEdit: { recordBeingEdited = record },
            onDelete: { viewModel.deleteRecord(record) },
            isLoading: viewModel.isLoading,
            presentation: presentation
        )
        .sheet(item: $recordBeingEdited) { selectedRecord in
            ChoreDurationPickerSheet(
                chore: viewModel.choreItem(for: selectedRecord),
                initialMinutes: selectedRecord.actualMinutes,
                initialPointsMultiplier: selectedRecord.pointsMultiplier,
                mode: .edit,
                onCancel: { recordBeingEdited = nil },
                onConfirm: { actualMinutes, _, pointsMultiplier in
                    viewModel.updateRecord(
                        selectedRecord,
                        actualMinutes: actualMinutes,
                        pointsMultiplier: pointsMultiplier
                    )
                    recordBeingEdited = nil
                }
            )
            .environmentObject(viewModel)
            .presentationDetents([.fraction(0.70), .large])
            .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    List {
        ActivityRow(record: MockData.todayRecords[0])
            .environmentObject(AppViewModel.previewLoggedIn())
    }
    .listStyle(.plain)
}
