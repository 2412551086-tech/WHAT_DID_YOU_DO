import SwiftUI

struct ActivityRow: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let record: ChoreRecord
    var presentation: DSActivityRowPresentation = .standalone

    var body: some View {
        DSActivityRow(
            record: record,
            onQuickReaction: { viewModel.toggleLike(record) },
            onReaction: { viewModel.react(to: record, with: $0) },
            onDelete: { viewModel.deleteRecord(record) },
            isLoading: viewModel.isLoading,
            presentation: presentation
        )
    }
}

#Preview {
    List {
        ActivityRow(record: MockData.todayRecords[0])
            .environmentObject(AppViewModel.previewLoggedIn())
    }
    .listStyle(.plain)
}
