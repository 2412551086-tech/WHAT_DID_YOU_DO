import SwiftUI

struct DSCard<Content: View>: View {
    let fill: Color
    let content: Content

    init(fill: Color = DSColor.surface, @ViewBuilder content: () -> Content) {
        self.fill = fill
        self.content = content()
    }

    var body: some View {
        DSBrutalCard(fill: fill, content: { content })
    }
}

struct DSBrutalCard<Content: View>: View {
    let fill: Color
    var cornerRadius: CGFloat
    var padding: CGFloat
    var strokeWidth: CGFloat
    var shadowOffset: CGSize
    let content: Content

    init(
        fill: Color = DSColor.surface,
        cornerRadius: CGFloat = DSCornerRadius.largeCard,
        padding: CGFloat = DSSpacing.cardPadding,
        strokeWidth: CGFloat = DSStroke.primary,
        shadowOffset: CGSize = DSShadow.hardOffset,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.strokeWidth = strokeWidth
        self.shadowOffset = shadowOffset
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .shadow(color: .white.opacity(0.72), radius: 8, x: -5, y: -5)
                    .shadow(
                        color: DSColor.ink.opacity(DSShadow.hardOpacity),
                        radius: 0,
                        x: shadowOffset.width,
                        y: shadowOffset.height
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DSColor.ink, lineWidth: strokeWidth)
            )
    }
}

struct DSPageBackground<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()
            content
        }
    }
}

struct DSSectionHeader: View {
    let title: String
    var subtitle: String?
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let systemImage {
                Label(title, systemImage: systemImage)
                    .font(.appHeadline())
                    .foregroundStyle(DSColor.ink)
            } else {
                Text(title)
                    .font(.appHeadline())
                    .foregroundStyle(DSColor.ink)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.appBody(14))
                    .foregroundStyle(DSColor.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DSBadge: View {
    let text: String
    var fill: Color = DSColor.yellow

    var body: some View {
        Text(text)
            .font(.appBody(12))
            .foregroundStyle(DSColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(fill)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(DSColor.ink, lineWidth: DSStroke.hairline))
    }
}

struct DSStickerLabel: View {
    let title: String
    var systemImage: String?
    var fill: Color = DSColor.yellow

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .black))
            }
            Text(title)
                .font(.appBody(13))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(DSColor.ink)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.smallCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSCornerRadius.smallCard, style: .continuous)
                .stroke(DSColor.ink, lineWidth: DSStroke.hairline)
        )
        .shadow(color: DSColor.ink.opacity(DSShadow.weakOpacity), radius: 0, x: 2, y: 2)
    }
}

struct DSScoreCard: View {
    let title: String
    let value: String
    var caption: String?
    var fill: Color
    var systemImage: String?

    var body: some View {
        DSBrutalCard(fill: fill) {
            VStack(alignment: .leading, spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .black))
                        .frame(width: 38, height: 38)
                        .background(DSColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(DSColor.ink, lineWidth: DSStroke.hairline)
                        )
                }

                Text(value)
                    .font(.appHeadline(24))
                    .foregroundStyle(DSColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(title)
                    .font(.appBody(13))
                    .foregroundStyle(DSColor.mutedInk)
                if let caption {
                    Text(caption)
                        .font(.appBody(12))
                        .foregroundStyle(DSColor.mutedInk)
                        .lineLimit(2)
                }
            }
        }
    }
}

struct DSMetricPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        DSScoreCard(title: title, value: value, fill: color)
    }
}

struct DSChoreCard: View {
    let chore: ChoreItem
    var showsPinnedBadge = false

    var body: some View {
        DSBrutalCard(fill: chore.color) {
            VStack(alignment: .leading, spacing: 11) {
                Image(systemName: chore.icon)
                    .font(.system(size: 27, weight: .black))
                    .frame(width: 44, height: 44)
                    .background(DSColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DSColor.ink, lineWidth: DSStroke.secondary)
                    )
                Text(chore.name)
                    .font(.appHeadline(19))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(height: 48, alignment: .topLeading)
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
                    DSStickerIcon(systemImage: "lock.fill", fill: DSColor.surface)
                } else if showsPinnedBadge {
                    DSStickerIcon(systemImage: "pin.fill", fill: DSColor.yellow)
                }
            }
        }
        .opacity(chore.isLocked ? 0.72 : 1)
    }
}

struct DSActivityRow: View {
    let record: ChoreRecord
    var onLike: (() -> Void)?
    var onDelete: (() -> Void)?
    var isLoading = false

    var body: some View {
        DSBrutalCard(fill: DSColor.surface) {
            HStack(spacing: 13) {
                DSAvatarView(
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
                                DSAvatarView(
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
                    onLike?()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: record.likedByMe ? "heart.fill" : "heart")
                            .font(.system(size: 20, weight: .black))
                        Text("\(record.likeCount)")
                            .font(.appBody(12))
                    }
                    .foregroundStyle(record.likedByMe ? DSColor.coral : DSColor.ink)
                    .frame(width: 42, height: 46)
                    .opacity(isLoading ? 0.52 : 1)
                }
                .buttonStyle(.plain)
                .disabled(isLoading || onLike == nil)
                .accessibilityLabel(record.likedByMe ? "取消点赞" : "点赞")
            }
            .foregroundStyle(DSColor.ink)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if record.canDelete, let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash.fill")
                }
            }
        }
    }
}

struct DSAvatarView: View {
    let avatarKey: String?
    let fallbackText: String
    var size: CGFloat = 48

    var body: some View {
        AvatarView(avatarKey: avatarKey, fallbackText: fallbackText, size: size)
    }
}

struct DSRankingRow: View {
    let index: Int
    let member: FamilyMember

    var body: some View {
        DSBrutalCard(fill: member.color) {
            HStack(spacing: 14) {
                Text("#\(index + 1)")
                    .font(.appHeadline(20))
                    .frame(width: 52, height: 44)
                    .background(DSColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DSColor.ink, lineWidth: DSStroke.secondary)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.appHeadline(18))
                    Text(member.badge)
                        .font(.appBody(13))
                        .foregroundStyle(DSColor.mutedInk)
                }

                Spacer()

                Text("\(member.monthlyPoints)")
                    .font(.appHeadline(24))
            }
            .foregroundStyle(DSColor.ink)
        }
    }
}

struct DSEmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "sparkles"
    var fill: Color = DSColor.mint

    var body: some View {
        DSBrutalCard(fill: fill) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .black))
                Text(title)
                    .font(.appHeadline(20))
                Text(message)
                    .font(.appBody(14))
                    .foregroundStyle(DSColor.mutedInk)
            }
            .foregroundStyle(DSColor.ink)
        }
    }
}

struct DSLoadingStateView: View {
    let message: String

    var body: some View {
        DSBrutalCard(fill: DSColor.sky) {
            Label(message, systemImage: "arrow.triangle.2.circlepath")
                .font(.appBody(15))
                .foregroundStyle(DSColor.ink)
        }
    }
}

struct DSErrorBanner: View {
    let message: String

    var body: some View {
        DSBrutalCard(fill: DSColor.coral) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.appBody(15))
                .foregroundStyle(DSColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if DEBUG
struct DSDebugPanel: View {
    struct Row: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        var allowsWrapping = false
    }

    let rows: [Row]

    var body: some View {
        DSBrutalCard(fill: DSColor.lavender) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title)
                            .font(.appBody(12))
                            .foregroundStyle(DSColor.mutedInk)
                        Text(row.value)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DSColor.ink)
                            .lineLimit(row.allowsWrapping ? 3 : 1)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
#endif

private struct DSStickerIcon: View {
    let systemImage: String
    let fill: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .black))
            .foregroundStyle(DSColor.ink)
            .padding(8)
            .background(fill)
            .clipShape(Circle())
            .overlay(Circle().stroke(DSColor.ink, lineWidth: DSStroke.hairline))
    }
}
