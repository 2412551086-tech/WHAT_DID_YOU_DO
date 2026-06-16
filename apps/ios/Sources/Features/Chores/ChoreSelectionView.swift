import SwiftUI

struct ChoreSelectionView: View {
    @EnvironmentObject private var viewModel: AppViewModel

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
                        Text("核心 10 项免费开放，点一个就会生成今日记录并回到首页。")
                            .font(.appBody())
                            .foregroundStyle(DSColor.mutedInk)
                    }
                    .foregroundStyle(DSColor.ink)
                    .padding(.top, 16)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(viewModel.chores) { chore in
                            Button {
                                viewModel.record(chore)
                            } label: {
                                ChoreTile(chore: chore)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
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
                    Text("+\(chore.points)")
                }
                .font(.appBody(13))
            }
            .foregroundStyle(DSColor.ink)
        }
    }
}

#Preview {
    NavigationStack {
        ChoreSelectionView()
            .environmentObject(AppViewModel.previewLoggedIn())
    }
}
