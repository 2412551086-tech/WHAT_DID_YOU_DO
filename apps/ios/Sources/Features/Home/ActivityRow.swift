import SwiftUI

struct ActivityRow: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let record: ChoreRecord

    var body: some View {
        DSCard(fill: DSColor.surface) {
            HStack(spacing: 13) {
                AvatarView(
                    avatarKey: record.avatarKey,
                    fallbackText: record.memberName,
                    size: 48
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text("\(record.displayIdentity) · \(record.memberName)")
                        .font(.appHeadline(16))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text("\(record.choreName) · \(record.actualMinutes) 分钟 · +\(record.points) 分")
                        .font(.appBody(13))
                        .foregroundStyle(DSColor.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)

                    if !record.likedBy.isEmpty {
                        HStack(spacing: 5) {
                            ForEach(Array(record.likedBy.prefix(4))) { liker in
                                AvatarView(
                                    avatarKey: liker.avatarKey,
                                    fallbackText: liker.displayName,
                                    size: 22
                                )
                            }
                            Text("为这笔功劳点赞")
                                .font(.appBody(11))
                                .foregroundStyle(DSColor.mutedInk)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                }

                Spacer(minLength: 6)

                Button {
                    viewModel.toggleLike(record)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: record.likedByMe ? "heart.fill" : "heart")
                            .font(.system(size: 20, weight: .black))
                        Text("\(record.likeCount)")
                            .font(.appBody(12))
                    }
                    .foregroundStyle(record.likedByMe ? DSColor.coral : DSColor.ink)
                    .frame(width: 42, height: 46)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
                .accessibilityLabel(record.likedByMe ? "取消点赞" : "点赞")
            }
            .foregroundStyle(DSColor.ink)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if record.canDelete {
                Button(role: .destructive) {
                    viewModel.deleteRecord(record)
                } label: {
                    Label("删除", systemImage: "trash.fill")
                }
            }
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
