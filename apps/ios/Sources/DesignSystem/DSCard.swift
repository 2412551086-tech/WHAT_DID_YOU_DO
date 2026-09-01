import Foundation
import SwiftUI
import UIKit

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
                    .shadow(color: DSColor.raisedHighlight, radius: 8, x: -5, y: -5)
                    .shadow(
                        color: DSColor.shadow.opacity(DSShadow.hardOpacity),
                        radius: 0,
                        x: shadowOffset.width,
                        y: shadowOffset.height
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DSColor.outline, lineWidth: strokeWidth)
            )
    }
}

struct DSQuietCard<Content: View>: View {
    var fill: Color
    var cornerRadius: CGFloat
    var padding: CGFloat
    let content: Content

    init(
        fill: Color = DSColor.pureSurface,
        cornerRadius: CGFloat = DSCornerRadius.largeCard,
        padding: CGFloat = DSSpacing.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .shadow(
                        color: DSColor.shadow.opacity(DSShadow.softOpacity),
                        radius: DSShadow.softRadius,
                        x: 0,
                        y: DSShadow.softYOffset
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DSColor.subtleStroke, lineWidth: 1)
            )
    }
}

enum DSFloatingElevation {
    case primary
    case secondary
    case none

    fileprivate var shadowOpacity: Double {
        switch self {
        case .primary: DSShadow.floatingPrimaryOpacity
        case .secondary: DSShadow.floatingSecondaryOpacity
        case .none: 0
        }
    }

    fileprivate var shadowRadius: CGFloat {
        switch self {
        case .primary: DSShadow.floatingPrimaryRadius
        case .secondary: DSShadow.floatingSecondaryRadius
        case .none: 0
        }
    }

    fileprivate var shadowYOffset: CGFloat {
        switch self {
        case .primary: DSShadow.floatingPrimaryYOffset
        case .secondary: DSShadow.floatingSecondaryYOffset
        case .none: 0
        }
    }

    fileprivate var contactShadowOpacity: Double {
        switch self {
        case .primary: DSShadow.floatingContactOpacity
        case .secondary, .none: 0
        }
    }

    fileprivate var contactShadowRadius: CGFloat {
        switch self {
        case .primary: DSShadow.floatingContactRadius
        case .secondary, .none: 0
        }
    }

    fileprivate var contactShadowYOffset: CGFloat {
        switch self {
        case .primary: DSShadow.floatingContactYOffset
        case .secondary, .none: 0
        }
    }
}

struct DSFloatingSurface<Content: View>: View {
    var cornerRadius: CGFloat
    var padding: CGFloat
    var elevation: DSFloatingElevation
    let content: Content

    init(
        cornerRadius: CGFloat = 18,
        padding: CGFloat = 16,
        elevation: DSFloatingElevation = .secondary,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.elevation = elevation
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DSColor.floatingSurface)
                    .shadow(
                        color: DSColor.shadow.opacity(elevation.contactShadowOpacity),
                        radius: elevation.contactShadowRadius,
                        x: 0,
                        y: elevation.contactShadowYOffset
                    )
                    .shadow(
                        color: DSColor.shadow.opacity(elevation.shadowOpacity),
                        radius: elevation.shadowRadius,
                        x: 0,
                        y: elevation.shadowYOffset
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DSColor.floatingStroke, lineWidth: 0.7)

                RoundedRectangle(cornerRadius: max(0, cornerRadius - 1), style: .continuous)
                    .inset(by: 1)
                    .stroke(DSColor.floatingHighlight, lineWidth: 0.5)
            }
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
            .overlay(Capsule().stroke(DSColor.outline, lineWidth: DSStroke.hairline))
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
                .stroke(DSColor.outline, lineWidth: DSStroke.hairline)
        )
        .shadow(color: DSColor.shadow.opacity(DSShadow.weakOpacity), radius: 0, x: 2, y: 2)
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
                                .stroke(DSColor.outline, lineWidth: DSStroke.hairline)
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

struct ChorePresentation {
    let assetName: String?
    let categoryLabel: String
    let cardFill: Color
    let accentColor: Color

    static func resolve(_ chore: ChoreItem) -> ChorePresentation {
        let categoryLabel = ChoreCategory.resolve(chore.category, choreName: chore.name).rawValue

        if chore.isCustom, let option = CustomChoreCatalog.option(for: chore.icon) {
            return .init(
                assetName: option.id,
                categoryLabel: categoryLabel,
                cardFill: option.color.opacity(0.14),
                accentColor: option.color
            )
        }

        switch kind(for: chore) {
        case .cook:
            return .init(
                assetName: "chore_core_cook_prepare",
                categoryLabel: categoryLabel,
                cardFill: DSColor.choreYellowSurface,
                accentColor: DSColor.yellow
            )
        case .dishes:
            return .init(
                assetName: "chore_core_dishes_cleanup",
                categoryLabel: categoryLabel,
                cardFill: DSColor.choreBlueSurface,
                accentColor: DSColor.infoBlue
            )
        case .laundry:
            return .init(
                assetName: "chore_core_laundry",
                categoryLabel: categoryLabel,
                cardFill: DSColor.choreMintSurface,
                accentColor: DSColor.mint
            )
        case .foldClothes:
            return .init(
                assetName: "chore_core_fold_clothes",
                categoryLabel: categoryLabel,
                cardFill: DSColor.chorePinkSurface,
                accentColor: Color(red: 1.00, green: 0.63, blue: 0.70)
            )
        case .sweep:
            return .init(
                assetName: "chore_core_sweep_vacuum",
                categoryLabel: categoryLabel,
                cardFill: DSColor.choreYellowSurface,
                accentColor: DSColor.yellow
            )
        case .mop:
            return .init(
                assetName: "chore_core_mop_floor",
                categoryLabel: categoryLabel,
                cardFill: DSColor.choreBlueSurface,
                accentColor: DSColor.infoBlue
            )
        case .organize:
            return .init(
                assetName: "chore_core_organize_storage",
                categoryLabel: categoryLabel,
                cardFill: DSColor.choreMintSurface,
                accentColor: DSColor.mint
            )
        case .bathroom:
            return .init(
                assetName: "chore_core_bathroom_clean",
                categoryLabel: categoryLabel,
                cardFill: DSColor.chorePinkSurface,
                accentColor: Color(red: 1.00, green: 0.63, blue: 0.70)
            )
        case .trash:
            return .init(
                assetName: "chore_core_trash_recycling",
                categoryLabel: categoryLabel,
                cardFill: DSColor.choreBlueSurface,
                accentColor: DSColor.infoBlue
            )
        case .shopping:
            return .init(
                assetName: "chore_core_shopping_supplies",
                categoryLabel: categoryLabel,
                cardFill: DSColor.choreYellowSurface,
                accentColor: DSColor.yellow
            )
        case .changeBedding:
            return fallback(chore, categoryLabel: categoryLabel, assetName: "chore_premium_change_bedding")
        case .cleanStove:
            return fallback(chore, categoryLabel: categoryLabel, assetName: "chore_premium_clean_stove")
        case .walkDog:
            return fallback(chore, categoryLabel: categoryLabel, assetName: "chore_premium_walk_dog")
        case nil:
            return fallback(chore, categoryLabel: categoryLabel)
        }
    }

    private static func fallback(
        _ chore: ChoreItem,
        categoryLabel: String,
        assetName: String? = nil
    ) -> ChorePresentation {
        ChorePresentation(
            assetName: assetName ?? (chore.icon.hasPrefix("chore_") ? chore.icon : nil),
            categoryLabel: categoryLabel,
            cardFill: chore.isLocked ? DSColor.pureSurface : chore.color.opacity(0.12),
            accentColor: chore.color
        )
    }

    private static func kind(for chore: ChoreItem) -> Kind? {
        let name = chore.name.replacingOccurrences(of: " ", with: "")

        if name.contains("换床单") { return .changeBedding }
        if name.contains("灶台") { return .cleanStove }
        if name.contains("遛狗") { return .walkDog }
        if name.contains("饭后") || name.contains("洗碗") { return .dishes }
        if name.contains("收衣") || name.contains("叠衣") { return .foldClothes }
        if name.contains("洗衣") { return .laundry }
        if name.contains("拖地") || name.contains("湿清洁") { return .mop }
        if name.contains("扫地") || name.contains("吸尘") { return .sweep }
        if name.contains("卫生间") { return .bathroom }
        if name.contains("倒垃圾") || name.contains("垃圾分类") { return .trash }
        if name.contains("采购") || name.contains("补货") { return .shopping }
        if name.contains("整理收纳") { return .organize }
        if name.contains("做饭") || name.contains("备餐") { return .cook }

        return nil
    }

    private enum Kind {
        case cook
        case dishes
        case laundry
        case foldClothes
        case sweep
        case mop
        case organize
        case bathroom
        case trash
        case shopping
        case changeBedding
        case cleanStove
        case walkDog
    }
}

struct DSChoreCard: View {
    let chore: ChoreItem
    var showsPinnedBadge = false

    var body: some View {
        let presentation = ChorePresentation.resolve(chore)

        DSQuietCard(
            fill: presentation.cardFill,
            cornerRadius: DSCornerRadius.smallCard,
            padding: 8
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    DSChoreIconTile(chore: chore, size: 56)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(chore.name)
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text("\(chore.minutes) 分钟")
                                .font(.system(size: 12, weight: .regular, design: .default))
                                .foregroundStyle(DSColor.mutedInk)
                                .monospacedDigit()

                            Spacer(minLength: 2)

                            Text("+\(chore.points)")
                                .font(.system(size: 18, weight: .semibold, design: .default))
                                .monospacedDigit()
                        }
                    }
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(presentation.accentColor)
                        .frame(width: 7, height: 7)

                    Text(presentation.categoryLabel)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundStyle(DSColor.mutedInk)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if showsPinnedBadge {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DSColor.ink)
                            .frame(width: 24, height: 24)
                            .background(DSColor.yellow)
                            .clipShape(Circle())
                            .accessibilityHidden(true)
                    }
                }
            }
            .foregroundStyle(DSColor.ink)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(chore.name)，\(chore.minutes) 分钟，\(chore.points) 积分，\(presentation.categoryLabel)"
        )
    }
}

struct DSChoreIconTile: View {
    let chore: ChoreItem
    let size: CGFloat

    var body: some View {
        let presentation = ChorePresentation.resolve(chore)
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)

        ZStack {
            DSColor.pureSurface

            if let assetName = presentation.assetName {
                DSChoreAssetImage(assetName: assetName)
                    .frame(width: size, height: size)
            } else {
                Image(systemName: chore.icon)
                    .font(.system(size: size * 0.43, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(DSColor.ink)
                    .frame(width: size, height: size)
                    .background(chore.color.opacity(0.88))
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .shadow(color: DSColor.shadow.opacity(0.12), radius: 4, x: 0, y: 2)
        .accessibilityHidden(true)
    }
}

struct DSChoreAssetImage: View {
    let assetName: String

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .scaleEffect(DSChoreIconFraming.contentScale(for: assetName))
            .clipped()
    }
}

enum DSChoreIconFraming {
    static func contentScale(for assetName: String) -> CGFloat {
        if assetName == "chore_premium_walk_dog" {
            return 1.32
        }

        if assetName.hasPrefix("chore_premium_") {
            return 1.22
        }

        if assetName.hasPrefix("chore_core_") {
            return 1.24
        }

        if assetName.hasPrefix("chore_custom_") {
            return 1.12
        }

        return 1
    }
}

enum DSActivityRowPresentation {
    case standalone
    case grouped(isFirst: Bool, isLast: Bool)
}

struct DSActivityRow: View {
    let record: ChoreRecord
    var timeZoneIdentifier: String?
    var onQuickReaction: (() -> Void)?
    var onReaction: ((ChoreReaction) -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var isLoading = false
    var presentation: DSActivityRowPresentation = .standalone

    @AppStorage("didDiscoverChoreReactions") private var didDiscoverReactions = false
    @State private var isReactionPickerPresented = false
    @State private var isReactionHintPresented = false

    var body: some View {
        presentedContent
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if record.canDelete, let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Label("删除", systemImage: "trash.fill")
                    }
                }
                if record.canEdit, let onEdit {
                    Button(action: onEdit) {
                        Label("编辑", systemImage: "slider.horizontal.3")
                    }
                    .tint(DSColor.infoBlue)
                }
            }
            .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var presentedContent: some View {
        switch presentation {
        case .standalone:
            DSFloatingSurface(cornerRadius: 18, padding: 14, elevation: .secondary) {
                rowContent
            }
        case let .grouped(isFirst, isLast):
            rowContent
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
                .background(groupedBackground(isFirst: isFirst, isLast: isLast))
                .overlay(alignment: .bottom) {
                    if !isLast {
                        Rectangle()
                            .fill(DSColor.floatingDivider)
                            .frame(height: 0.7)
                            .padding(.leading, 60)
                            .padding(.trailing, 16)
                    }
                }
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 11) {
            DSAvatarView(
                avatarKey: record.avatarKey,
                fallbackText: record.memberName,
                size: 44,
                presentation: .flat
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("\(record.displayIdentity) · \(choreDisplayName)")
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text("\(record.actualMinutes) 分钟 · \(activityTimestamp)")
                        .lineLimit(1)

                    if record.syncState == .pending {
                        Label("待同步", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .semibold, design: .default))
                            .foregroundStyle(DSColor.infoBlue)
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundStyle(DSColor.floatingSecondaryText)

                if !record.likedBy.isEmpty {
                    HStack(spacing: 1) {
                        ForEach(Array(record.likedBy.prefix(3))) { liker in
                            DSReactionAvatarBadge(liker: liker)
                        }

                        if remainingLikeCount > 0 {
                            Text("+\(remainingLikeCount)")
                                .font(.system(size: 11, weight: .regular, design: .default))
                                .foregroundStyle(DSColor.floatingSecondaryText)
                                .padding(.leading, 8)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(record.likeCount) 人回应")
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                } else {
                    Color.clear
                        .frame(height: 18)
                        .accessibilityHidden(true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 2)

            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(record.points) 分")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(DSColor.floatingPrimaryText)
                    .monospacedDigit()
                    .lineLimit(1)

                HStack(spacing: 3) {
                    reactionControl

                    Text("\(record.likeCount)")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundStyle(DSColor.floatingSecondaryText)
                        .monospacedDigit()
                        .frame(minWidth: 10)
                }
                .opacity(isLoading ? 0.52 : 1)
            }
        }
        .foregroundStyle(DSColor.floatingPrimaryText)
    }

    private func groupedBackground(isFirst: Bool, isLast: Bool) -> some View {
        let shape = UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: isFirst ? 20 : 0,
                bottomLeading: isLast ? 20 : 0,
                bottomTrailing: isLast ? 20 : 0,
                topTrailing: isFirst ? 20 : 0
            ),
            style: .continuous
        )

        return shape
            .fill(DSColor.floatingSurface)
            .shadow(
                color: DSColor.shadow.opacity(isLast ? DSShadow.floatingSecondaryOpacity : 0),
                radius: isLast ? DSShadow.floatingSecondaryRadius : 0,
                x: 0,
                y: isLast ? DSShadow.floatingSecondaryYOffset : 0
            )
            .overlay(shape.stroke(DSColor.floatingStroke, lineWidth: 0.7))
    }

    private var choreDisplayName: String {
        let names = record.choreName
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return names.min(by: { $0.count < $1.count }) ?? record.choreName
    }

    private var activityTimestamp: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .autoupdatingCurrent
        formatter.dateFormat = "EEEE HH:mm"
        return formatter.string(from: record.createdAt).replacingOccurrences(of: "星期", with: "周")
    }

    private var remainingLikeCount: Int {
        max(0, record.likeCount - min(record.likedBy.count, 3))
    }

    private var selectedReaction: ChoreReaction? {
        record.myReaction ?? (record.likedByMe ? .like : nil)
    }

    private var reactionControl: some View {
        DSReactionIcon(reaction: selectedReaction ?? .like, size: 21, isMuted: selectedReaction == nil)
            .frame(width: 42, height: 42)
            .background {
                Circle()
                    .fill(selectedReaction == nil ? DSColor.floatingPageBackground : DSColor.yellow.opacity(0.9))
                    .frame(width: 34, height: 34)
            }
            .overlay {
                Circle()
                    .stroke(
                        selectedReaction == nil ? DSColor.subtleStroke : DSColor.yellow,
                        lineWidth: 1
                    )
                    .frame(width: 34, height: 34)
            }
            .contentShape(Circle())
            .opacity(isLoading ? 0.52 : 1)
            .allowsHitTesting(!isLoading && onQuickReaction != nil)
            .gesture(reactionGesture)
            .popover(isPresented: $isReactionPickerPresented, arrowEdge: .bottom) {
                DSReactionPickerBar(selectedReaction: selectedReaction) { reaction in
                    isReactionPickerPresented = false
                    onReaction?(reaction)
                }
                .presentationCompactAdaptation(.popover)
            }
            .overlay(alignment: .top) {
                if isReactionHintPresented {
                    Text("长按可以选回应")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DSColor.floatingPrimaryText)
                        .fixedSize()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(DSColor.floatingSurface)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
                        )
                        .offset(x: -42, y: -32)
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(selectedReaction == nil ? "回应" : "已回应：\(selectedReaction?.title ?? "")")
            .accessibilityHint("轻点快速点赞，长按选择其他回应")
            .accessibilityAction(named: "选择回应") {
                presentReactionPicker()
            }
    }

    private var reactionGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .exclusively(before: TapGesture())
            .onEnded { result in
                switch result {
                case .first(true):
                    presentReactionPicker()
                case .second:
                    onQuickReaction?()
                    presentReactionHintIfNeeded()
                default:
                    break
                }
            }
    }

    private func presentReactionPicker() {
        didDiscoverReactions = true
        isReactionHintPresented = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isReactionPickerPresented = true
    }

    private func presentReactionHintIfNeeded() {
        guard !didDiscoverReactions else { return }
        didDiscoverReactions = true
        withAnimation(.easeOut(duration: 0.18)) {
            isReactionHintPresented = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeIn(duration: 0.18)) {
                isReactionHintPresented = false
            }
        }
    }

}

private struct DSReactionAvatarBadge: View {
    let liker: ActivityLiker

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            DSAvatarView(
                avatarKey: liker.avatarKey,
                fallbackText: liker.displayName,
                size: 19,
                presentation: .flat
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            DSReactionIcon(reaction: liker.reaction, size: 13)
                .padding(1.5)
                .background {
                    Circle()
                        .fill(DSColor.floatingSurface)
                        .overlay(Circle().stroke(DSColor.floatingStroke, lineWidth: 0.6))
                }
                .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
        }
        .frame(width: 26, height: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(liker.displayName)回应了\(liker.reaction.title)")
    }
}

private struct DSReactionPickerBar: View {
    let selectedReaction: ChoreReaction?
    let onSelect: (ChoreReaction) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(ChoreReaction.allCases) { reaction in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    onSelect(reaction)
                } label: {
                    DSReactionIcon(reaction: reaction, size: 28)
                        .frame(width: 38, height: 38)
                        .background {
                            Circle()
                                .fill(selectedReaction == reaction ? DSColor.yellow.opacity(0.45) : Color.clear)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(reaction.title)
                .accessibilityAddTraits(selectedReaction == reaction ? .isSelected : [])
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(DSColor.subtleStroke.opacity(0.75), lineWidth: 0.8))
        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)
    }
}

struct DSReactionIcon: View {
    let reaction: ChoreReaction
    var size: CGFloat = 28
    var isMuted = false

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, canvasSize in
            context.scaleBy(x: canvasSize.width / 32, y: canvasSize.height / 32)
            draw(reaction, in: &context)
        }
        .frame(width: size, height: size)
        .opacity(isMuted ? 0.58 : 1)
        .accessibilityHidden(true)
    }

    private func draw(_ reaction: ChoreReaction, in context: inout GraphicsContext) {
        switch reaction {
        case .like:
            drawLike(in: &context)
        case .highFive:
            drawHighFive(in: &context)
        case .moonFace:
            drawMoonFace(in: &context)
        case .laughCry:
            drawLaughCry(in: &context)
        case .tease:
            drawTease(in: &context)
        }
    }

    private func drawLike(in context: inout GraphicsContext) {
        var hand = Path()
        hand.move(to: CGPoint(x: 8, y: 15))
        hand.addLine(to: CGPoint(x: 12, y: 15))
        hand.addLine(to: CGPoint(x: 16, y: 6))
        hand.addCurve(to: CGPoint(x: 19, y: 8), control1: CGPoint(x: 18, y: 5), control2: CGPoint(x: 20, y: 6))
        hand.addLine(to: CGPoint(x: 18, y: 13))
        hand.addLine(to: CGPoint(x: 25, y: 13))
        hand.addCurve(to: CGPoint(x: 27, y: 17), control1: CGPoint(x: 28, y: 13), control2: CGPoint(x: 28, y: 15))
        hand.addLine(to: CGPoint(x: 24, y: 26))
        hand.addCurve(to: CGPoint(x: 20, y: 28), control1: CGPoint(x: 24, y: 28), control2: CGPoint(x: 22, y: 28))
        hand.addLine(to: CGPoint(x: 12, y: 27))
        hand.addLine(to: CGPoint(x: 8, y: 25))
        hand.closeSubpath()
        fillAndStroke(hand, fill: Color(red: 1, green: 0.78, blue: 0.12), in: &context)

        let cuff = Path(roundedRect: CGRect(x: 3, y: 14, width: 7, height: 13), cornerRadius: 2)
        fillAndStroke(cuff, fill: Color(red: 0.23, green: 0.61, blue: 0.98), in: &context)
    }

    private func drawHighFive(in context: inout GraphicsContext) {
        var left = Path()
        left.move(to: CGPoint(x: 4, y: 27))
        left.addLine(to: CGPoint(x: 8, y: 13))
        left.addLine(to: CGPoint(x: 10, y: 5))
        left.addCurve(to: CGPoint(x: 13, y: 7), control1: CGPoint(x: 11, y: 3), control2: CGPoint(x: 14, y: 4))
        left.addLine(to: CGPoint(x: 13, y: 14))
        left.addLine(to: CGPoint(x: 17, y: 10))
        left.addCurve(to: CGPoint(x: 19, y: 13), control1: CGPoint(x: 20, y: 9), control2: CGPoint(x: 21, y: 11))
        left.addLine(to: CGPoint(x: 14, y: 21))
        left.addLine(to: CGPoint(x: 12, y: 28))
        left.closeSubpath()
        fillAndStroke(left, fill: Color(red: 1, green: 0.69, blue: 0.2), in: &context)

        var right = Path()
        right.move(to: CGPoint(x: 28, y: 27))
        right.addLine(to: CGPoint(x: 24, y: 13))
        right.addLine(to: CGPoint(x: 22, y: 5))
        right.addCurve(to: CGPoint(x: 19, y: 7), control1: CGPoint(x: 21, y: 3), control2: CGPoint(x: 18, y: 4))
        right.addLine(to: CGPoint(x: 19, y: 14))
        right.addLine(to: CGPoint(x: 15, y: 10))
        right.addCurve(to: CGPoint(x: 13, y: 13), control1: CGPoint(x: 12, y: 9), control2: CGPoint(x: 11, y: 11))
        right.addLine(to: CGPoint(x: 18, y: 21))
        right.addLine(to: CGPoint(x: 20, y: 28))
        right.closeSubpath()
        fillAndStroke(right, fill: Color(red: 0.98, green: 0.43, blue: 0.45), in: &context)
    }

    private func drawMoonFace(in context: inout GraphicsContext) {
        let face = Path(ellipseIn: CGRect(x: 3, y: 3, width: 26, height: 26))
        fillAndStroke(face, fill: Color(red: 0.12, green: 0.13, blue: 0.17), in: &context)
        drawEye(at: CGPoint(x: 11, y: 13), color: Color(red: 0.82, green: 0.83, blue: 0.86), in: &context)
        drawEye(at: CGPoint(x: 21, y: 13), color: Color(red: 0.82, green: 0.83, blue: 0.86), in: &context)
        var smile = Path()
        smile.move(to: CGPoint(x: 10, y: 21))
        smile.addCurve(to: CGPoint(x: 23, y: 19), control1: CGPoint(x: 15, y: 24), control2: CGPoint(x: 20, y: 23))
        context.stroke(smile, with: .color(Color.white.opacity(0.82)), style: strokeStyle(width: 1.8))
    }

    private func drawLaughCry(in context: inout GraphicsContext) {
        let face = Path(ellipseIn: CGRect(x: 4, y: 4, width: 24, height: 24))
        fillAndStroke(face, fill: Color(red: 1, green: 0.79, blue: 0.13), in: &context)
        drawHappyEye(from: CGPoint(x: 9, y: 13), to: CGPoint(x: 14, y: 11), in: &context)
        drawHappyEye(from: CGPoint(x: 18, y: 11), to: CGPoint(x: 23, y: 13), in: &context)
        let mouth = Path(roundedRect: CGRect(x: 10, y: 17, width: 12, height: 7), cornerRadius: 4)
        fillAndStroke(mouth, fill: Color(red: 0.18, green: 0.12, blue: 0.13), in: &context, lineWidth: 1.5)
        drawTear(at: CGPoint(x: 4, y: 18), mirrored: false, in: &context)
        drawTear(at: CGPoint(x: 28, y: 18), mirrored: true, in: &context)
    }

    private func drawTease(in context: inout GraphicsContext) {
        let face = Path(ellipseIn: CGRect(x: 4, y: 4, width: 24, height: 24))
        fillAndStroke(face, fill: Color(red: 1, green: 0.45, blue: 0.55), in: &context)
        drawEye(at: CGPoint(x: 11, y: 14), color: .black, in: &context)
        var wink = Path()
        wink.move(to: CGPoint(x: 18, y: 14))
        wink.addCurve(to: CGPoint(x: 24, y: 13), control1: CGPoint(x: 20, y: 11), control2: CGPoint(x: 22, y: 11))
        context.stroke(wink, with: .color(.black), style: strokeStyle(width: 2.1))
        var mouth = Path()
        mouth.move(to: CGPoint(x: 10, y: 20))
        mouth.addCurve(to: CGPoint(x: 22, y: 20), control1: CGPoint(x: 14, y: 24), control2: CGPoint(x: 19, y: 24))
        context.stroke(mouth, with: .color(.black), style: strokeStyle(width: 2))
        let tongue = Path(ellipseIn: CGRect(x: 14, y: 21, width: 7, height: 6))
        fillAndStroke(tongue, fill: Color(red: 0.91, green: 0.16, blue: 0.35), in: &context, lineWidth: 1.2)
    }

    private func fillAndStroke(
        _ path: Path,
        fill: Color,
        in context: inout GraphicsContext,
        lineWidth: CGFloat = 2
    ) {
        context.fill(path, with: .color(fill))
        context.stroke(path, with: .color(Color(red: 0.08, green: 0.08, blue: 0.07)), style: strokeStyle(width: lineWidth))
    }

    private func drawEye(at point: CGPoint, color: Color, in context: inout GraphicsContext) {
        let eye = Path(ellipseIn: CGRect(x: point.x - 1.5, y: point.y - 2, width: 3, height: 4))
        context.fill(eye, with: .color(color))
    }

    private func drawHappyEye(from start: CGPoint, to end: CGPoint, in context: inout GraphicsContext) {
        var eye = Path()
        eye.move(to: start)
        eye.addCurve(
            to: end,
            control1: CGPoint(x: start.x + 1.5, y: start.y - 2),
            control2: CGPoint(x: end.x - 1.5, y: end.y - 2)
        )
        context.stroke(eye, with: .color(.black), style: strokeStyle(width: 1.8))
    }

    private func drawTear(at point: CGPoint, mirrored: Bool, in context: inout GraphicsContext) {
        var tear = Path()
        tear.move(to: CGPoint(x: point.x, y: point.y - 3))
        tear.addCurve(
            to: CGPoint(x: point.x, y: point.y + 5),
            control1: CGPoint(x: point.x + (mirrored ? 5 : -5), y: point.y),
            control2: CGPoint(x: point.x + (mirrored ? 3 : -3), y: point.y + 5)
        )
        tear.addCurve(
            to: CGPoint(x: point.x, y: point.y - 3),
            control1: CGPoint(x: point.x + (mirrored ? -2 : 2), y: point.y + 5),
            control2: CGPoint(x: point.x + (mirrored ? -2 : 2), y: point.y)
        )
        fillAndStroke(tear, fill: Color(red: 0.25, green: 0.67, blue: 1), in: &context, lineWidth: 1.2)
    }

    private func strokeStyle(width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }
}

struct DSAvatarView: View {
    let avatarKey: String?
    let fallbackText: String
    var size: CGFloat = 48
    var presentation: AvatarPresentation = .sticker

    var body: some View {
        AvatarView(
            avatarKey: avatarKey,
            fallbackText: fallbackText,
            size: size,
            presentation: presentation
        )
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
    var fill: Color = DSColor.pureSurface
    var avatarKey: String?
    var actionTitle: String?
    var actionSystemImage: String = "plus.circle"
    var action: (() -> Void)?

    var body: some View {
        DSQuietCard(fill: fill, cornerRadius: 22, padding: 24) {
            VStack(spacing: 12) {
                if let avatarKey {
                    AvatarView(
                        avatarKey: avatarKey,
                        fallbackText: title,
                        size: 96,
                        presentation: .quiet
                    )
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(DSColor.infoBlue)
                        .frame(width: 76, height: 76)
                        .background(DSColor.choreBlueSurface)
                        .clipShape(Circle())
                }

                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(DSColor.mutedInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionTitle, let action {
                    Button(action: action) {
                        Label(actionTitle, systemImage: actionSystemImage)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(DSColor.ink)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(DSColor.yellow)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: DSColor.yellow.opacity(0.22), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    .accessibilityIdentifier("empty-state-primary-action")
                }
            }
            .foregroundStyle(DSColor.ink)
            .frame(maxWidth: .infinity)
        }
    }
}

struct DSLoadingStateView: View {
    let message: String

    var body: some View {
        DSQuietCard(fill: DSColor.choreBlueSurface) {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(DSColor.infoBlue)
                Text(message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(DSColor.mutedInk)
            }
        }
    }
}

struct DSErrorBanner: View {
    let message: String

    var body: some View {
        DSQuietCard(fill: DSColor.redSoft) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(DSColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DSRequestFailureView: View {
    let title: String
    let message: String
    let retryAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 31, weight: .regular))
                .foregroundStyle(DSColor.coral)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(DSColor.ink)
                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(DSColor.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Button("重试", action: retryAction)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.red)
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("request-failure-retry")
        }
        .padding(16)
        .background(DSColor.redSoft.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DSColor.coral.opacity(0.55), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

struct DSOfflineStatusView: View {
    let lastUpdatedAt: Date?
    var pendingUploadCount = 0

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 27, weight: .regular))
                .foregroundStyle(DSColor.infoBlue)
                .accessibilityHidden(true)

            Text(statusMessage)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(DSColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Text(updateLabel)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(DSColor.mutedInk.opacity(0.72))
                .lineLimit(1)
                .monospacedDigit()
        }
        .padding(16)
        .background(DSColor.choreBlueSurface.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DSColor.infoBlue.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var updateLabel: String {
        guard let lastUpdatedAt else { return "尚未同步" }
        return lastUpdatedAt.formatted(date: .omitted, time: .shortened) + " 更新"
    }

    private var statusMessage: String {
        guard pendingUploadCount > 0 else {
            return "当前离线，正在展示上次更新的数据"
        }
        return "当前离线，\(pendingUploadCount) 条记录将在联网后同步"
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
