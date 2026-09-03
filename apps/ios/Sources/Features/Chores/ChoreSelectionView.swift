import SwiftUI
import UIKit

struct ChoreSelectionView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @EnvironmentObject private var dragCoordinator: CommonChoreDragCoordinator
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var copySeed = Int.random(in: 0..<10_000)
    @State private var choreForDurationPicker: ChoreItem?
    @State private var showsRoutineEditor = false
    @State private var customEditorContext: CustomChoreEditorContext?
    @State private var pendingCustomEditorContext: CustomChoreEditorContext?
    @State private var premiumUpgradeTrigger: PremiumUpgradeTrigger?
    @State private var dragState = CommonChoreDragState.idle
    @State private var isLayoutEditing = false
    @State private var userHasScrolled = false
    @State private var bottomPickerArmed = true
    @State private var bottomSentinelMinY = CGFloat.greatestFiniteMagnitude
    @State private var scrollViewportHeight: CGFloat = 0
    @State private var bottomPullStartedAtBottom = false
    @State private var bottomOverscrollDistance: CGFloat = 0
    @State private var scrollResetID = UUID()
    @State private var commonChoreFrames: [String: CGRect] = [:]
    @State private var commonChoreContainerGlobalFrame: CGRect = .zero
    @State private var dragAnchorOffset: CGPoint = .zero
    @State private var lastReorderTargetID: String?
    @State private var lastReorderLocation: CGPoint?
    @State private var lastReorderAt = Date.distantPast
    @State private var dragStartSnapshot: [String] = []

    private static let commonChoreCoordinateSpace = "common-chore-grid"
    private static let choreScrollCoordinateSpace = "chore-scroll"
    private static let reorderHoldDuration = 0.80
    private static let reorderMaximumMovement: CGFloat = 12
    // Require the reveal sentinel to be almost fully visible so a normal scroll
    // near the last row does not unexpectedly open the chore library.
    private static let bottomTriggerThreshold: CGFloat = -60
    private static let bottomRearmDistance: CGFloat = 180
    private static let bottomPullActivationDistance: CGFloat = 44
    private static let reorderCooldown: TimeInterval = 0.08
    private static let reorderTravelThreshold: CGFloat = 18

    private var draggingGridItemID: String? { dragState.itemID }
    private var dragLocation: CGPoint? { dragState.location }
    private var isReordering: Bool { dragState.isActive }
    private var isTrashTargeted: Bool { dragState.isTrashTargeted }
    private var isPresentingModal: Bool {
        choreForDurationPicker != nil
            || showsRoutineEditor
            || customEditorContext != nil
            || premiumUpgradeTrigger != nil
    }

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ChoreScrollActivityObserver { activity in
                        userHasScrolled = true
                        bottomPullStartedAtBottom = activity.startedAtBottom
                        bottomOverscrollDistance = activity.bottomOverscroll
                        evaluateBottomSentinel(
                            userDidScroll: true,
                            pullStartedAtBottom: activity.startedAtBottom,
                            overscrollDistance: activity.bottomOverscroll
                        )
                    }
                    .frame(width: 0, height: 0)
                    pageHeader
                    statusBanner
                    commonChoresSection
                    bottomSentinel
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 108)
                .frame(
                    minHeight: max(0, scrollViewportHeight + 96),
                    alignment: .top
                )
            }
            .coordinateSpace(name: Self.choreScrollCoordinateSpace)
            .background {
                ZStack {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ChoreScrollViewportPreferenceKey.self,
                            value: proxy.size.height
                        )
                    }
                }
            }
            .id(scrollResetID)
            .scrollDisabled(isLayoutEditing)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            resetBottomPickerTracking()
            resetTransientInteractionState()
            viewModel.prepareCommonChoreGrid()
        }
        .onDisappear {
            resetTransientInteractionState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                resetTransientInteractionState()
            }
        }
        .onChange(of: viewModel.commonChoreGridItemIDs) { _, itemIDs in
            if let activeItemID = dragState.itemID, !itemIDs.contains(activeItemID) {
                resetTransientInteractionState()
            }
        }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            if isLoading {
                resetTransientInteractionState()
            }
        }
        .onPreferenceChange(ChoreScrollViewportPreferenceKey.self) { height in
            scrollViewportHeight = height
            evaluateBottomSentinel()
        }
        .onPreferenceChange(ChoreBottomSentinelPreferenceKey.self) { minY in
            bottomSentinelMinY = minY
            evaluateBottomSentinel()
        }
        .onChange(of: dragCoordinator.isActive) { _, isActive in
            if !isActive {
                isLayoutEditing = false
                dragState = .idle
            }
        }
        .sheet(item: $choreForDurationPicker, onDismiss: resetAfterModal) { chore in
            ChoreDurationPickerSheet(
                chore: chore,
                initialMinutes: viewModel.getDefaultDuration(for: chore),
                onCancel: {
                    choreForDurationPicker = nil
                },
                onConfirm: { actualMinutes, calculatedPoints, pointsMultiplier in
                    viewModel.saveLastDuration(choreId: chore.id, minutes: actualMinutes)
                    viewModel.record(
                        chore,
                        actualMinutes: actualMinutes,
                        calculatedPoints: calculatedPoints,
                        pointsMultiplier: pointsMultiplier
                    )
                    choreForDurationPicker = nil
                }
            )
            .environmentObject(viewModel)
            .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.fraction(0.70), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsRoutineEditor, onDismiss: resetAfterRoutineEditor) {
            ChoreRoutineEditorView(isInitialSetup: false)
                .environmentObject(viewModel)
        }
        .sheet(item: $customEditorContext, onDismiss: resetAfterCustomEditor) { context in
            CustomChoreEditorSheet(chore: context.chore) { draft in
                let saved = await viewModel.saveCustomChore(draft, editing: context.chore)
                if saved {
                    customEditorContext = nil
                    viewModel.prepareCommonChoreGrid()
                }
                return saved
            } onCancel: {
                customEditorContext = nil
            }
            .environmentObject(viewModel)
            .presentationDetents([.large])
        }
        .sheet(item: $premiumUpgradeTrigger, onDismiss: resetAfterModal) { trigger in
            premiumUpgradeSheet(for: trigger)
        }
        .onAppear {
            copySeed = Int.random(in: 0..<10_000)
        }
    }

    private var pageHeader: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("记一下")
                    .font(DSFont.functionalPageTitle)
                    .foregroundStyle(DSColor.ink)

                Text(RotatingCopy.value(from: RotatingCopy.choreSelection, seed: copySeed))
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundStyle(DSColor.mutedInk)

                if viewModel.canChooseChoreLayoutMode {
                    Toggle(isOn: Binding(
                        get: { viewModel.followsFamilyChoreLayout },
                        set: { viewModel.setFollowsFamilyChoreLayout($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("跟随一家之主布局")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DSColor.ink)
                            Text(viewModel.followsFamilyChoreLayout ? "一家之主更新后会同步" : "只显示我的常用家务")
                                .font(.caption)
                                .foregroundStyle(DSColor.mutedInk)
                        }
                    }
                    .tint(DSColor.yellow)
                    .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var commonChoresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("常用家务")
                    .font(DSFont.functionalSectionTitle)
                    .foregroundStyle(DSColor.ink)
                Spacer()
                Text("\(commonGridItems.count) 项")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DSColor.mutedInk)
            }

            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(commonGridItems) { item in
                    commonGridCard(item)
                }
            }
        }
        .coordinateSpace(name: Self.commonChoreCoordinateSpace)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: CommonChoreContainerFramePreferenceKey.self,
                    value: proxy.frame(in: .global)
                )
            }
        }
        .onPreferenceChange(CommonChoreFramePreferenceKey.self) { frames in
            commonChoreFrames = frames
        }
        .onPreferenceChange(CommonChoreContainerFramePreferenceKey.self) { frame in
            commonChoreContainerGlobalFrame = frame
        }
        .overlay(alignment: .topLeading) {
            floatingDragCard
        }
    }

    @ViewBuilder
    private func commonGridCard(_ item: CommonChoreGridItem) -> some View {
        let dragShape = RoundedRectangle(
            cornerRadius: DSCornerRadius.smallCard,
            style: .continuous
        )

        gridCardContent(item)
            .contentShape(.interaction, dragShape)
            .scaleEffect(draggingGridItemID == item.id ? 1.035 : (isReordering ? 0.985 : 1))
            .opacity(draggingGridItemID == item.id ? 0.16 : 1)
            .animation(
                draggingGridItemID == item.id ? nil : .easeOut(duration: 0.12),
                value: isReordering
            )
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: CommonChoreFramePreferenceKey.self,
                        value: [
                            item.id: proxy.frame(in: .named(Self.commonChoreCoordinateSpace)),
                        ]
                    )
                }
            }
            .overlay {
                GeometryReader { proxy in
                    ChoreCardInteractionView(
                        isEditing: isLayoutEditing,
                        holdDuration: Self.reorderHoldDuration,
                        holdMovementLimit: Self.reorderMaximumMovement,
                        editingDragThreshold: 7,
                        frameInGrid: proxy.frame(in: .named(Self.commonChoreCoordinateSpace)),
                        onTap: {
                            guard !viewModel.isLoading else { return }
                            if isLayoutEditing {
                                exitLayoutEditing()
                            } else {
                                open(item)
                            }
                        },
                        onLayoutBegan: { location in
                            guard enterLayoutEditing(for: item.id) else { return }
                            beginDragging(
                                item.id,
                                location: location,
                                allowDuringLayoutEntry: true
                            )
                        },
                        onDragChanged: { location in
                            guard !viewModel.isLoading, !isPresentingModal else { return }
                            if draggingGridItemID == nil {
                                beginDragging(item.id, location: location)
                            }
                            updateReordering(itemID: item.id, location: location)
                        },
                        onDragEnded: { location in
                            guard draggingGridItemID == item.id else {
                                exitLayoutEditing()
                                return
                            }
                            updateReordering(itemID: item.id, location: location)
                            completeReordering(itemID: item.id)
                        },
                        onDragCancelled: {
                            exitLayoutEditing()
                        }
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .accessibilityLabel(isLayoutEditing ? "布局编辑中的\(item.accessibilityName)" : item.accessibilityName)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                guard !viewModel.isLoading else { return }
                if isLayoutEditing {
                    exitLayoutEditing()
                } else {
                    open(item)
                }
            }
    }

    @ViewBuilder
    private var floatingDragCard: some View {
        if let itemID = draggingGridItemID,
           let item = commonGridItems.first(where: { $0.id == itemID }),
           let location = dragLocation,
           let frame = commonChoreFrames[itemID]
        {
            gridCardContent(item)
                .frame(width: frame.width, height: frame.height)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: DSCornerRadius.smallCard,
                        style: .continuous
                    )
                )
                .shadow(color: DSColor.shadow.opacity(0.16), radius: 14, x: 0, y: 8)
                .scaleEffect(1.03)
                .position(location)
                .allowsHitTesting(false)
                .zIndex(20)
        }
    }

    @ViewBuilder
    private func gridCardContent(_ item: CommonChoreGridItem) -> some View {
        switch item {
        case let .chore(chore):
            DSChoreCard(
                chore: chore,
                showsPinnedBadge: viewModel.isChorePinned(chore)
            )
        case let .customSlot(slot, chore):
            if let chore {
                DSChoreCard(chore: chore)
            } else {
                DSCustomChoreSlotCard(slot: slot)
            }
        }
    }

    private var commonGridItems: [CommonChoreGridItem] {
        let choresByID = Dictionary(uniqueKeysWithValues: viewModel.displayedChores.map { ($0.id, $0) })

        return viewModel.commonChoreGridItemIDs.compactMap { itemID in
            if let slot = viewModel.customChoreSlot(forGridItemID: itemID) {
                return .customSlot(slot: slot, chore: viewModel.customChore(forSlot: slot))
            }
            guard let chore = choresByID[itemID] else { return nil }
            return .chore(chore)
        }
    }

    private var bottomSentinel: some View {
        Color.clear
            .frame(height: 72)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ChoreBottomSentinelPreferenceKey.self,
                        value: proxy.frame(in: .named(Self.choreScrollCoordinateSpace)).minY
                    )
                }
            }
            .accessibilityHidden(true)
    }

    private func evaluateBottomSentinel(
        userDidScroll: Bool = false,
        pullStartedAtBottom: Bool? = nil,
        overscrollDistance: CGFloat? = nil
    ) {
        guard bottomSentinelMinY.isFinite,
              scrollViewportHeight > 0
        else { return }

        let distanceToViewportBottom = bottomSentinelMinY - scrollViewportHeight
        if distanceToViewportBottom > Self.bottomRearmDistance {
            bottomPickerArmed = true
        }

        guard ChoreLibraryRevealPolicy.shouldOpen(
            distanceToBottom: distanceToViewportBottom,
            threshold: Self.bottomTriggerThreshold,
            userHasScrolled: userHasScrolled || userDidScroll,
            isArmed: bottomPickerArmed,
            pullStartedAtBottom: pullStartedAtBottom ?? bottomPullStartedAtBottom,
            overscrollDistance: overscrollDistance ?? bottomOverscrollDistance,
            minimumPullDistance: Self.bottomPullActivationDistance
        ),
              !isLayoutEditing,
              !isReordering,
              draggingGridItemID == nil,
              !isPresentingModal,
              !viewModel.isLoading
        else { return }

        bottomPickerArmed = false
        DispatchQueue.main.async {
            guard !self.isLayoutEditing,
                  !self.isReordering,
                  !self.isPresentingModal,
                  !self.viewModel.isLoading
            else { return }

            guard self.viewModel.canEditCommonChoreLayout else {
                self.handleLayoutEditUnavailable()
                return
            }
            self.openRoutineEditor()
        }
    }

    private func open(_ item: CommonChoreGridItem) {
        resetTransientInteractionState()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        switch item {
        case let .chore(chore):
            choreForDurationPicker = chore
        case let .customSlot(slot, chore):
            if let chore {
                choreForDurationPicker = chore
            } else {
                let context = CustomChoreEditorContext(id: "custom-slot-\(slot)", chore: nil)
                if viewModel.hasPremiumAccess {
                    customEditorContext = context
                } else {
                    pendingCustomEditorContext = context
                    requestPremiumUpgrade(for: .customChore)
                }
            }
        }
    }

    @discardableResult
    private func enterLayoutEditing(for itemID: String) -> Bool {
        guard !isPresentingModal, !viewModel.isLoading else { return false }
        guard viewModel.canEditCommonChoreLayout else {
            handleLayoutEditUnavailable()
            return false
        }
        guard !isLayoutEditing else { return true }
        isLayoutEditing = true
        dragState = .idle
        dragCoordinator.begin()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return true
    }

    private func beginDragging(
        _ itemID: String,
        location: CGPoint,
        allowDuringLayoutEntry: Bool = false
    ) {
        guard (isLayoutEditing || allowDuringLayoutEntry),
              viewModel.canEditCommonChoreLayout,
              !isPresentingModal,
              !viewModel.isLoading
        else { return }
        guard draggingGridItemID == nil else { return }
        dragStartSnapshot = viewModel.commonChoreGridItemIDs
        lastReorderTargetID = nil
        lastReorderLocation = nil
        if let frame = commonChoreFrames[itemID] {
            dragAnchorOffset = CGPoint(
                x: location.x - frame.minX,
                y: location.y - frame.minY
            )
            dragState = CommonChoreDragState(
                itemID: itemID,
                location: CGPoint(
                    x: location.x - dragAnchorOffset.x + frame.width / 2,
                    y: location.y - dragAnchorOffset.y + frame.height / 2
                ),
                isTrashTargeted: false
            )
            return
        }

        dragAnchorOffset = .zero
        dragState = CommonChoreDragState(
            itemID: itemID,
            location: location,
            isTrashTargeted: false
        )
    }

    private func updateReordering(itemID: String, location: CGPoint) {
        guard draggingGridItemID == itemID else { return }
        let centeredLocation: CGPoint
        if let frame = commonChoreFrames[itemID] {
            centeredLocation = CGPoint(
                x: location.x - dragAnchorOffset.x + frame.width / 2,
                y: location.y - dragAnchorOffset.y + frame.height / 2
            )
        } else {
            centeredLocation = location
        }
        dragState.location = centeredLocation

        let dragCenter = dragState.location ?? location
        let globalLocation = CGPoint(
            x: commonChoreContainerGlobalFrame.minX + dragCenter.x,
            y: commonChoreContainerGlobalFrame.minY + dragCenter.y
        )
        let trashDropFrame = dragCoordinator.trashFrame.insetBy(dx: -12, dy: -20)
        let targetsTrash = dragCoordinator.trashFrame != .zero
            && trashDropFrame.contains(globalLocation)
        if targetsTrash != isTrashTargeted {
            dragState.isTrashTargeted = targetsTrash
            dragCoordinator.isTrashTargeted = targetsTrash
            UIImpactFeedbackGenerator(style: targetsTrash ? .rigid : .light).impactOccurred()
        }
        guard !targetsTrash else { return }

        guard Date().timeIntervalSince(lastReorderAt) >= Self.reorderCooldown,
              let draggedCenter = dragState.location,
              let targetID = reorderTargetID(
                  excluding: itemID,
                  draggedCenter: draggedCenter
              )
        else {
            return
        }

        if let lastReorderLocation,
           distanceSquared(lastReorderLocation, dragCenter)
            < Self.reorderTravelThreshold * Self.reorderTravelThreshold
        {
            return
        }

        withAnimation(.spring(response: 0.20, dampingFraction: 0.88)) {
            if viewModel.moveCommonChoreGridItem(itemID, to: targetID, persist: false) {
                lastReorderTargetID = targetID
                lastReorderLocation = dragCenter
                lastReorderAt = Date()
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
    }

    private func reorderTargetID(
        excluding itemID: String,
        draggedCenter: CGPoint
    ) -> String? {
        commonChoreFrames
            .filter { id, frame in
                guard id != itemID else { return false }
                let activationArea = frame.insetBy(
                    dx: frame.width * 0.22,
                    dy: frame.height * 0.22
                )
                return activationArea.contains(draggedCenter)
            }
            .min { lhs, rhs in
                let lhsCenter = CGPoint(x: lhs.value.midX, y: lhs.value.midY)
                let rhsCenter = CGPoint(x: rhs.value.midX, y: rhs.value.midY)
                return distanceSquared(lhsCenter, draggedCenter)
                    < distanceSquared(rhsCenter, draggedCenter)
            }?.key
    }

    private func distanceSquared(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    private func completeReordering(itemID: String) {
        guard draggingGridItemID == itemID else {
            exitLayoutEditing()
            return
        }

        let shouldRemove = isTrashTargeted
        let snapshot = dragStartSnapshot
        let didChangeOrder = snapshot != viewModel.commonChoreGridItemIDs
        exitLayoutEditing()

        Task {
            if shouldRemove {
                let removed = await viewModel.removeCommonChoreGridItem(itemID)
                UINotificationFeedbackGenerator().notificationOccurred(removed ? .success : .error)
            } else if didChangeOrder {
                let saved = await viewModel.persistCommonChoreGridLayout()
                if !saved, !snapshot.isEmpty {
                    viewModel.restoreCommonChoreGridOrder(snapshot)
                }
            }
        }

    }

    private func finishReordering() {
        dragState = .idle
        dragAnchorOffset = .zero
        lastReorderTargetID = nil
        lastReorderLocation = nil
        lastReorderAt = .distantPast
        dragStartSnapshot = []
        dragCoordinator.isTrashTargeted = false
    }

    private func exitLayoutEditing() {
        finishReordering()
        isLayoutEditing = false
        dragCoordinator.end()
    }

    private func resetTransientInteractionState() {
        exitLayoutEditing()
    }

    private func resetAfterModal() {
        resetTransientInteractionState()
    }

    private func resetAfterCustomEditor() {
        resetTransientInteractionState()
        viewModel.prepareCommonChoreGrid()
    }

    private func resetAfterRoutineEditor() {
        resetTransientInteractionState()
        viewModel.prepareCommonChoreGrid()
        resetBottomPickerTracking()
        scrollResetID = UUID()
    }

    private func resetBottomPickerTracking() {
        userHasScrolled = false
        bottomPickerArmed = true
        bottomSentinelMinY = .greatestFiniteMagnitude
        bottomPullStartedAtBottom = false
        bottomOverscrollDistance = 0
    }

    private func requestPremiumUpgrade(for trigger: PremiumUpgradeTrigger) {
        resetTransientInteractionState()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        premiumUpgradeTrigger = trigger
    }

    private func handleLayoutEditUnavailable() {
        if viewModel.canChooseChoreLayoutMode && viewModel.followsFamilyChoreLayout {
            viewModel.errorMessage = "当前正在跟随一家之主布局，请先关闭开关再编辑。"
        } else {
            requestPremiumUpgrade(for: .personalLayout)
        }
    }

    private func openRoutineEditor() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        exitLayoutEditing()
        showsRoutineEditor = true
    }

    private func openRoutineEditorAfterUpgrade() {
        premiumUpgradeTrigger = nil
        DispatchQueue.main.async {
            openRoutineEditor()
        }
    }

    private func continueWithFreeCustomSlot() {
        let context = pendingCustomEditorContext
        pendingCustomEditorContext = nil
        premiumUpgradeTrigger = nil
        resetTransientInteractionState()
        DispatchQueue.main.async {
            customEditorContext = context
        }
    }

    private func openCustomEditorAfterUpgrade() {
        continueWithFreeCustomSlot()
    }

    private func handlePremiumUnlocked(_ trigger: PremiumUpgradeTrigger) {
        switch trigger {
        case .customChore:
            openCustomEditorAfterUpgrade()
        case .personalLayout:
            openRoutineEditorAfterUpgrade()
        case .commonLimit, .profile, .pointsMultiplier:
            break
        }
    }

    private func premiumUpgradeSheet(for trigger: PremiumUpgradeTrigger) -> some View {
        let canContinueFree = trigger == .customChore
            && viewModel.isCurrentUserOwner
            && viewModel.availableCustomChoreSlots > 0
        let continueAction: (() -> Void)? = canContinueFree
            ? { continueWithFreeCustomSlot() }
            : nil
        let unlockedAction: () -> Void = { handlePremiumUnlocked(trigger) }

        return PremiumUpgradeSheet(
            trigger: trigger,
            onContinueFree: continueAction,
            onUnlocked: unlockedAction
        )
        .environmentObject(viewModel)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var gridColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }

        return [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ]
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

private struct ChoreCardInteractionView: UIViewRepresentable {
    let isEditing: Bool
    let holdDuration: TimeInterval
    let holdMovementLimit: CGFloat
    let editingDragThreshold: CGFloat
    let frameInGrid: CGRect
    let onTap: () -> Void
    let onLayoutBegan: (CGPoint) -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void
    let onDragCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ChoreCardInteractionHostView {
        let view = ChoreCardInteractionHostView()
        context.coordinator.install(
            on: view,
            holdDuration: holdDuration,
            holdMovementLimit: holdMovementLimit,
            editingDragThreshold: editingDragThreshold
        )
        return view
    }

    func updateUIView(_ uiView: ChoreCardInteractionHostView, context: Context) {
        context.coordinator.update(
            isEditing: isEditing,
            frameInGrid: frameInGrid,
            onTap: onTap,
            onLayoutBegan: onLayoutBegan,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded,
            onDragCancelled: onDragCancelled
        )
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var hostView: UIView?
        private var isEditing = false
        private var frameInGrid = CGRect.zero
        private var longPressOwnsDrag = false
        private var onTap: (() -> Void)?
        private var onLayoutBegan: ((CGPoint) -> Void)?
        private var onDragChanged: ((CGPoint) -> Void)?
        private var onDragEnded: ((CGPoint) -> Void)?
        private var onDragCancelled: (() -> Void)?

        private lazy var tapRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap(_:))
        )
        private lazy var longPressRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        private lazy var panRecognizer = UIPanGestureRecognizer(
            target: self,
            action: #selector(handlePan(_:))
        )

        func install(
            on view: UIView,
            holdDuration: TimeInterval,
            holdMovementLimit: CGFloat,
            editingDragThreshold: CGFloat
        ) {
            hostView = view

            tapRecognizer.cancelsTouchesInView = false
            longPressRecognizer.minimumPressDuration = holdDuration
            longPressRecognizer.allowableMovement = holdMovementLimit
            longPressRecognizer.cancelsTouchesInView = true
            panRecognizer.minimumNumberOfTouches = 1
            panRecognizer.maximumNumberOfTouches = 1
            _ = editingDragThreshold

            tapRecognizer.delegate = self
            longPressRecognizer.delegate = self
            panRecognizer.delegate = self
            tapRecognizer.require(toFail: longPressRecognizer)
            tapRecognizer.require(toFail: panRecognizer)

            view.addGestureRecognizer(tapRecognizer)
            view.addGestureRecognizer(longPressRecognizer)
            view.addGestureRecognizer(panRecognizer)
            panRecognizer.isEnabled = false
        }

        func update(
            isEditing: Bool,
            frameInGrid: CGRect,
            onTap: @escaping () -> Void,
            onLayoutBegan: @escaping (CGPoint) -> Void,
            onDragChanged: @escaping (CGPoint) -> Void,
            onDragEnded: @escaping (CGPoint) -> Void,
            onDragCancelled: @escaping () -> Void
        ) {
            self.isEditing = isEditing
            self.frameInGrid = frameInGrid
            self.onTap = onTap
            self.onLayoutBegan = onLayoutBegan
            self.onDragChanged = onDragChanged
            self.onDragEnded = onDragEnded
            self.onDragCancelled = onDragCancelled

            if panRecognizer.isEnabled != isEditing {
                panRecognizer.isEnabled = isEditing
            }
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            onTap?()
        }

        @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            let location = gridLocation(recognizer.location(in: hostView))
            switch recognizer.state {
            case .began:
                guard !isEditing else { return }
                longPressOwnsDrag = true
                onLayoutBegan?(location)
                onDragChanged?(location)
            case .changed:
                guard longPressOwnsDrag else { return }
                onDragChanged?(location)
            case .ended:
                guard longPressOwnsDrag else { return }
                longPressOwnsDrag = false
                onDragEnded?(location)
            case .cancelled, .failed:
                guard longPressOwnsDrag else { return }
                longPressOwnsDrag = false
                onDragCancelled?()
            default:
                break
            }
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard isEditing else { return }
            let location = gridLocation(recognizer.location(in: hostView))
            switch recognizer.state {
            case .began, .changed:
                onDragChanged?(location)
            case .ended:
                onDragEnded?(location)
            case .cancelled, .failed:
                onDragCancelled?()
            default:
                break
            }
        }

        private func gridLocation(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: frameInGrid.minX + point.x,
                y: frameInGrid.minY + point.y
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }
    }
}

private final class ChoreCardInteractionHostView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct CommonChoreDragState: Equatable {
    static let idle = CommonChoreDragState()

    var itemID: String?
    var location: CGPoint?
    var isTrashTargeted = false

    var isActive: Bool { itemID != nil }
}

@MainActor
final class CommonChoreDragCoordinator: ObservableObject {
    @Published private(set) var isActive = false
    @Published var isTrashTargeted = false
    var trashFrame: CGRect = .zero

    func begin() {
        isTrashTargeted = false
        isActive = true
    }

    func end() {
        isActive = false
        isTrashTargeted = false
        trashFrame = .zero
    }
}

struct CommonChoreRemovalTarget: View {
    let isTargeted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isTargeted ? "trash.fill" : "trash")
                .font(.system(size: 21, weight: .semibold))
                .scaleEffect(isTargeted ? 1.12 : 1)

            Text(isTargeted ? "松手移出常用" : "拖到这里移出常用")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(isTargeted ? Color.white : DSColor.coral)
        .frame(maxWidth: .infinity, minHeight: 64)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isTargeted ? DSColor.coral : DSColor.redSoft.opacity(0.98))
                .shadow(
                    color: DSColor.shadow.opacity(isTargeted ? 0.18 : 0.10),
                    radius: isTargeted ? 16 : 10,
                    x: 0,
                    y: 5
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isTargeted ? DSColor.coral : DSColor.coral.opacity(0.36),
                    lineWidth: 1
                )
        }
        .scaleEffect(isTargeted ? 1.015 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isTargeted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isTargeted ? "松手移出常用家务" : "拖到这里移出常用家务")
    }
}

private enum CommonChoreGridItem: Identifiable {
    case chore(ChoreItem)
    case customSlot(slot: Int, chore: ChoreItem?)

    var id: String {
        switch self {
        case let .chore(chore):
            chore.id
        case let .customSlot(slot, _):
            "custom-chore-slot-\(slot)"
        }
    }

    var accessibilityName: String {
        switch self {
        case let .chore(chore):
            return chore.name
        case let .customSlot(slot, chore):
            return chore?.name ?? "第 \(slot) 个自定义家务"
        }
    }
}

private struct DSCustomChoreSlotCard: View {
    let slot: Int

    private var accentColor: Color {
        slot.isMultiple(of: 2) ? DSColor.lavender : DSColor.sky
    }

    var body: some View {
        DSQuietCard(
            fill: accentColor.opacity(0.22),
            cornerRadius: DSCornerRadius.smallCard,
            padding: 8
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(DSColor.ink)
                        .frame(width: 56, height: 56)
                        .background(DSColor.pureSurface.opacity(0.86))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("自定义")
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)

                        Text("第 \(slot) 项")
                            .font(.system(size: 12))
                            .foregroundStyle(DSColor.mutedInk)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 7, height: 7)
                    Text("自定义家务")
                        .font(.system(size: 12))
                        .foregroundStyle(DSColor.mutedInk)
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(DSColor.ink)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第 \(slot) 个自定义家务")
    }
}

@MainActor
private struct CommonChoreFramePreferenceKey: PreferenceKey {
    nonisolated static let defaultValue: [String: CGRect] = [:]

    nonisolated static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private struct CommonChoreContainerFramePreferenceKey: PreferenceKey {
    nonisolated static let defaultValue: CGRect = .zero

    nonisolated static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

private struct ChoreScrollViewportPreferenceKey: PreferenceKey {
    nonisolated static let defaultValue: CGFloat = 0

    nonisolated static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}

private struct ChoreScrollActivity {
    let startedAtBottom: Bool
    let bottomOverscroll: CGFloat
}

private struct ChoreScrollActivityObserver: UIViewRepresentable {
    let onScroll: (ChoreScrollActivity) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        context.coordinator.onScroll = onScroll
        DispatchQueue.main.async {
            context.coordinator.attach(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onScroll = onScroll
        DispatchQueue.main.async {
            context.coordinator.attach(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var observedPanRecognizer: UIPanGestureRecognizer?
        weak var observedScrollView: UIScrollView?
        var onScroll: ((ChoreScrollActivity) -> Void)?
        private var gestureStartedAtBottom = false

        private static let bottomStartTolerance: CGFloat = 8

        func attach(from view: UIView) {
            guard observedPanRecognizer == nil else { return }

            var ancestor = view.superview
            while let current = ancestor, !(current is UIScrollView) {
                ancestor = current.superview
            }
            guard let scrollView = ancestor as? UIScrollView else { return }

            observedScrollView = scrollView
            observedPanRecognizer = scrollView.panGestureRecognizer
            scrollView.panGestureRecognizer.addTarget(
                self,
                action: #selector(handleScrollPan(_:))
            )
        }

        func detach() {
            observedPanRecognizer?.removeTarget(
                self,
                action: #selector(handleScrollPan(_:))
            )
            observedPanRecognizer = nil
            observedScrollView = nil
            gestureStartedAtBottom = false
        }

        @objc private func handleScrollPan(_ recognizer: UIPanGestureRecognizer) {
            guard let scrollView = observedScrollView else { return }

            let maximumOffset = max(
                -scrollView.adjustedContentInset.top,
                scrollView.contentSize.height
                    - scrollView.bounds.height
                    + scrollView.adjustedContentInset.bottom
            )

            if recognizer.state == .began {
                let remainingDistance = maximumOffset - scrollView.contentOffset.y
                gestureStartedAtBottom = remainingDistance <= Self.bottomStartTolerance
            }

            guard recognizer.state == .began || recognizer.state == .changed else {
                gestureStartedAtBottom = false
                onScroll?(
                    ChoreScrollActivity(
                        startedAtBottom: false,
                        bottomOverscroll: 0
                    )
                )
                return
            }

            onScroll?(
                ChoreScrollActivity(
                    startedAtBottom: gestureStartedAtBottom,
                    bottomOverscroll: max(0, scrollView.contentOffset.y - maximumOffset)
                )
            )
        }
    }
}

private struct ChoreBottomSentinelPreferenceKey: PreferenceKey {
    nonisolated static let defaultValue = CGFloat.greatestFiniteMagnitude

    nonisolated static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next.isFinite {
            value = next
        }
    }
}

enum ChoreLibraryRevealPolicy {
    static func shouldOpen(
        distanceToBottom: CGFloat,
        threshold: CGFloat,
        userHasScrolled: Bool,
        isArmed: Bool,
        pullStartedAtBottom: Bool,
        overscrollDistance: CGFloat,
        minimumPullDistance: CGFloat
    ) -> Bool {
        distanceToBottom <= threshold
            && userHasScrolled
            && isArmed
            && pullStartedAtBottom
            && overscrollDistance >= minimumPullDistance
    }
}

struct CommonChoreRemovalFramePreferenceKey: PreferenceKey {
    nonisolated static let defaultValue: CGRect = .zero

    nonisolated static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct ChoreRoutineEditorView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let isInitialSetup: Bool

    @State private var selectedIDs: [String] = []
    @State private var pinnedIDs: Set<String> = []
    @State private var didInitialize = false
    @State private var isSaving = false
    @State private var localMessage: String?
    @State private var customEditorContext: CustomChoreEditorContext?
    @State private var pendingCustomEditorContext: CustomChoreEditorContext?
    @State private var customChoreToDelete: ChoreItem?
    @State private var selectedTheme: ChoreTheme = .daily
    @State private var premiumUpgradeTrigger: PremiumUpgradeTrigger?

    var body: some View {
        ZStack {
            DSColor.quietBackground.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    themeHeader
                    themeTabs
                    selectionSummary
                    themedCatalogSection
                    customManagementSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle(isInitialSetup ? "选择常用家务" : "家务库")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isInitialSetup)
        .safeAreaInset(edge: .bottom) {
            saveBar
        }
        .task {
            guard !didInitialize else { return }
            selectedIDs = initialSelection
            pinnedIDs = viewModel.pinnedChoreIDs.intersection(Set(selectedIDs))
            normalizePinnedOrder()
            didInitialize = true
        }
        .sheet(item: $customEditorContext) { context in
            CustomChoreEditorSheet(chore: context.chore) { draft in
                let saved = await viewModel.saveCustomChore(draft, editing: context.chore)
                if saved {
                    customEditorContext = nil
                }
                return saved
            } onCancel: {
                customEditorContext = nil
            }
            .environmentObject(viewModel)
            .presentationDetents([.large])
        }
        .sheet(item: $premiumUpgradeTrigger) { trigger in
            premiumUpgradeSheet(for: trigger)
        }
        .alert(
            "移除自定义家务？",
            isPresented: Binding(
                get: { customChoreToDelete != nil },
                set: { if !$0 { customChoreToDelete = nil } }
            ),
            presenting: customChoreToDelete
        ) { chore in
            Button("取消", role: .cancel) { customChoreToDelete = nil }
            Button("移除", role: .destructive) {
                Task {
                    if await viewModel.archiveCustomChore(chore) {
                        selectedIDs.removeAll { $0 == chore.id }
                        pinnedIDs.remove(chore.id)
                        customChoreToDelete = nil
                    }
                }
            }
        } message: { chore in
            Text("「\(chore.name)」会从可选目录移除，历史记录和积分仍然保留。")
        }
    }

    private var themeHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isInitialSetup ? "先搭好你们家的常用区" : "重新挑选常用家务")
                .font(DSFont.functionalSectionTitle)
                .foregroundStyle(DSColor.ink)

            Text(viewModel.hasPremiumAccess
                ? "高级版常用家务不限数量，并可创建 10 项自定义家务。"
                : (viewModel.isGuestWorkspace
                    ? "先选最多 6 项家务，开始使用不需要登录。"
                    : "可少选，免费版最多 6 项；一家之主的设置会同步给全家。"))
                .font(.system(size: 13))
                .foregroundStyle(DSColor.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var themeTabs: some View {
        HStack(spacing: 8) {
            ForEach(ChoreTheme.allCases) { theme in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selectedTheme = theme
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: theme.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 16, height: 16)

                        Text(theme.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(DSColor.ink)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(
                        theme == selectedTheme
                            ? themeAccent(theme).opacity(0.9)
                            : DSColor.pureSurface
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                theme == selectedTheme
                                    ? DSColor.ink.opacity(0.48)
                                    : DSColor.subtleStroke,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(theme == selectedTheme ? .isSelected : [])
            }
        }
    }

    private var selectionSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: selectedIDs.isEmpty ? "hand.tap" : "checkmark.circle.fill")
                .foregroundStyle(selectedIDs.isEmpty ? DSColor.mutedInk : DSColor.mint)

            Text(selectionCount == 0 ? "点卡片开始选择" : "已选 \(selectionCount) / \(selectionMaximum)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DSColor.ink)

            Spacer()

            Text(viewModel.isGuestWorkspace ? "含自定义家务" : (selectionLimit.map { "最多 \($0) 项" } ?? "不限数量"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DSColor.mutedInk)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .background(DSColor.pureSurface.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var themedCatalogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedTheme.title)
                    .font(DSFont.functionalSectionTitle)
                Spacer()
                Text("\(themedChores.count) 项")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DSColor.mutedInk)
            }

            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(themedChores) { chore in
                    let isSelected = selectedIDs.contains(chore.id)
                    Button {
                        toggleSelection(chore)
                    } label: {
                        DSChoreCard(chore: chore)
                            .overlay {
                                RoundedRectangle(cornerRadius: DSCornerRadius.smallCard, style: .continuous)
                                    .fill(isSelected ? themeAccent(selectedTheme).opacity(0.16) : .clear)
                            }
                            .overlay(alignment: .topTrailing) {
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(DSColor.ink)
                                        .background(themeAccent(selectedTheme).clipShape(Circle()))
                                        .padding(8)
                                }
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: DSCornerRadius.smallCard, style: .continuous)
                                    .stroke(isSelected ? DSColor.outline.opacity(0.9) : .clear, lineWidth: 2)
                            }
                            .scaleEffect(isSelected ? 0.98 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(chore.name)，\(isSelected ? "已选择" : "未选择")")
                }
            }
        }
    }

    private var themedChores: [ChoreItem] {
        viewModel.routineCatalogChores.filter { $0.themeKey == selectedTheme.rawValue }
    }

    private var selectionLimit: Int? {
        viewModel.commonChoreSelectionLimit
    }

    private var selectionCount: Int {
        selectedIDs.count + (viewModel.isGuestWorkspace ? viewModel.customChores.count : 0)
    }

    private var selectionMaximum: Int {
        viewModel.isGuestWorkspace ? 6 : (selectionLimit ?? selectionCount)
    }

    private func themeAccent(_ theme: ChoreTheme) -> Color {
        switch theme {
        case .daily: DSColor.yellow
        case .love: DSColor.coral
        case .childcare: DSColor.sky
        case .pet: DSColor.mint
        }
    }

    private var introCard: some View {
        DSQuietCard(fill: DSColor.choreYellowSurface, padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checklist.checked")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(DSColor.ink)

                VStack(alignment: .leading, spacing: 6) {
                    Text(isInitialSetup ? "先选几项常做的，全家记录更顺手" : "常用区按需要增减")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DSColor.ink)
                    Text("点卡片加入或替换；图钉决定置顶，箭头调整同组顺序。其他家务会留在完整目录里。")
                        .font(.system(size: 13))
                        .foregroundStyle(DSColor.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var selectedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("家庭常用")
                    .font(DSFont.functionalSectionTitle)
                Spacer()
                Text(selectionLimit.map { "\(selectedIDs.count)/\($0)" } ?? "\(selectedIDs.count) 项")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(selectionLimit == selectedIDs.count ? DSColor.mint : DSColor.coral)
                    .monospacedDigit()
            }

            VStack(spacing: 8) {
                ForEach(Array(selectedChores.enumerated()), id: \.element.id) { index, chore in
                    selectedRow(chore, index: index)
                }
            }
        }
    }

    private func selectedRow(_ chore: ChoreItem, index: Int) -> some View {
        let isPinned = pinnedIDs.contains(chore.id)
        return DSQuietCard(fill: ChorePresentation.resolve(chore).cardFill, cornerRadius: 14, padding: 10) {
            VStack(spacing: 9) {
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(DSColor.pureSurface)
                        .clipShape(Circle())

                    routineIcon(chore, size: 46)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(chore.name)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Text(ChoreCategory.resolve(chore.category, choreName: chore.name).rawValue)
                            .font(.system(size: 12))
                            .foregroundStyle(DSColor.mutedInk)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 4)

                    Button(role: .destructive) {
                        selectedIDs.removeAll { $0 == chore.id }
                        pinnedIDs.remove(chore.id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 19))
                            .foregroundStyle(DSColor.coral)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("移出常用")
                }

                HStack(spacing: 8) {
                    Button {
                        if isPinned { pinnedIDs.remove(chore.id) } else { pinnedIDs.insert(chore.id) }
                        normalizePinnedOrder()
                    } label: {
                        Label(isPinned ? "已置顶" : "置顶", systemImage: isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(minWidth: 82, minHeight: 36)
                            .background(isPinned ? DSColor.yellow : DSColor.pureSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPinned ? "取消置顶" : "置顶")

                    Spacer(minLength: 0)

                    moveButton(systemName: "chevron.up", choreID: chore.id, offset: -1)
                    moveButton(systemName: "chevron.down", choreID: chore.id, offset: 1)
                }
            }
        }
    }

    private func moveButton(systemName: String, choreID: String, offset: Int) -> some View {
        Button {
            move(choreID, offset: offset)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 28, height: 22)
                .background(DSColor.pureSurface)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canMove(choreID, offset: offset))
        .opacity(canMove(choreID, offset: offset) ? 1 : 0.3)
    }

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("全部家务")
                .font(DSFont.functionalSectionTitle)

            ForEach(ChoreCategory.allCases) { category in
                let categoryChores = viewModel.routineCatalogChores.filter {
                    ChoreCategory.resolve($0.category, choreName: $0.name) == category
                }
                if !categoryChores.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DSColor.mutedInk)

                        LazyVGrid(columns: gridColumns, spacing: 8) {
                            ForEach(categoryChores) { chore in
                                Button {
                                    toggleSelection(chore)
                                } label: {
                                    DSChoreCard(chore: chore)
                                        .overlay(alignment: .topLeading) {
                                            if selectedIDs.contains(chore.id) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 22, weight: .bold))
                                                    .foregroundStyle(DSColor.infoBlue)
                                                    .background(DSColor.pureSurface.clipShape(Circle()))
                                                    .padding(7)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var customManagementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("自定义家务")
                    .font(DSFont.functionalSectionTitle)
                Spacer()
                Text("\(viewModel.customChores.count)/\(viewModel.customChoreLimit)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DSColor.mutedInk)
            }

            Text(viewModel.hasPremiumAccess
                ? "高级版最多创建 10 项；常用页每次只展示接下来的 2 个空位。"
                : "免费版最多创建 2 项；创建前可查看高级版权益。")
                .font(.system(size: 12))
                .foregroundStyle(DSColor.mutedInk)

            ForEach(viewModel.customChores) { chore in
                HStack(spacing: 12) {
                    routineIcon(chore, size: 46)
                    Text(chore.name)
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Button("编辑") {
                        if viewModel.canEditCommonChoreLayout {
                            customEditorContext = .init(id: chore.id, chore: chore)
                        } else if viewModel.canChooseChoreLayoutMode && viewModel.followsFamilyChoreLayout {
                            viewModel.errorMessage = "当前正在跟随一家之主布局，请先关闭开关再编辑。"
                        } else {
                            premiumUpgradeTrigger = .personalLayout
                        }
                    }
                    Button(role: .destructive) {
                        if viewModel.canEditCommonChoreLayout {
                            customChoreToDelete = chore
                        } else if viewModel.canChooseChoreLayoutMode && viewModel.followsFamilyChoreLayout {
                            viewModel.errorMessage = "当前正在跟随一家之主布局，请先关闭开关再编辑。"
                        } else {
                            premiumUpgradeTrigger = .personalLayout
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                .padding(12)
                .background(DSColor.pureSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if (viewModel.availableCustomChoreSlots > 0 || !viewModel.hasPremiumAccess)
                && (!viewModel.isGuestWorkspace || selectionCount < 6) {
                Button {
                    let context = CustomChoreEditorContext(id: "new-\(UUID().uuidString)", chore: nil)
                    if viewModel.hasPremiumAccess || viewModel.isGuestWorkspace {
                        customEditorContext = context
                    } else {
                        pendingCustomEditorContext = context
                        premiumUpgradeTrigger = .customChore
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }
                } label: {
                    Label(
                        viewModel.availableCustomChoreSlots > 0 ? "新增自定义家务" : "扩展自定义额度",
                        systemImage: viewModel.availableCustomChoreSlots > 0 ? "plus.circle.fill" : "crown.fill"
                    )
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(DSColor.yellow)
                        .foregroundStyle(DSColor.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var saveBar: some View {
        VStack(spacing: 8) {
            if let message = localMessage ?? viewModel.errorMessage {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DSColor.coral)
            }

            HStack(spacing: 10) {
                if !isInitialSetup {
                    Button("取消") { dismiss() }
                        .frame(minWidth: 78, minHeight: 50)
                }

                Button {
                    Task {
                        isSaving = true
                        let succeeded = await viewModel.saveChoreLayout(
                            choreIDs: normalizedSelection,
                            pinnedIDs: pinnedIDs
                        )
                        isSaving = false
                        if succeeded && !isInitialSetup { dismiss() }
                    }
                } label: {
                    Group {
                        if isSaving { ProgressView().tint(DSColor.ink) }
                        else { Label(isInitialSetup ? "开始使用" : "保存常用家务", systemImage: "checkmark.circle.fill") }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(selectionCount == 0 ? DSColor.surface : DSColor.yellow)
                    .foregroundStyle(DSColor.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSaving || selectionCount == 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var selectedChores: [ChoreItem] {
        let byID = Dictionary(uniqueKeysWithValues: viewModel.allAvailableChores.map { ($0.id, $0) })
        return normalizedSelection.compactMap { byID[$0] }
    }

    private var normalizedSelection: [String] {
        selectedIDs.filter(pinnedIDs.contains) + selectedIDs.filter { !pinnedIDs.contains($0) }
    }

    private var initialSelection: [String] {
        if isInitialSetup && !viewModel.choreLayoutConfigured {
            return []
        }

        let available = Set(viewModel.routineCatalogChores.map(\.id))
        let saved = viewModel.choreOrder.filter(available.contains)
        return saved
    }

    private var gridColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    }

    private func toggleSelection(_ chore: ChoreItem) {
        localMessage = nil
        if selectedIDs.contains(chore.id) {
            selectedIDs.removeAll { $0 == chore.id }
            pinnedIDs.remove(chore.id)
        } else if selectionLimit.map({ selectedIDs.count < $0 }) ?? true {
            selectedIDs.append(chore.id)
            UISelectionFeedbackGenerator().selectionChanged()
        } else {
            premiumUpgradeTrigger = .commonLimit
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func normalizePinnedOrder() {
        selectedIDs = normalizedSelection
    }

    private func move(_ choreID: String, offset: Int) {
        guard let index = selectedIDs.firstIndex(of: choreID) else { return }
        let target = index + offset
        guard selectedIDs.indices.contains(target), pinnedIDs.contains(selectedIDs[target]) == pinnedIDs.contains(choreID) else { return }
        selectedIDs.swapAt(index, target)
    }

    private func canMove(_ choreID: String, offset: Int) -> Bool {
        guard let index = selectedIDs.firstIndex(of: choreID) else { return false }
        let target = index + offset
        return selectedIDs.indices.contains(target)
            && pinnedIDs.contains(selectedIDs[target]) == pinnedIDs.contains(choreID)
    }

    private func fillSelectionIfNeeded() {
        let selected = Set(selectedIDs)
        let targetCount = selectionLimit ?? viewModel.routineCatalogChores.count
        for chore in viewModel.routineCatalogChores where selectedIDs.count < targetCount && !selected.contains(chore.id) {
            selectedIDs.append(chore.id)
        }
    }

    private func continueWithFreeCustomSlot() {
        let context = pendingCustomEditorContext
        pendingCustomEditorContext = nil
        premiumUpgradeTrigger = nil
        DispatchQueue.main.async {
            customEditorContext = context
        }
    }

    private func openCustomEditorAfterUpgrade() {
        continueWithFreeCustomSlot()
    }

    private func premiumUpgradeSheet(for trigger: PremiumUpgradeTrigger) -> some View {
        let canContinueFree = trigger == .customChore
            && viewModel.isCurrentUserOwner
            && viewModel.availableCustomChoreSlots > 0
        let continueAction: (() -> Void)? = canContinueFree
            ? { continueWithFreeCustomSlot() }
            : nil
        let unlockedAction: (() -> Void)? = trigger == .customChore
            ? { openCustomEditorAfterUpgrade() }
            : nil

        return PremiumUpgradeSheet(
            trigger: trigger,
            onContinueFree: continueAction,
            onUnlocked: unlockedAction
        )
        .environmentObject(viewModel)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func routineIcon(_ chore: ChoreItem, size: CGFloat) -> some View {
        DSChoreIconTile(chore: chore, size: size)
    }
}

enum PremiumUpgradeTrigger: String, Identifiable, Equatable {
    case profile
    case commonLimit
    case customChore
    case personalLayout
    case pointsMultiplier

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: "解锁高级家庭空间"
        case .commonLimit: "常用家务已经放满啦"
        case .customChore: "把你们家的独门家务记下来"
        case .personalLayout: "每个人都能有自己的常用区"
        case .pointsMultiplier: "让积分更贴合家务难度"
        }
    }

    var subtitle: String {
        switch self {
        case .profile: "把常用家务、自定义家务和家庭成员的个人偏好一起升级。"
        case .commonLimit: "免费版最多放 6 项常用家务，高级版不限制数量。"
        case .customChore: "免费版可创建 2 项，高级版可创建 10 项自定义家务。"
        case .personalLayout: "免费版由一家之主统一设置；高级版每位成员都能单独定制。"
        case .pointsMultiplier: "高级版可在每次记录时调整 0.5x...2.0x 积分倍率。"
        }
    }
}

struct PremiumUpgradeSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let trigger: PremiumUpgradeTrigger
    var onContinueFree: (() -> Void)? = nil
    var onUnlocked: (() -> Void)? = nil

    @State private var code = ""
    @State private var errorMessage: String?
    @State private var isRedeeming = false
    @State private var isRedeemed = false
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isRedeemed {
                    successContent
                } else {
                    upgradeContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.quietBackground.ignoresSafeArea())
    }

    private var upgradeContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "crown.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(DSColor.ink)
                .frame(width: 68, height: 68)
                .background(DSColor.yellow)
                .clipShape(Circle())

            VStack(spacing: 7) {
                Text(trigger.title)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(DSColor.ink)
                    .multilineTextAlignment(.center)

                Text(trigger.subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(DSColor.mutedInk)
                    .multilineTextAlignment(.center)
            }

            comparisonTable

            VStack(alignment: .leading, spacing: 8) {
                Text("开发测试兑换")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DSColor.mutedInk)

            TextField("输入兑换码", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.system(size: 22, weight: .semibold))
                .monospacedDigit()
                .focused($isCodeFocused)
                .padding(.horizontal, 16)
                .frame(height: 58)
                .background(DSColor.pureSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(errorMessage == nil ? DSColor.subtleStroke : DSColor.coral, lineWidth: 1.5)
                )
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DSColor.coral)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task {
                    isRedeeming = true
                    errorMessage = nil
                    let succeeded = await viewModel.redeemPremium(code: code)
                    isRedeeming = false

                    if succeeded {
                        isCodeFocused = false
                        withAnimation(.easeOut(duration: 0.2)) {
                            isRedeemed = true
                        }
                    } else {
                        errorMessage = viewModel.errorMessage ?? "兑换失败，请稍后重试"
                    }
                }
            } label: {
                Group {
                    if isRedeeming {
                        ProgressView()
                            .tint(DSColor.ink)
                    } else {
                        Label("兑换并开通高级版", systemImage: "sparkles")
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DSColor.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(DSColor.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isRedeeming || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let onContinueFree {
                Button("先使用免费额度") {
                    dismiss()
                    DispatchQueue.main.async { onContinueFree() }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DSColor.ink)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(DSColor.pureSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DSColor.subtleStroke, lineWidth: 1)
                )
            }

            Button("暂不开通", role: .cancel) { dismiss() }
                .foregroundStyle(DSColor.mutedInk)
                .disabled(isRedeeming)
        }
    }

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            comparisonHeader
            comparisonRow(label: "常用家务", free: "最多 6 项", premium: "不限数量")
            comparisonRow(label: "自定义家务", free: "最多 2 项", premium: "不限（保护上限 100）")
            comparisonRow(label: "成员常用区", free: "全家共享", premium: "每人定制")
            comparisonRow(label: "积分倍率", free: "系统固定", premium: "0.5–2.0x")
            comparisonRow(label: "家庭共享", free: "不共享", premium: "全家可用")
        }
        .background(DSColor.pureSurface.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DSColor.subtleStroke, lineWidth: 1)
        )
    }

    private var comparisonHeader: some View {
        HStack(spacing: 0) {
            Text("权益")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("免费版")
                .frame(width: 82)
            Text("高级版")
                .frame(width: 82)
                .foregroundStyle(DSColor.ink)
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(DSColor.mutedInk)
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(DSColor.yellow.opacity(0.34))
    }

    private func comparisonRow(label: String, free: String, premium: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(free)
                .foregroundStyle(DSColor.mutedInk)
                .frame(width: 82)
            Text(premium)
                .fontWeight(.semibold)
                .foregroundStyle(DSColor.ink)
                .frame(width: 82)
        }
        .font(.system(size: 13))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .overlay(alignment: .top) {
            Divider().padding(.leading, 14)
        }
    }

    private var successContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(DSColor.mint)

            VStack(spacing: 8) {
                Text("家庭高级版已解锁")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(DSColor.ink)

                Text("全家已共享高级权益：常用家务不限数量，可创建 10 项自定义家务；每位成员都能定制常用区，并按实际难度调整积分倍率。")
                    .font(.system(size: 15))
                    .foregroundStyle(DSColor.mutedInk)
                    .multilineTextAlignment(.center)
            }

            Button("开始使用高级版") {
                dismiss()
                DispatchQueue.main.async { onUnlocked?() }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(DSColor.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(DSColor.mint)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .buttonStyle(.plain)
        }
    }
}

private struct CustomChoreEditorContext: Identifiable {
    let id: String
    let chore: ChoreItem?
}

private struct CustomChoreEditorSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel

    let chore: ChoreItem?
    let onSave: (CustomChoreDraft) async -> Bool
    let onCancel: () -> Void

    @State private var draft: CustomChoreDraft
    @State private var isSaving = false
    @State private var localErrorMessage: String?
    @FocusState private var isNameFocused: Bool

    init(
        chore: ChoreItem?,
        onSave: @escaping (CustomChoreDraft) async -> Bool,
        onCancel: @escaping () -> Void
    ) {
        self.chore = chore
        self.onSave = onSave
        self.onCancel = onCancel
        _draft = State(initialValue: chore.map { CustomChoreDraft(chore: $0) } ?? CustomChoreDraft())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    previewCard
                    nameField
                    categoryPicker
                    iconLibrary
                    durationControl
                    multiplierControl
                    pointsPreview
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .padding(.bottom, 24)
            }
            .background(DSColor.quietBackground.ignoresSafeArea())
            .navigationTitle(chore == nil ? "添加自定义家务" : "编辑自定义家务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                    .fontWeight(.semibold)
                    .disabled(isSaving || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var selectedOption: CustomChoreIconOption {
        CustomChoreCatalog.option(for: draft.iconKey) ?? CustomChoreCatalog.options[0]
    }

    private var previewCard: some View {
        HStack(spacing: 14) {
            DSChoreAssetImage(assetName: draft.iconKey)
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(draft.name.isEmpty ? "未命名家务" : draft.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DSColor.ink)
                    .lineLimit(2)

                Text(draft.category.rawValue)
                    .font(.system(size: 13))
                    .foregroundStyle(DSColor.mutedInk)

                Text("\(draft.standardMinutes) 分钟 · +\(draft.defaultPoints) 分")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DSColor.ink)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(selectedOption.color.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(DSColor.subtleStroke, lineWidth: 1.5))
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("家务名称")
            TextField("输入家务名称", text: $draft.name)
                .textInputAutocapitalization(.never)
                .focused($isNameFocused)
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(DSColor.pureSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(DSColor.subtleStroke, lineWidth: 1.5))
                .onChange(of: draft.name) { _, _ in
                    localErrorMessage = nil
                }

            Text("最多 5 个字")
                .font(.system(size: 12))
                .foregroundStyle(DSColor.mutedInk)

            if let localErrorMessage {
                Text(localErrorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DSColor.coral)
            }
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("统计大类")

            HStack(spacing: 12) {
                Label("归入本周战况和月度战报", systemImage: "chart.bar.fill")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DSColor.mutedInk)

                Spacer(minLength: 0)

                Picker("统计大类", selection: $draft.category) {
                    ForEach(ChoreCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .tint(DSColor.infoBlue)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(DSColor.pureSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(DSColor.subtleStroke, lineWidth: 1.5))
        }
    }

    private var iconLibrary: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("选择通用图标")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(CustomChoreCatalog.options) { option in
                    Button {
                        draft.iconKey = option.id
                    } label: {
                        DSChoreAssetImage(assetName: option.id)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .background(DSColor.pureSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13)
                                    .stroke(
                                        draft.iconKey == option.id ? DSColor.ink : Color.clear,
                                        lineWidth: 2.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.accessibilityLabel)
                    .accessibilityAddTraits(draft.iconKey == option.id ? .isSelected : [])
                }
            }
        }
    }

    private var durationControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("默认时长")
                Spacer()
                Text("\(draft.standardMinutes) 分钟")
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
            }
            Stepper("调整默认时长", value: $draft.standardMinutes, in: 1...180, step: 1)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .trailing)
            Slider(value: Binding(
                get: { Double(draft.standardMinutes) },
                set: { draft.standardMinutes = Int($0.rounded()) }
            ), in: 1...180, step: 1)
            .tint(DSColor.infoBlue)
        }
    }

    private var multiplierControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("积分倍率")
                Spacer()
                Text(String(format: "%.1fx", draft.difficultyMultiplier))
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
            }
            Slider(value: $draft.difficultyMultiplier, in: 0.5...2.0, step: 0.1)
                .tint(DSColor.coral)
            Text("倍率越高，每分钟积分越高。")
                .font(.system(size: 12))
                .foregroundStyle(DSColor.mutedInk)
        }
    }

    private var pointsPreview: some View {
        HStack {
            Label("默认完成一次", systemImage: "sparkles")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Text("+\(draft.defaultPoints) 分")
                .font(.system(size: 24, weight: .bold))
                .monospacedDigit()
        }
        .foregroundStyle(DSColor.ink)
        .padding(16)
        .background(DSColor.yellow.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(DSColor.ink)
    }

    private func save() {
        isNameFocused = false
        localErrorMessage = nil

        let normalizedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            localErrorMessage = "请给这个家务起个名字。"
            return
        }
        guard normalizedName.count <= 5 else {
            localErrorMessage = "家务名称最多 5 个字。"
            return
        }

        Task {
            isSaving = true
            let saved = await onSave(draft)
            if !saved {
                localErrorMessage = viewModel.errorMessage ?? "保存失败，请稍后重试。"
            }
            isSaving = false
        }
    }
}

#Preview {
    NavigationStack {
        ChoreSelectionView()
            .environmentObject(AppViewModel.previewLoggedIn())
            .environmentObject(CommonChoreDragCoordinator())
    }
}


#Preview("记一下 · 深色") {
    NavigationStack {
        ChoreSelectionView()
            .environmentObject(AppViewModel.previewLoggedIn())
            .environmentObject(CommonChoreDragCoordinator())
    }
    .preferredColorScheme(.dark)
}
