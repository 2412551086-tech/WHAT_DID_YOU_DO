import SwiftUI

struct ActivityRow: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let record: ChoreRecord

    var body: some View {
        DSActivityRow(
            record: record,
            onLike: { viewModel.toggleLike(record) },
            onDelete: { viewModel.deleteRecord(record) },
            isLoading: viewModel.isLoading
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
