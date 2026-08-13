import Foundation
import Security
import XCTest
@testable import WhatDidYouDo

@MainActor
final class WhatDidYouDoTests: XCTestCase {
    func testAchievementArtworkMapsAllCurrentAchievementThemes() {
        let expectedMappings = [
            "FIRST_RECORD": "achievement_first_record",
            "ACTIVE_DAYS_3": "achievement_active_days_3",
            "HABIT_30": "achievement_habit_25_30",
            "MASTERY_DISHES": "achievement_mastery_dishes",
            "REACTION_FIRST": "achievement_reaction_first",
            "FAMILY_FORMED": "achievement_family_formed",
            "PAIR_COOK_AND_CLEAN": "achievement_pair_cook_and_clean",
            "FAMILY_ACTIVE_DAYS": "achievement_family_visible_4w",
            "FAMILY_RECORD_COUNT": "achievement_family_all_in",
            "FAMILY_ANNIVERSARY": "achievement_family_formed",
            "HIDDEN_DISHES_3": "achievement_mastery_dishes",
            "HIDDEN_SHINY_FLOOR": "achievement_mastery_floor",
            "HIDDEN_GUESTS": "achievement_mastery_all_rounder",
            "HIDDEN_NIGHT_SHIFT": "achievement_streak_14",
            "HIDDEN_ENDURANCE": "achievement_mastery_organize",
        ]

        for (key, assetName) in expectedMappings {
            XCTAssertEqual(AchievementCopy.artworkAssetName(for: key), assetName)
        }
        XCTAssertNil(AchievementCopy.artworkAssetName(for: "UNKNOWN_ACHIEVEMENT"))
    }

    func testAppAppearanceProvidesThreeStableOptions() {
        XCTAssertEqual(AppAppearance.allCases, [.system, .light, .dark])
        XCTAssertEqual(AppAppearance.system.title, "跟随系统")
        XCTAssertEqual(AppAppearance.light.title, "浅色")
        XCTAssertEqual(AppAppearance.dark.title, "深色")
    }

    func testAppAppearanceFallsBackToSystemForUnknownStoredValue() {
        XCTAssertEqual(AppAppearance.resolve("unexpected-value"), .system)
        XCTAssertNil(AppAppearance.system.preferredColorScheme)
        XCTAssertEqual(AppAppearance.light.preferredColorScheme, .light)
        XCTAssertEqual(AppAppearance.dark.preferredColorScheme, .dark)
    }

    func testEstimatedPointsUsesDefaultPointsAtStandardDuration() {
        let chore = makeChore(minutes: 15, points: 21)

        XCTAssertEqual(AppViewModel.estimatedPoints(for: chore, selectedMinutes: 15), 21)
    }

    func testEstimatedPointsScalesForLongerAndShorterDurations() {
        let chore = makeChore(minutes: 15, points: 21)

        XCTAssertEqual(AppViewModel.estimatedPoints(for: chore, selectedMinutes: 20), 28)
        XCTAssertEqual(AppViewModel.estimatedPoints(for: chore, selectedMinutes: 10), 14)
    }

    func testEstimatedPointsFallsBackWhenStandardDurationIsZero() {
        let chore = makeChore(minutes: 0, points: 21)

        XCTAssertEqual(AppViewModel.estimatedPoints(for: chore, selectedMinutes: 20), 21)
    }

    func testPremiumPointsMultiplierUsesActualMinutes() {
        let chore = makeChore(minutes: 45, points: 68)

        XCTAssertEqual(AppViewModel.defaultPointsMultiplier(for: chore), 1.5)
        XCTAssertEqual(
            AppViewModel.estimatedPoints(
                for: chore,
                selectedMinutes: 30,
                pointsMultiplier: 1.8
            ),
            54
        )
    }

    func testPremiumPointsMultiplierClampsToSupportedRange() {
        let chore = makeChore(minutes: 15, points: 21)

        XCTAssertEqual(
            AppViewModel.estimatedPoints(for: chore, selectedMinutes: 10, pointsMultiplier: 0.1),
            5
        )
        XCTAssertEqual(
            AppViewModel.estimatedPoints(for: chore, selectedMinutes: 10, pointsMultiplier: 3),
            20
        )
    }

    func testCustomChoreCatalogHasFourGenericAssetsAndDraftStartsBlank() {
        XCTAssertEqual(CustomChoreCatalog.options.count, 4)
        XCTAssertEqual(Set(CustomChoreCatalog.options.map(\.id)).count, 4)
        XCTAssertTrue(CustomChoreCatalog.options.allSatisfy { $0.id.hasPrefix("chore_custom_generic_") })

        let blankDraft = CustomChoreDraft()
        XCTAssertEqual(blankDraft.name, "")
        XCTAssertEqual(blankDraft.category, .household)
        XCTAssertEqual(blankDraft.standardMinutes, 15)

        let draft = CustomChoreDraft(
            name: "擦餐桌",
            iconKey: "chore_custom_dust",
            category: .cleaning,
            standardMinutes: 15,
            difficultyMultiplier: 1.4
        )
        XCTAssertEqual(draft.defaultPoints, 21)
        XCTAssertEqual(draft.category, .cleaning)
    }

    func testLegacyChoreCategoriesCollapseIntoBroadCategories() {
        XCTAssertEqual(ChoreCategory.resolve("厨房类", choreName: "做饭 / 备餐"), .cooking)
        XCTAssertEqual(ChoreCategory.resolve("厨房类", choreName: "饭后收拾 / 洗碗"), .cleaning)
        XCTAssertEqual(ChoreCategory.resolve("餐厨清洁"), .cleaning)
        XCTAssertEqual(ChoreCategory.resolve("地面清洁"), .cleaning)
        XCTAssertEqual(ChoreCategory.resolve("收纳类"), .organizing)
        XCTAssertEqual(ChoreCategory.resolve("采购类"), .household)
    }

    func testCustomChoreCategoryIsIndependentFromIcon() async {
        let viewModel = AppViewModel(
            tokenStore: MockSecureTokenStore(),
            forceMockData: true,
            automaticallyRestoreSession: false
        )
        let draft = CustomChoreDraft(
            name: "文件归档",
            iconKey: "chore_custom_dust",
            category: .household,
            standardMinutes: 15,
            difficultyMultiplier: 1
        )

        let saved = await viewModel.saveCustomChore(draft)

        XCTAssertTrue(saved)
        XCTAssertEqual(viewModel.customChores.first?.category, ChoreCategory.household.rawValue)
    }

    func testCustomChoreNameRejectsMoreThanFiveCharacters() async {
        let viewModel = AppViewModel(
            tokenStore: MockSecureTokenStore(),
            forceMockData: true,
            automaticallyRestoreSession: false
        )
        let draft = CustomChoreDraft(
            name: "超过五个汉字",
            iconKey: "chore_custom_dust",
            category: .cleaning,
            standardMinutes: 15,
            difficultyMultiplier: 1
        )

        let saved = await viewModel.saveCustomChore(draft)

        XCTAssertFalse(saved)
        XCTAssertEqual(viewModel.errorMessage, "家务名称最多 5 个字。")
    }

    func testMockModeLimitsCustomChoresToTwoAndReleasesArchivedSlot() async {
        let viewModel = AppViewModel(
            tokenStore: MockSecureTokenStore(),
            forceMockData: true,
            automaticallyRestoreSession: false
        )
        let first = CustomChoreDraft(name: "擦餐桌", iconKey: "chore_custom_dust", standardMinutes: 15, difficultyMultiplier: 1)
        let second = CustomChoreDraft(name: "浇花", iconKey: "chore_custom_plant", standardMinutes: 10, difficultyMultiplier: 0.8)
        let third = CustomChoreDraft(name: "家庭账单", iconKey: "chore_custom_admin", standardMinutes: 20, difficultyMultiplier: 1.2)

        let firstSaved = await viewModel.saveCustomChore(first)
        let secondSaved = await viewModel.saveCustomChore(second)
        let thirdSaved = await viewModel.saveCustomChore(third)
        XCTAssertTrue(firstSaved)
        XCTAssertTrue(secondSaved)
        XCTAssertFalse(thirdSaved)
        XCTAssertEqual(viewModel.customChores.count, 2)
        XCTAssertEqual(viewModel.customChores.map(\.customSlot), [1, 2])
        XCTAssertEqual(viewModel.customChoreLimit, 2)

        let archived = await viewModel.archiveCustomChore(viewModel.customChores[0])
        XCTAssertTrue(archived)
        XCTAssertEqual(viewModel.availableCustomChoreSlots, 1)
        let replacementSaved = await viewModel.saveCustomChore(third)
        XCTAssertTrue(replacementSaved)
        XCTAssertEqual(viewModel.customChores.count, 2)
    }

    func testMockFamilyChoreLayoutSupportsFlexibleFreeAndPremiumSelection() async {
        let viewModel = AppViewModel(
            tokenStore: MockSecureTokenStore(),
            forceMockData: true,
            automaticallyRestoreSession: false
        )
        let choreIDs = Array(viewModel.allAvailableChores.prefix(7).map(\.id))

        let emptySelection = await viewModel.saveChoreLayout(
            choreIDs: [],
            pinnedIDs: []
        )
        XCTAssertFalse(emptySelection)

        let freeSelection = Array(choreIDs.prefix(3))
        let saved = await viewModel.saveChoreLayout(
            choreIDs: freeSelection,
            pinnedIDs: [freeSelection[2], freeSelection[0]]
        )
        XCTAssertTrue(saved)
        XCTAssertEqual(viewModel.displayedChores.count, 3)
        XCTAssertEqual(viewModel.displayedChores.prefix(2).map(\.id), [freeSelection[0], freeSelection[2]])
        XCTAssertTrue(viewModel.choreLayoutConfigured)

        let overFreeLimit = await viewModel.saveChoreLayout(
            choreIDs: choreIDs,
            pinnedIDs: []
        )
        XCTAssertFalse(overFreeLimit)

        viewModel.phoneNumber = "layout-premium"
        viewModel.mockLogin()
        let redeemed = await viewModel.redeemPremium(code: "241255")
        XCTAssertTrue(redeemed)
        let premiumSelection = Array(viewModel.allAvailableChores.prefix(12).map(\.id))
        let premiumSaved = await viewModel.saveChoreLayout(choreIDs: premiumSelection, pinnedIDs: [])
        XCTAssertTrue(premiumSaved)
        XCTAssertEqual(viewModel.displayedChores.count, 12)
    }

    func testCommonChoreGridContainsSelectedRoutineChoresAndTwoCustomSlots() async {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = makeViewModel(defaults: fixture.defaults)
        let choreIDs = Array(viewModel.allAvailableChores.prefix(6).map(\.id))
        let saved = await viewModel.saveChoreLayout(choreIDs: choreIDs, pinnedIDs: [])
        XCTAssertTrue(saved)

        viewModel.prepareCommonChoreGrid()

        XCTAssertEqual(viewModel.displayedChores.count, 6)
        XCTAssertEqual(viewModel.commonChoreGridItemIDs.count, 8)
        XCTAssertEqual(
            viewModel.commonChoreGridItemIDs.compactMap(viewModel.customChoreSlot(forGridItemID:)),
            [1, 2]
        )
    }

    func testCommonChoreGridReorderPersistsAcrossViewModels() async {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = makeViewModel(defaults: fixture.defaults)
        let choreIDs = Array(viewModel.allAvailableChores.prefix(6).map(\.id))
        let saved = await viewModel.saveChoreLayout(choreIDs: choreIDs, pinnedIDs: [])
        XCTAssertTrue(saved)
        viewModel.prepareCommonChoreGrid()
        let initialOrder = viewModel.commonChoreGridItemIDs
        let customSlotID = initialOrder.last!

        XCTAssertTrue(viewModel.moveCommonChoreGridItem(customSlotID, to: initialOrder[0]))
        XCTAssertEqual(viewModel.commonChoreGridItemIDs.first, customSlotID)

        let restoredViewModel = makeViewModel(defaults: fixture.defaults)
        let restoredSaved = await restoredViewModel.saveChoreLayout(choreIDs: choreIDs, pinnedIDs: [])
        XCTAssertTrue(restoredSaved)
        restoredViewModel.prepareCommonChoreGrid()
        XCTAssertEqual(restoredViewModel.commonChoreGridItemIDs.first, customSlotID)
    }

    func testCommonChoreGridTransientMovePersistsOnlyAfterDropCompletion() async throws {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = makeViewModel(defaults: fixture.defaults)
        let choreIDs = Array(viewModel.allAvailableChores.prefix(6).map(\.id))
        let initialSaved = await viewModel.saveChoreLayout(choreIDs: choreIDs, pinnedIDs: [])
        XCTAssertTrue(initialSaved)
        viewModel.prepareCommonChoreGrid()
        let sourceID = try XCTUnwrap(viewModel.commonChoreGridItemIDs.last)
        let targetID = try XCTUnwrap(viewModel.commonChoreGridItemIDs.first)

        XCTAssertTrue(viewModel.moveCommonChoreGridItem(sourceID, to: targetID, persist: false))

        let beforeDropViewModel = makeViewModel(defaults: fixture.defaults)
        let beforeDropSaved = await beforeDropViewModel.saveChoreLayout(choreIDs: choreIDs, pinnedIDs: [])
        XCTAssertTrue(beforeDropSaved)
        beforeDropViewModel.prepareCommonChoreGrid()
        XCTAssertNotEqual(beforeDropViewModel.commonChoreGridItemIDs.first, sourceID)

        await viewModel.persistCommonChoreGridLayout()
        let afterDropViewModel = makeViewModel(defaults: fixture.defaults)
        let afterDropSaved = await afterDropViewModel.saveChoreLayout(choreIDs: choreIDs, pinnedIDs: [])
        XCTAssertTrue(afterDropSaved)
        afterDropViewModel.prepareCommonChoreGrid()
        XCTAssertEqual(afterDropViewModel.commonChoreGridItemIDs.first, sourceID)
    }

    func testCommonChoreDragStateReturnsToIdleAfterInterruptedInteraction() {
        var state = CommonChoreDragState(
            itemID: "chore-1",
            location: CGPoint(x: 120, y: 240),
            isTrashTargeted: true
        )

        XCTAssertTrue(state.isActive)
        XCTAssertEqual(state.itemID, "chore-1")
        XCTAssertTrue(state.isTrashTargeted)

        state = .idle

        XCTAssertFalse(state.isActive)
        XCTAssertNil(state.itemID)
        XCTAssertNil(state.location)
        XCTAssertFalse(state.isTrashTargeted)
    }

    func testCommonChoreDragCoordinatorReplacesAndRestoresTabTargetState() {
        let coordinator = CommonChoreDragCoordinator()

        coordinator.begin()
        coordinator.trashFrame = CGRect(x: 20, y: 700, width: 350, height: 70)
        coordinator.isTrashTargeted = true

        XCTAssertTrue(coordinator.isActive)
        XCTAssertTrue(coordinator.isTrashTargeted)
        XCTAssertNotEqual(coordinator.trashFrame, .zero)

        coordinator.end()

        XCTAssertFalse(coordinator.isActive)
        XCTAssertFalse(coordinator.isTrashTargeted)
        XCTAssertEqual(coordinator.trashFrame, .zero)
    }

    func testChoreLibraryRevealRequiresARealUserScrollAndAnArmedTrigger() {
        XCTAssertFalse(
            ChoreLibraryRevealPolicy.shouldOpen(
                distanceToBottom: 0,
                threshold: -60,
                userHasScrolled: false,
                isArmed: true
            )
        )
        XCTAssertFalse(
            ChoreLibraryRevealPolicy.shouldOpen(
                distanceToBottom: 0,
                threshold: -60,
                userHasScrolled: true,
                isArmed: false
            )
        )
        XCTAssertFalse(
            ChoreLibraryRevealPolicy.shouldOpen(
                distanceToBottom: -40,
                threshold: -60,
                userHasScrolled: true,
                isArmed: true
            )
        )
        XCTAssertTrue(
            ChoreLibraryRevealPolicy.shouldOpen(
                distanceToBottom: -64,
                threshold: -60,
                userHasScrolled: true,
                isArmed: true
            )
        )
    }

    func testPremiumMemberCanSwitchBetweenSharedAndPersonalCommonChoreOrders() async throws {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = AppViewModel.previewLoggedIn(userDefaults: fixture.defaults)
        let redeemed = await viewModel.redeemPremium(code: "241255")
        XCTAssertTrue(redeemed)
        let initialRoutineIDs = Array(viewModel.routineCatalogChores.prefix(6).map(\.id))
        let configured = await viewModel.saveChoreLayout(
            choreIDs: initialRoutineIDs,
            pinnedIDs: []
        )
        XCTAssertTrue(configured)
        viewModel.prepareCommonChoreGrid()

        let familyRoutineOrder = viewModel.commonChoreGridItemIDs.filter { itemID in
            viewModel.routineCatalogChores.contains { $0.id == itemID }
        }
        let newOwner = try XCTUnwrap(viewModel.transferableFamilyMembers.first)
        let transferred = await viewModel.transferOwnership(to: newOwner)
        XCTAssertTrue(transferred)
        XCTAssertTrue(viewModel.canChooseChoreLayoutMode)
        XCTAssertTrue(viewModel.followsFamilyChoreLayout)
        XCTAssertFalse(viewModel.canEditCommonChoreLayout)

        viewModel.setFollowsFamilyChoreLayout(false)
        XCTAssertFalse(viewModel.followsFamilyChoreLayout)
        XCTAssertTrue(viewModel.canEditCommonChoreLayout)

        let personalRoutineOrder = viewModel.commonChoreGridItemIDs.filter { itemID in
            viewModel.routineCatalogChores.contains { $0.id == itemID }
        }
        let sourceID = try XCTUnwrap(personalRoutineOrder.last)
        let targetID = try XCTUnwrap(personalRoutineOrder.first)
        XCTAssertTrue(viewModel.moveCommonChoreGridItem(sourceID, to: targetID))
        XCTAssertEqual(viewModel.commonChoreGridItemIDs.first, sourceID)

        viewModel.setFollowsFamilyChoreLayout(true)
        let restoredFamilyOrder = viewModel.commonChoreGridItemIDs.filter { itemID in
            viewModel.routineCatalogChores.contains { $0.id == itemID }
        }
        XCTAssertEqual(restoredFamilyOrder, familyRoutineOrder)
        XCTAssertFalse(viewModel.canEditCommonChoreLayout)

        viewModel.setFollowsFamilyChoreLayout(false)
        XCTAssertEqual(viewModel.commonChoreGridItemIDs.first, sourceID)
    }

    func testCommonGridRoutineReorderUpdatesSavedLayoutOrder() async {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = makeViewModel(defaults: fixture.defaults)
        let choreIDs = Array(viewModel.allAvailableChores.prefix(6).map(\.id))
        let saved = await viewModel.saveChoreLayout(choreIDs: choreIDs, pinnedIDs: [])
        XCTAssertTrue(saved)
        viewModel.prepareCommonChoreGrid()

        XCTAssertTrue(viewModel.moveCommonChoreGridItem(choreIDs[1], to: choreIDs[0]))
        await viewModel.persistCommonChoreGridLayout()

        XCTAssertEqual(viewModel.choreOrder.first, choreIDs[1])
    }

    func testRemovingCommonChoreKeepsItInLibrary() async {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = makeViewModel(defaults: fixture.defaults)
        let choreIDs = Array(viewModel.allAvailableChores.prefix(4).map(\.id))
        let saved = await viewModel.saveChoreLayout(choreIDs: choreIDs, pinnedIDs: [])
        XCTAssertTrue(saved)

        let removed = await viewModel.removeCommonChoreGridItem(choreIDs[1])
        XCTAssertTrue(removed)

        XCTAssertFalse(viewModel.displayedChores.map(\.id).contains(choreIDs[1]))
        XCTAssertTrue(viewModel.allAvailableChores.map(\.id).contains(choreIDs[1]))
    }

    func testRemovingEmptyCustomPlaceholderPersists() async throws {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = makeViewModel(defaults: fixture.defaults)
        viewModel.prepareCommonChoreGrid()
        let placeholderID = try XCTUnwrap(
            viewModel.commonChoreGridItemIDs.first { $0.contains("custom-chore-slot-") }
        )

        let removed = await viewModel.removeCommonChoreGridItem(placeholderID)
        XCTAssertTrue(removed)
        XCTAssertFalse(viewModel.commonChoreGridItemIDs.contains(placeholderID))

        let restoredViewModel = makeViewModel(defaults: fixture.defaults)
        restoredViewModel.prepareCommonChoreGrid()
        XCTAssertFalse(restoredViewModel.commonChoreGridItemIDs.contains(placeholderID))
    }

    func testRemovingPremiumPlaceholderDoesNotBackfillAnotherBlankCard() async throws {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = makeViewModel(defaults: fixture.defaults)
        viewModel.phoneNumber = "premium-placeholder-removal"
        viewModel.mockLogin()
        let redeemed = await viewModel.redeemPremium(code: "241255")
        XCTAssertTrue(redeemed)
        viewModel.prepareCommonChoreGrid()

        let initialPlaceholders = viewModel.commonChoreGridItemIDs.compactMap(
            viewModel.customChoreSlot(forGridItemID:)
        )
        XCTAssertEqual(initialPlaceholders, [1, 2])
        let firstPlaceholderID = try XCTUnwrap(
            viewModel.commonChoreGridItemIDs.first { viewModel.customChoreSlot(forGridItemID: $0) == 1 }
        )

        let removed = await viewModel.removeCommonChoreGridItem(firstPlaceholderID)
        XCTAssertTrue(removed)
        XCTAssertEqual(
            viewModel.commonChoreGridItemIDs.compactMap(viewModel.customChoreSlot(forGridItemID:)),
            [2]
        )
    }

    func testNewSharedCustomChoreAppearsInPersonalizedGridAfterPlaceholderWasHidden() async throws {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = AppViewModel.previewLoggedIn(userDefaults: fixture.defaults)
        let redeemed = await viewModel.redeemPremium(code: "241255")
        XCTAssertTrue(redeemed)
        let initialRoutineIDs = Array(viewModel.routineCatalogChores.prefix(6).map(\.id))
        let configured = await viewModel.saveChoreLayout(
            choreIDs: initialRoutineIDs,
            pinnedIDs: []
        )
        XCTAssertTrue(configured)

        for (name, icon) in [("擦桌", "chore_custom_generic_01"), ("浇花", "chore_custom_plant")] {
            let saved = await viewModel.saveCustomChore(
                CustomChoreDraft(
                    name: name,
                    iconKey: icon,
                    standardMinutes: 10,
                    difficultyMultiplier: 1
                )
            )
            XCTAssertTrue(saved)
        }

        let newOwner = try XCTUnwrap(viewModel.transferableFamilyMembers.first)
        let transferred = await viewModel.transferOwnership(to: newOwner)
        XCTAssertTrue(transferred)
        viewModel.setFollowsFamilyChoreLayout(false)

        let thirdPlaceholderID = try XCTUnwrap(
            viewModel.commonChoreGridItemIDs.first { viewModel.customChoreSlot(forGridItemID: $0) == 3 }
        )
        let removed = await viewModel.removeCommonChoreGridItem(thirdPlaceholderID)
        XCTAssertTrue(removed)
        let saved = await viewModel.saveCustomChore(
            CustomChoreDraft(
                name: "擦镜子",
                iconKey: "chore_custom_window",
                standardMinutes: 10,
                difficultyMultiplier: 1
            )
        )
        XCTAssertTrue(saved)

        XCTAssertNotNil(viewModel.customChore(forSlot: 3))
        XCTAssertTrue(viewModel.commonChoreGridItemIDs.contains(thirdPlaceholderID))
    }

    func testMockWeekNavigationMovesBackAndReturnsToCurrentWeek() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = makeViewModel(defaults: fixture.defaults)

        viewModel.selectPreviousWeek()
        XCTAssertEqual(viewModel.selectedWeekOffset, -1)
        XCTAssertEqual(viewModel.selectedWeekLabel, "上周")
        XCTAssertTrue(viewModel.weekRecords.isEmpty)

        viewModel.selectNextWeek()
        XCTAssertEqual(viewModel.selectedWeekOffset, 0)
        XCTAssertFalse(viewModel.canSelectNextWeek)
        XCTAssertEqual(viewModel.weekRecords.count, MockData.todayRecords.count)
    }

    func testWeekLabelsUseNaturalChineseNamesBeforeMonthWeekFormat() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = makeViewModel(defaults: fixture.defaults)

        XCTAssertEqual(viewModel.selectedWeekLabel, "本周")
        viewModel.selectPreviousWeek()
        XCTAssertEqual(viewModel.selectedWeekLabel, "上周")
        viewModel.selectPreviousWeek()
        XCTAssertEqual(viewModel.selectedWeekLabel, "上上周")
        viewModel.selectPreviousWeek()
        XCTAssertTrue(viewModel.selectedWeekLabel.contains("月第"))
        XCTAssertTrue(viewModel.selectedWeekLabel.hasSuffix("周"))
        XCTAssertFalse(viewModel.selectedWeekAccessibilityLabel.isEmpty)
    }

    func testPremiumCommonGridShowsOnlyTwoEmptyCustomPlaceholders() async {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = makeViewModel(defaults: fixture.defaults)
        viewModel.phoneNumber = "premium-grid"
        viewModel.mockLogin()
        let redeemed = await viewModel.redeemPremium(code: "241255")
        XCTAssertTrue(redeemed)

        viewModel.prepareCommonChoreGrid()
        XCTAssertEqual(
            viewModel.commonChoreGridItemIDs.compactMap(viewModel.customChoreSlot(forGridItemID:)),
            [1, 2]
        )

        let saved = await viewModel.saveCustomChore(
            CustomChoreDraft(
                name: "浇花",
                iconKey: "chore_custom_plant",
                standardMinutes: 10,
                difficultyMultiplier: 1
            )
        )
        XCTAssertTrue(saved)
        viewModel.prepareCommonChoreGrid()
        XCTAssertEqual(
            viewModel.commonChoreGridItemIDs.compactMap(viewModel.customChoreSlot(forGridItemID:)),
            [1, 2, 3]
        )
    }

    func testMockCatalogContainsFourThemesInProductOrder() {
        XCTAssertEqual(ChoreTheme.allCases.map(\.title), ["家庭", "恋爱", "育儿", "宠物"])
        XCTAssertEqual(MockData.chores.filter { $0.themeKey == ChoreTheme.daily.rawValue }.count, 22)
        XCTAssertEqual(MockData.chores.filter { $0.themeKey == ChoreTheme.love.rawValue }.count, 8)
        XCTAssertEqual(MockData.chores.filter { $0.themeKey == ChoreTheme.childcare.rawValue }.count, 9)
        XCTAssertEqual(MockData.chores.filter { $0.themeKey == ChoreTheme.pet.rawValue }.count, 7)
    }

    func testDurationMemoryUsesDefaultThenSavedValue() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = makeViewModel(defaults: fixture.defaults)
        let chore = makeChore(id: "dishes", minutes: 15, points: 21)

        XCTAssertEqual(viewModel.getDefaultDuration(for: chore), 15)

        viewModel.saveLastDuration(choreId: chore.id, minutes: 20)

        XCTAssertEqual(viewModel.getDefaultDuration(for: chore), 20)
    }

    func testDurationMemoryIsIndependentPerChore() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = makeViewModel(defaults: fixture.defaults)
        let dishes = makeChore(id: "dishes", minutes: 15, points: 21)
        let bathroom = makeChore(id: "bathroom", minutes: 30, points: 45)

        viewModel.saveLastDuration(choreId: dishes.id, minutes: 20)

        XCTAssertEqual(viewModel.getDefaultDuration(for: dishes), 20)
        XCTAssertEqual(viewModel.getDefaultDuration(for: bathroom), 30)
    }

    func testMockPremiumRedemptionRejectsWrongCodeAndPersistsCorrectCode() async {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }

        let viewModel = makeViewModel(defaults: fixture.defaults)
        viewModel.phoneNumber = "123456"
        viewModel.mockLogin()

        let wrongCodeSucceeded = await viewModel.redeemPremium(code: "000000")
        XCTAssertFalse(wrongCodeSucceeded)
        XCTAssertFalse(viewModel.hasPremiumAccess)

        let correctCodeSucceeded = await viewModel.redeemPremium(code: "241255")
        XCTAssertTrue(correctCodeSucceeded)
        XCTAssertTrue(viewModel.hasPremiumAccess)
        XCTAssertEqual(viewModel.customChoreLimit, 100)
        XCTAssertEqual(viewModel.availableCustomChoreSlots, 100)

        let restoredViewModel = makeViewModel(defaults: fixture.defaults)
        restoredViewModel.phoneNumber = "123456"
        restoredViewModel.mockLogin()
        XCTAssertTrue(restoredViewModel.hasPremiumAccess)
        XCTAssertEqual(restoredViewModel.customChoreLimit, 100)
    }

    func testAPIPremiumRedemptionUsesBackendAndUnlocksAccount() async throws {
        let client = StubAPIClient(
            responses: [
                "POST /auth/redeem-premium": Data(
                    #"{"plan":"premium","premiumRedeemedAt":"2026-08-01T05:00:00.000Z"}"#.utf8
                ),
            ]
        )
        let viewModel = AppViewModel(
            apiClient: client,
            tokenStore: MockSecureTokenStore(),
            dataMode: .api,
            automaticallyRestoreSession: false
        )

        let succeeded = await viewModel.redeemPremium(code: "241255")
        XCTAssertTrue(succeeded)
        XCTAssertTrue(viewModel.hasPremiumAccess)
        let requestBody = await client.requestBodies["POST /auth/redeem-premium"]
        XCTAssertEqual(
            try requestBody.map { try JSONDecoder().decode(PremiumRedemptionRequest.self, from: $0).code },
            "241255"
        )
    }

    func testActivityItemDTOInteractionFieldsDecode() throws {
        let data = Data(
            #"""
            {
              "id": "record-1",
              "recordId": "record-1",
              "familyId": "family-1",
              "user": {
                "id": "user-1",
                "displayName": "用户一",
                "identityLabel": "老妈",
                "avatarKey": "avatar_01"
              },
              "createdBy": {
                "id": "user-1",
                "displayName": "用户一",
                "identityLabel": "老妈",
                "avatarKey": "avatar_01"
              },
              "chore": {
                "id": "chore-1",
                "name": "洗碗",
                "category": "厨房类",
                "icon": "fork.knife",
                "standardMinutes": 15,
                "defaultPoints": 20,
                "difficultyMultiplier": 1.3
              },
              "choreName": "洗碗",
              "minutes": 15,
              "actualMinutes": 20,
              "points": 28,
              "pointsMultiplier": 1.4,
              "note": null,
              "imageUrls": [],
              "likeCount": 1,
              "likedBy": [
                {
                  "id": "user-2",
                  "displayName": "用户二",
                  "identityLabel": "室友",
                  "avatarKey": "avatar_02",
                  "reactionKey": "high_five"
                }
              ],
              "likedByMe": true,
              "myReaction": "laugh_cry",
              "reactionCounts": {
                "like": 0,
                "high_five": 1,
                "moon_face": 0,
                "laugh_cry": 1,
                "tease": 0
              },
              "canDelete": true,
              "canEdit": true,
              "createdAt": "2026-06-22T08:00:00.000Z"
            }
            """#.utf8
        )

        let dto = try APIClient.decoder.decode(ActivityItemDTO.self, from: data)

        XCTAssertEqual(dto.likeCount, 1)
        XCTAssertEqual(dto.likedByMe, true)
        XCTAssertEqual(dto.canDelete, true)
        XCTAssertEqual(dto.canEdit, true)
        XCTAssertEqual(dto.pointsMultiplier, 1.4)
        XCTAssertEqual(dto.chore.defaultPoints, 20)
        XCTAssertEqual(dto.createdBy?.identityLabel, "老妈")
        XCTAssertEqual(dto.createdBy?.avatarKey, "avatar_01")
        XCTAssertEqual(dto.likedBy?.first?.identityLabel, "室友")
        XCTAssertEqual(dto.likedBy?.first?.avatarKey, "avatar_02")
        XCTAssertEqual(dto.likedBy?.first?.reactionKey, "high_five")
        XCTAssertEqual(dto.myReaction, "laugh_cry")
        XCTAssertEqual(dto.reactionCounts?["high_five"], 1)
        XCTAssertEqual(dto.reactionCounts?["laugh_cry"], 1)
    }

    func testMockRecordEditUpdatesOnlyOwnedRecord() throws {
        let viewModel = AppViewModel.previewLoggedIn()
        let ownedRecord = try XCTUnwrap(viewModel.recentRecords.first { $0.canEdit })
        let untouchedIDs = viewModel.recentRecords.filter { $0.id != ownedRecord.id }.map(\.id)

        viewModel.updateRecord(ownedRecord, actualMinutes: 30, pointsMultiplier: nil)

        let updated = try XCTUnwrap(viewModel.recentRecords.first { $0.id == ownedRecord.id })
        XCTAssertEqual(updated.actualMinutes, 30)
        XCTAssertEqual(updated.points, 42)
        XCTAssertNil(updated.pointsMultiplier)
        XCTAssertEqual(
            viewModel.recentRecords.filter { $0.id != ownedRecord.id }.map(\.id),
            untouchedIDs
        )
    }

    func testMockReactionCanBeSelectedChangedAndRemovedWithoutDoubleCounting() throws {
        let viewModel = AppViewModel.previewLoggedIn()
        let record = try XCTUnwrap(viewModel.recentRecords.first { !$0.likedByMe })
        let originalCount = record.likeCount

        viewModel.react(to: record, with: .laughCry)
        let laughed = try XCTUnwrap(viewModel.recentRecords.first { $0.id == record.id })
        XCTAssertEqual(laughed.myReaction, .laughCry)
        XCTAssertEqual(laughed.likeCount, originalCount + 1)
        XCTAssertEqual(laughed.reactionCounts[.laughCry], 1)

        viewModel.react(to: laughed, with: .highFive)
        let highFived = try XCTUnwrap(viewModel.recentRecords.first { $0.id == record.id })
        XCTAssertEqual(highFived.myReaction, .highFive)
        XCTAssertEqual(highFived.likeCount, originalCount + 1)
        XCTAssertEqual(highFived.reactionCounts[.laughCry], nil)
        XCTAssertEqual(highFived.reactionCounts[.highFive], 1)

        viewModel.toggleLike(highFived)
        let removed = try XCTUnwrap(viewModel.recentRecords.first { $0.id == record.id })
        XCTAssertNil(removed.myReaction)
        XCTAssertFalse(removed.likedByMe)
        XCTAssertEqual(removed.likeCount, originalCount)
    }

    func testFamilyDTOInviteAndMembershipFieldsDecode() throws {
        let data = Data(
            #"""
            {
              "id": "family-1",
              "name": "测试家庭",
              "requirePhotoProof": false,
              "timezone": "Asia/Shanghai",
              "inviteCode": "ABC12345",
              "memberRole": "OWNER",
              "status": "ACTIVE",
              "hasPremiumAccess": true
            }
            """#.utf8
        )

        let dto = try APIClient.decoder.decode(FamilyDTO.self, from: data)

        XCTAssertEqual(dto.inviteCode, "ABC12345")
        XCTAssertEqual(dto.timezone, "Asia/Shanghai")
        XCTAssertEqual(dto.memberRole, "OWNER")
        XCTAssertEqual(dto.status, "ACTIVE")
        XCTAssertEqual(dto.hasPremiumAccess, true)
    }

    func testFamilyInvitePreviewAndJoinApplicationDecode() throws {
        let previewData = Data(
            #"{"id":"family-1","name":"今日劳动观察站","inviteCode":"A5F637F7","memberCount":4,"owner":{"id":"owner-1","displayName":"用户 123456","identityLabel":"女主人","avatarKey":"avatar_01"},"currentStatus":"PENDING"}"#.utf8
        )
        let applicationData = Data(
            #"{"id":"member-2","userId":"user-2","familyId":"family-1","identityLabel":"室友","customIdentity":null,"avatarKey":"avatar_08","memberRole":"MEMBER","status":"PENDING","approvedAt":null,"approvedById":null,"createdAt":"2026-08-01T02:00:00.000Z","user":{"id":"user-2","displayName":"用户 654321"},"family":{"id":"family-1","name":"今日劳动观察站","inviteCode":"A5F637F7","memberCount":4,"owner":null,"currentStatus":"PENDING"}}"#.utf8
        )

        let preview = try APIClient.decoder.decode(FamilyInvitePreviewDTO.self, from: previewData)
        let application = try APIClient.decoder.decode(JoinApplicationDTO.self, from: applicationData)

        XCTAssertEqual(preview.owner?.identityLabel, "女主人")
        XCTAssertEqual(preview.currentStatus, "PENDING")
        XCTAssertEqual(application.family.inviteCode, "A5F637F7")
        XCTAssertEqual(application.avatarKey, "avatar_08")
        XCTAssertEqual(application.status, "PENDING")
    }

    func testMonthlyReportDecodesThemeAndCategoryStats() throws {
        let data = Data(
            #"{"familyId":"family-1","month":"2026-08","totalPoints":41,"totalRecords":2,"totalMinutes":35,"headline":"本月家务宇宙稳定运转","leaderboard":[],"themeStats":[{"themeKey":"daily","points":41,"recordCount":2}],"categoryStats":[{"category":"厨房类","points":41,"recordCount":2}],"recentRecords":[]}"#.utf8
        )

        let report = try APIClient.decoder.decode(MonthlyReportDTO.self, from: data)

        XCTAssertEqual(report.totalMinutes, 35)
        XCTAssertEqual(report.themeStats?.first?.themeKey, "daily")
        XCTAssertEqual(report.themeStats?.first?.points, 41)
        XCTAssertEqual(report.categoryStats.first?.category, "厨房类")
        XCTAssertEqual(report.categoryStats.first?.recordCount, 2)
    }

    func testAchievementSummaryDTOIncludesProgressRewardAndCapacity() throws {
        let summary = try APIClient.decoder.decode(
            AchievementSummaryDTO.self,
            from: Self.achievementSummaryData
        )

        XCTAssertEqual(summary.unlockedCount, 1)
        XCTAssertEqual(summary.totalCount, 7)
        XCTAssertEqual(summary.nextAchievement?.key, "ACTIVE_DAYS_3")
        XCTAssertEqual(summary.nextAchievement?.currentValue, 2)
        XCTAssertEqual(summary.nextAchievement?.reward?.type, "COMMON_CHORE_SLOT")
        XCTAssertEqual(summary.capacity.common.limit, 6)
        XCTAssertEqual(summary.capacity.custom.limit, 2)
    }

    func testMockAchievementsLoadAndUpdateSharingWithoutNetwork() async throws {
        let viewModel = AppViewModel.previewLoggedIn()

        await viewModel.refreshAchievements()

        XCTAssertEqual(viewModel.achievementDataState, .loaded)
        XCTAssertEqual(viewModel.achievementItems.count, 7)
        XCTAssertEqual(viewModel.nextAchievement?.key, "ACTIVE_DAYS_3")
        XCTAssertEqual(viewModel.upcomingAchievements.count, 3)
        XCTAssertEqual(viewModel.upcomingAchievements.map(\.key), [
            "ACTIVE_DAYS_3",
            "ACTIVE_DAYS_5",
            "ACTIVE_DAYS_7",
        ])
        XCTAssertEqual(viewModel.orderedAchievements.first?.key, "FIRST_RECORD")
        XCTAssertTrue(
            viewModel.orderedAchievements
                .drop(while: \.isUnlocked)
                .prefix(3)
                .allSatisfy { $0.reward != nil }
        )
        await viewModel.updateAchievementSharing(showToFamily: false)

        XCTAssertFalse(viewModel.showAchievementsToFamily)
        XCTAssertTrue(viewModel.unlockedAchievements.allSatisfy { $0.visibility == .privateOnly })
    }

    func testAPIModeLoadsAchievementSummaryAndCollection() async throws {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        var responses = Self.restoreResponses
        responses["GET /families/family-1/achievements/summary"] = Self.achievementSummaryData
        responses["GET /families/family-1/achievements/me"] = Self.achievementCollectionData
        let client = StubAPIClient(responses: responses)
        let viewModel = AppViewModel(
            apiClient: client,
            tokenStore: MockSecureTokenStore(token: "stored-token"),
            dataMode: .api,
            userDefaults: fixture.defaults
        )
        try await waitUntil { viewModel.sessionState == .authenticated }

        await viewModel.refreshAchievements()

        XCTAssertEqual(viewModel.achievementDataState, .loaded)
        XCTAssertEqual(viewModel.achievementSummary?.unlockedCount, 1)
        XCTAssertEqual(viewModel.achievementItems.count, 2)
        XCTAssertEqual(viewModel.nextAchievement?.key, "ACTIVE_DAYS_3")
        let paths = await client.requestPaths
        XCTAssertTrue(paths.contains("GET /families/family-1/achievements/summary"))
        XCTAssertTrue(paths.contains("GET /families/family-1/achievements/me"))
    }

    func testMonthlyReportCanMoveToPreviousMonthAndBack() {
        let viewModel = AppViewModel.previewLoggedIn()
        let currentMonth = viewModel.selectedReportMonth

        viewModel.selectPreviousReportMonth()

        XCTAssertNotEqual(viewModel.selectedReportMonth, currentMonth)
        XCTAssertEqual(viewModel.monthlyReport?.month, viewModel.selectedReportMonth)
        XCTAssertTrue(viewModel.canSelectNextReportMonth)

        viewModel.selectNextReportMonth()

        XCTAssertEqual(viewModel.selectedReportMonth, currentMonth)
        XCTAssertFalse(viewModel.canSelectNextReportMonth)
        XCTAssertFalse(viewModel.monthlyReport?.themeStats.isEmpty ?? true)
    }

    func testMockOwnerCanTransferOwnershipToActiveMember() async throws {
        let viewModel = AppViewModel.previewLoggedIn()
        XCTAssertEqual(viewModel.orderedActiveFamilyMembers.first?.memberRole, .owner)
        let target = try XCTUnwrap(viewModel.transferableFamilyMembers.first)

        let succeeded = await viewModel.transferOwnership(to: target)

        XCTAssertTrue(succeeded)
        XCTAssertFalse(viewModel.isCurrentUserOwner)
        XCTAssertEqual(
            viewModel.familyMembers.first(where: { $0.id == target.id })?.memberRole,
            .owner
        )
        XCTAssertEqual(viewModel.orderedActiveFamilyMembers.first?.id, target.id)
        XCTAssertEqual(
            Array(viewModel.orderedActiveFamilyMembers.dropFirst()).map(\.joinedAt),
            Array(viewModel.orderedActiveFamilyMembers.dropFirst()).map(\.joinedAt).sorted()
        )
    }

    func testMockFormerOwnerCanLeaveFamilyWithoutLoggingOut() async throws {
        let viewModel = AppViewModel.previewLoggedIn()
        let target = try XCTUnwrap(viewModel.transferableFamilyMembers.first)

        let transferred = await viewModel.transferOwnership(to: target)
        let leftFamily = await viewModel.leaveCurrentFamily()

        XCTAssertTrue(transferred)
        XCTAssertTrue(leftFamily)

        XCTAssertNil(viewModel.currentFamily)
        XCTAssertNil(viewModel.currentMembership)
        XCTAssertEqual(viewModel.rootScreen, .createFamily)
        XCTAssertNotNil(viewModel.currentUser)
    }

    func testMockOwnerMustTransferBeforeLeavingFamily() async {
        let viewModel = AppViewModel.previewLoggedIn()

        let leftFamily = await viewModel.leaveCurrentFamily()

        XCTAssertFalse(leftFamily)
        XCTAssertNotNil(viewModel.currentFamily)
        XCTAssertEqual(viewModel.errorMessage, "请先将一家之主转让给其他家庭成员，再退出当前家庭。")
    }

    func testMockOwnerCanRenameFamilyAndMemberCannot() async throws {
        let viewModel = AppViewModel.previewLoggedIn()

        let ownerRenameSucceeded = await viewModel.updateFamilyName("新的家庭名称")
        XCTAssertTrue(ownerRenameSucceeded)
        XCTAssertEqual(viewModel.currentFamily?.name, "新的家庭名称")

        let target = try XCTUnwrap(viewModel.transferableFamilyMembers.first)
        let transferSucceeded = await viewModel.transferOwnership(to: target)
        XCTAssertTrue(transferSucceeded)
        let memberRenameSucceeded = await viewModel.updateFamilyName("不应成功")
        XCTAssertFalse(memberRenameSucceeded)
        XCTAssertEqual(viewModel.currentFamily?.name, "新的家庭名称")
    }

    func testMockMemberActivityReturnsOnlySelectedMembersRecentRecords() async throws {
        let viewModel = AppViewModel.previewLoggedIn()
        let member = try XCTUnwrap(
            viewModel.familyMembers.first { $0.userId == "mock-user-xia" }
        )

        await viewModel.loadMemberActivity(for: member)

        let records = viewModel.memberActivity(for: member)
        XCTAssertFalse(records.isEmpty)
        XCTAssertTrue(records.allSatisfy { $0.creatorId == member.userId })
        XCTAssertTrue(records.allSatisfy { $0.createdAt >= Date().addingTimeInterval(-30 * 24 * 60 * 60) })
    }

    func testMockAppearanceUpdatesCurrentProfileAndHistoricalActivity() async {
        let viewModel = AppViewModel.previewLoggedIn()
        let currentUserID = viewModel.currentUser?.id

        XCTAssertFalse(viewModel.weekRecords.filter { $0.creatorId == currentUserID }.isEmpty)

        XCTAssertEqual(viewModel.monthlyLeaderIllustrationAsset, "family_avatar_action_01")

        let succeeded = await viewModel.updateAppearance(avatarKey: "avatar_13")

        XCTAssertTrue(succeeded)
        XCTAssertEqual(viewModel.currentMembership?.avatarKey, "avatar_13")
        XCTAssertEqual(
            viewModel.familyMembers.first(where: { $0.userId == viewModel.currentUser?.id })?.avatarKey,
            "avatar_13"
        )
        XCTAssertEqual(
            viewModel.weekRecords
                .filter { $0.creatorId == currentUserID }
                .map(\.avatarKey),
            Array(repeating: "avatar_13", count: viewModel.weekRecords.filter { $0.creatorId == currentUserID }.count)
        )
        XCTAssertTrue(
            viewModel.recentRecords
                .filter { $0.creatorId == currentUserID }
                .allSatisfy { $0.avatarKey == "avatar_13" }
        )
        XCTAssertEqual(FamilyIdentityOptions.actionAsset(for: "avatar_13"), "family_avatar_action_13")
        XCTAssertEqual(viewModel.monthlyLeaderIllustrationAsset, "family_avatar_action_13")
    }

    func testAPIConfigDebugDefaultUsesLocalSimulator() {
        let environment = APIConfig.resolvedEnvironment(
            defaultEnvironment: .localSimulator,
            overrideValue: nil,
            isDebug: true
        )

        XCTAssertEqual(environment, .localSimulator)
        XCTAssertEqual(environment.baseURL.absoluteString, "http://127.0.0.1:3000")
    }

    func testAPIConfigCanSelectLocalNetworkForDeviceDebugging() {
        let environment = APIConfig.resolvedEnvironment(
            defaultEnvironment: .localSimulator,
            overrideValue: "localNetwork",
            isDebug: true
        )

        XCTAssertEqual(environment, .localNetwork)
        XCTAssertFalse(APIConfig.isLoopbackURL(environment.baseURL))
    }

    func testAPIConfigReleaseDoesNotAllowLocalSimulator() {
        let environment = APIConfig.resolvedEnvironment(
            defaultEnvironment: .production,
            overrideValue: "localSimulator",
            isDebug: false
        )

        XCTAssertEqual(environment, .production)
        XCTAssertFalse(APIConfig.isLoopbackURL(environment.baseURL))
    }

    func testConnectivityErrorClassificationCoversOfflineFailures() {
        XCTAssertTrue(APIError.isConnectivityError(URLError(.notConnectedToInternet)))
        XCTAssertTrue(APIError.isConnectivityError(URLError(.cannotConnectToHost)))
        XCTAssertTrue(APIError.isConnectivityError(URLError(.timedOut)))
        XCTAssertFalse(
            APIError.isConnectivityError(
                APIError.requestFailed(statusCode: 500, message: "Server error")
            )
        )
    }

    func testEmptyStateActionSelectsRecordTab() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = makeViewModel(defaults: fixture.defaults)

        XCTAssertEqual(viewModel.selectedTab, .today)

        viewModel.showChoreSelection()

        XCTAssertEqual(viewModel.selectedTab, .record)
    }

    func testMockModeDoesNotCallNetwork() async {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = SpyAPIClient()
        let viewModel = AppViewModel(
            apiClient: client,
            dataMode: .mock,
            userDefaults: fixture.defaults
        )
        viewModel.phoneNumber = "123456"

        viewModel.mockLogin()

        let requestCount = await client.requestCount
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(viewModel.modeLabel, "Mock 模式")
        XCTAssertEqual(viewModel.accessToken, "mock-token")
        XCTAssertEqual(viewModel.sessionState, .authenticated)
    }

    func testMockLoginUsesEditableNickname() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = AppViewModel(
            forceMockData: true,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: false
        )
        viewModel.phoneNumber = "123456"
        viewModel.displayName = "小明"

        viewModel.mockLogin()

        XCTAssertEqual(viewModel.currentUser?.displayName, "小明")
        XCTAssertEqual(viewModel.currentUser?.avatarInitial, "小")
    }

    func testMockProfileCanUpdateNickname() async {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = AppViewModel(
            forceMockData: true,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: false
        )
        viewModel.phoneNumber = "123456"
        viewModel.mockLogin()

        let updated = await viewModel.updateDisplayName("新的昵称")
        XCTAssertTrue(updated)
        XCTAssertEqual(viewModel.currentUser?.displayName, "新的昵称")
        XCTAssertEqual(viewModel.displayName, "新的昵称")
    }

    func testMockCreateFamilySavesEditedNickname() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = AppViewModel(
            forceMockData: true,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: false
        )
        viewModel.phoneNumber = "123456"
        viewModel.mockLogin()
        viewModel.displayName = "创建家庭昵称"
        viewModel.familyName = "昵称测试家庭"

        viewModel.createFamily()

        XCTAssertEqual(viewModel.currentUser?.displayName, "创建家庭昵称")
        XCTAssertEqual(viewModel.familyMembers.first?.name, "创建家庭昵称")
        XCTAssertEqual(viewModel.rootScreen, .choreSetup)
    }

    func testMockJoinFamilySavesEditedNickname() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let viewModel = AppViewModel(
            forceMockData: true,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: false
        )
        viewModel.phoneNumber = "654321"
        viewModel.mockLogin()
        viewModel.showJoinFamily()
        viewModel.displayName = "加入家庭昵称"
        viewModel.joinInviteCode = MockData.invitePreview.inviteCode
        viewModel.validateJoinInviteCode()

        viewModel.submitJoinRequest()

        XCTAssertEqual(viewModel.currentUser?.displayName, "加入家庭昵称")
        XCTAssertEqual(viewModel.currentJoinApplication?.status, .pending)
        XCTAssertEqual(viewModel.rootScreen, .joinStatus)
    }

    func testAPIModeUsesInjectedAPIClient() async throws {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = SpyAPIClient()
        let tokenStore = MockSecureTokenStore()
        let viewModel = AppViewModel(
            apiClient: client,
            tokenStore: tokenStore,
            dataMode: .api,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: false
        )
        viewModel.phoneNumber = "654321"

        viewModel.mockLogin()

        for _ in 0..<50 {
            if await client.requestCount > 0 {
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }

        let paths = await client.requestPaths
        XCTAssertEqual(viewModel.modeLabel, "API 模式")
        XCTAssertEqual(paths, ["POST /auth/mock-login"])
    }

    func testKeychainStoreSavesLoadsAndDeletesToken() throws {
        let store = KeychainStore(
            service: "com.whatdidyoudo.tests.\(UUID().uuidString)",
            account: "access-token"
        )
        defer { try? store.deleteAccessToken() }

        do {
            let initialToken = try store.loadAccessToken()
            XCTAssertNil(initialToken)
            try store.saveAccessToken("keychain-test-token")
            let savedToken = try store.loadAccessToken()
            XCTAssertEqual(savedToken, "keychain-test-token")
            try store.deleteAccessToken()
            let deletedToken = try store.loadAccessToken()
            XCTAssertNil(deletedToken)
        } catch KeychainStoreError.unhandledStatus(errSecMissingEntitlement) {
            throw XCTSkip("Unsigned CI test hosts cannot access Keychain")
        }
    }

    func testAPILoginSavesAccessTokenWithoutOverwritingNickname() async throws {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = StubAPIClient(responses: Self.loginResponses)
        let tokenStore = MockSecureTokenStore()
        let viewModel = AppViewModel(
            apiClient: client,
            tokenStore: tokenStore,
            dataMode: .api,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: false
        )
        viewModel.phoneNumber = "123456"

        viewModel.mockLogin()
        try await waitUntil { tokenStore.token == "api-token" && !viewModel.isLoading }

        XCTAssertEqual(viewModel.accessToken, "api-token")
        XCTAssertEqual(tokenStore.saveCount, 1)
        XCTAssertEqual(viewModel.sessionState, .authenticated)
        XCTAssertEqual(viewModel.rootScreen, .createFamily)
        let requestBodies = await client.requestBodies
        let requestBody = try XCTUnwrap(requestBodies["POST /auth/mock-login"])
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
        XCTAssertEqual(json["phoneNumber"] as? String, "123456")
        XCTAssertNil(json["displayName"])
    }

    func testLogoutDeletesStoredToken() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let tokenStore = MockSecureTokenStore(token: "stored-token")
        let viewModel = AppViewModel(
            tokenStore: tokenStore,
            dataMode: .api,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: false
        )

        viewModel.logout()

        XCTAssertNil(tokenStore.token)
        XCTAssertEqual(tokenStore.deleteCount, 1)
        XCTAssertNil(viewModel.accessToken)
        XCTAssertEqual(viewModel.sessionState, .unauthenticated)
        XCTAssertEqual(viewModel.rootScreen, .login)
    }

    func testStoredTokenStartsInRestoringSessionState() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = StubAPIClient(responses: Self.restoreResponses)
        let tokenStore = MockSecureTokenStore(token: "restored-token")

        let viewModel = AppViewModel(
            apiClient: client,
            tokenStore: tokenStore,
            dataMode: .api,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: true
        )

        XCTAssertEqual(viewModel.sessionState, .restoringSession)
    }

    func testNoStoredTokenStartsUnauthenticated() {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = StubAPIClient(responses: Self.restoreResponses)
        let tokenStore = MockSecureTokenStore()

        let viewModel = AppViewModel(
            apiClient: client,
            tokenStore: tokenStore,
            dataMode: .api,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: true
        )

        XCTAssertEqual(viewModel.sessionState, .unauthenticated)
        XCTAssertNil(viewModel.accessToken)
        XCTAssertEqual(tokenStore.loadCount, 1)
    }

    func testStoredTokenAutomaticallyRestoresSessionAndFamilyData() async throws {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = StubAPIClient(responses: Self.restoreResponses)
        let tokenStore = MockSecureTokenStore(token: "restored-token")
        let viewModel = AppViewModel(
            apiClient: client,
            tokenStore: tokenStore,
            dataMode: .api,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: true
        )

        XCTAssertEqual(viewModel.sessionState, .restoringSession)
        try await waitUntil { viewModel.rootScreen == .home && !viewModel.isLoading }

        XCTAssertEqual(viewModel.accessToken, "restored-token")
        XCTAssertEqual(viewModel.currentUser?.displayName, "用户123456")
        XCTAssertEqual(viewModel.currentFamily?.id, "family-1")
        XCTAssertEqual(viewModel.sessionState, .authenticated)
        XCTAssertEqual(viewModel.rootScreen, .home)
        XCTAssertTrue(viewModel.hasPremiumAccess)
        XCTAssertFalse(viewModel.isOffline)
        XCTAssertNotNil(viewModel.lastSuccessfulSyncAt)
        XCTAssertEqual(tokenStore.loadCount, 1)
        let didSetToken = await client.didSetToken("restored-token")
        let requestPaths = await client.requestPaths
        XCTAssertTrue(didSetToken)
        XCTAssertTrue(requestPaths.contains("GET /auth/me"))
        XCTAssertTrue(requestPaths.contains("GET /families/me"))
        XCTAssertTrue(requestPaths.contains("GET /families/family-1/activity?range=week&weekOffset=0"))
        XCTAssertTrue(requestPaths.contains("GET /families/family-1/leaderboard?range=week&weekOffset=0"))
    }

    func testStoredTokenRestoresPendingJoinApplication() async throws {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = StubAPIClient(responses: Self.pendingRestoreResponses)
        let tokenStore = MockSecureTokenStore(token: "pending-token")
        let viewModel = AppViewModel(
            apiClient: client,
            tokenStore: tokenStore,
            dataMode: .api,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: true
        )

        try await waitUntil { viewModel.rootScreen == .joinStatus && !viewModel.isLoading }

        XCTAssertEqual(viewModel.sessionState, .authenticated)
        XCTAssertEqual(viewModel.currentJoinApplication?.status, .pending)
        XCTAssertEqual(viewModel.currentJoinApplication?.family.inviteCode, "A5F637F7")
        XCTAssertNil(viewModel.currentFamily)
    }

    func testUnauthorizedRestoreClearsSessionAndStoredToken() async {
        let fixture = makeDefaultsFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let client = StubAPIClient(
            responses: [:],
            errors: ["GET /auth/me": APIError.requestFailed(statusCode: 401, message: "Unauthorized")]
        )
        let tokenStore = MockSecureTokenStore(token: "expired-token")
        let viewModel = AppViewModel(
            apiClient: client,
            tokenStore: tokenStore,
            dataMode: .api,
            userDefaults: fixture.defaults,
            automaticallyRestoreSession: false
        )

        await viewModel.restoreSessionIfNeeded()

        XCTAssertNil(viewModel.accessToken)
        XCTAssertNil(tokenStore.token)
        XCTAssertEqual(tokenStore.deleteCount, 1)
        XCTAssertEqual(viewModel.sessionState, .unauthenticated)
        XCTAssertEqual(viewModel.rootScreen, .login)
        XCTAssertEqual(viewModel.errorMessage, "登录已失效，请重新登录。")
    }

    private func makeViewModel(defaults: UserDefaults) -> AppViewModel {
        AppViewModel(dataMode: .mock, userDefaults: defaults)
    }

    private func makeDefaultsFixture() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "WhatDidYouDoTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func makeChore(
        id: String = "test-chore",
        minutes: Int,
        points: Int
    ) -> ChoreItem {
        ChoreItem(
            id: id,
            name: "测试家务",
            category: "测试类",
            minutes: minutes,
            points: points,
            icon: "checkmark.circle",
            color: DSColor.yellow
        )
    }

    private func waitUntil(
        timeoutIterations: Int = 100,
        condition: @escaping @MainActor () async -> Bool
    ) async throws {
        for _ in 0..<timeoutIterations {
            if await condition() {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for asynchronous state")
    }

    private static let loginResponses: [String: Data] = [
        "POST /auth/mock-login": Data(
            #"{"user":{"id":"user-1","phoneNumber":"123456","displayName":"用户123456"},"accessToken":"api-token"}"#.utf8
        ),
        "GET /chores": Data("[]".utf8),
        "GET /families/me": Data("[]".utf8),
        "GET /families/join-requests/me": Data("null".utf8),
    ]

    private static let restoreResponses: [String: Data] = [
        "GET /auth/me": Data(
            #"{"id":"user-1","phoneNumber":"123456","displayName":"用户123456"}"#.utf8
        ),
        "GET /families/me": Data(
            #"[{"id":"family-1","name":"测试家庭","requirePhotoProof":false,"timezone":"Asia/Shanghai","inviteCode":"ABC12345","memberRole":"OWNER","status":"ACTIVE","hasPremiumAccess":true,"myMembership":{"id":"member-1","userId":"user-1","familyId":"family-1","identityLabel":"男主人","avatarKey":"avatar_01","memberRole":"OWNER","status":"ACTIVE","user":{"id":"user-1","phoneNumber":"123456","displayName":"用户123456"}}}]"#.utf8
        ),
        "GET /chores": Data("[]".utf8),
        "GET /families/family-1/custom-chores": Data("[]".utf8),
        "GET /families/family-1/chore-layout": Data(
            #"{"choreIds":[],"pinnedChoreIds":[],"isConfigured":false}"#.utf8
        ),
        "GET /families/family-1/activity?range=week&weekOffset=0": Data("[]".utf8),
        "GET /families/family-1/activity?range=recent": Data("[]".utf8),
        "GET /families/family-1/leaderboard?range=week&weekOffset=0": Data("[]".utf8),
        "GET /families/family-1/leaderboard?range=month": Data("[]".utf8),
        "GET /families/family-1/monthly-report": Data(
            #"{"familyId":"family-1","month":"2026-06","totalPoints":0,"totalRecords":0,"headline":"暂无记录","leaderboard":[],"categoryStats":[],"recentRecords":[]}"#.utf8
        ),
    ]

    private static let pendingRestoreResponses: [String: Data] = [
        "GET /auth/me": Data(
            #"{"id":"user-2","phoneNumber":"654321","displayName":"用户654321"}"#.utf8
        ),
        "GET /families/me": Data("[]".utf8),
        "GET /chores": Data("[]".utf8),
        "GET /families/join-requests/me": Data(
            #"{"id":"member-2","userId":"user-2","familyId":"family-1","identityLabel":"室友","customIdentity":null,"avatarKey":"avatar_08","memberRole":"MEMBER","status":"PENDING","approvedAt":null,"approvedById":null,"createdAt":"2026-08-01T02:00:00.000Z","user":{"id":"user-2","displayName":"用户 654321"},"family":{"id":"family-1","name":"今日劳动观察站","inviteCode":"A5F637F7","memberCount":4,"owner":{"id":"owner-1","displayName":"用户 123456","identityLabel":"女主人","avatarKey":"avatar_01"},"currentStatus":"PENDING"}}"#.utf8
        ),
    ]

    private static let achievementSummaryData = Data(
        #"{"familyId":"family-1","userId":"user-1","showAchievementsToFamily":true,"unlockedCount":1,"totalCount":7,"nextAchievement":{"definitionId":"definition-active-3","key":"ACTIVE_DAYS_3","nameKey":"achievement.active_days_3.none.name","descriptionKey":"achievement.active_days_3.none.description","unlockCopyKey":"achievement.active_days_3.none.unlock","track":"JOURNEY","tier":"NONE","targetValue":3,"currentValue":2,"rawCurrentValue":2,"progressStatus":"ACTIVE","isUnlocked":false,"memberAchievementId":null,"unlockedAt":null,"visibility":"FAMILY","reward":{"type":"COMMON_CHORE_SLOT","value":1}},"recentUnlocks":[],"capacity":{"common":{"base":6,"earned":0,"limit":6},"custom":{"base":2,"earned":0,"limit":2}}}"#.utf8
    )

    private static let achievementCollectionData = Data(
        #"{"familyId":"family-1","userId":"user-1","showAchievementsToFamily":true,"achievements":[{"definitionId":"definition-first","key":"FIRST_RECORD","nameKey":"achievement.first_record.none.name","descriptionKey":"achievement.first_record.none.description","unlockCopyKey":"achievement.first_record.none.unlock","track":"JOURNEY","tier":"NONE","targetValue":1,"currentValue":1,"rawCurrentValue":1,"progressStatus":"COMPLETED","isUnlocked":true,"memberAchievementId":"member-achievement-first","unlockedAt":"2026-08-11T01:00:00.000Z","visibility":"FAMILY","reward":null},{"definitionId":"definition-active-3","key":"ACTIVE_DAYS_3","nameKey":"achievement.active_days_3.none.name","descriptionKey":"achievement.active_days_3.none.description","unlockCopyKey":"achievement.active_days_3.none.unlock","track":"JOURNEY","tier":"NONE","targetValue":3,"currentValue":2,"rawCurrentValue":2,"progressStatus":"ACTIVE","isUnlocked":false,"memberAchievementId":null,"unlockedAt":null,"visibility":"FAMILY","reward":{"type":"COMMON_CHORE_SLOT","value":1}}],"capacity":{"common":{"base":6,"earned":0,"limit":6},"custom":{"base":2,"earned":0,"limit":2}},"updatedAt":"2026-08-11T01:00:00.000Z"}"#.utf8
    )
}

private actor SpyAPIClient: APIClientProtocol {
    private(set) var requestPaths: [String] = []

    var requestCount: Int {
        requestPaths.count
    }

    func setAccessToken(_ token: String?) {}

    func currentDebugSnapshot() -> APIDebugSnapshot {
        APIDebugSnapshot(lastRequestPath: requestPaths.last)
    }

    func get<Response: Decodable & Sendable>(
        _ path: String,
        queryItems: [URLQueryItem]
    ) async throws -> Response {
        requestPaths.append("GET /\(path)")
        throw SpyError.expectedRequest
    }

    func post<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody
    ) async throws -> Response {
        requestPaths.append("POST /\(path)")
        throw SpyError.expectedRequest
    }

    func post<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        requestPaths.append("POST /\(path)")
        throw SpyError.expectedRequest
    }

    func patch<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody
    ) async throws -> Response {
        requestPaths.append("PATCH /\(path)")
        throw SpyError.expectedRequest
    }

    func delete<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        requestPaths.append("DELETE /\(path)")
        throw SpyError.expectedRequest
    }
}

private final class MockSecureTokenStore: SecureTokenStore {
    var token: String?
    private(set) var saveCount = 0
    private(set) var loadCount = 0
    private(set) var deleteCount = 0

    init(token: String? = nil) {
        self.token = token
    }

    func saveAccessToken(_ token: String) throws {
        saveCount += 1
        self.token = token
    }

    func loadAccessToken() throws -> String? {
        loadCount += 1
        return token
    }

    func deleteAccessToken() throws {
        deleteCount += 1
        token = nil
    }
}

private actor StubAPIClient: APIClientProtocol {
    private let responses: [String: Data]
    private let errors: [String: Error]
    private(set) var requestPaths: [String] = []
    private(set) var requestBodies: [String: Data] = [:]
    private var accessToken: String?

    init(responses: [String: Data], errors: [String: Error] = [:]) {
        self.responses = responses
        self.errors = errors
    }

    func setAccessToken(_ token: String?) {
        accessToken = token
    }

    func didSetToken(_ token: String) -> Bool {
        accessToken == token
    }

    func currentDebugSnapshot() -> APIDebugSnapshot {
        APIDebugSnapshot(lastRequestPath: requestPaths.last)
    }

    func get<Response: Decodable & Sendable>(
        _ path: String,
        queryItems: [URLQueryItem]
    ) async throws -> Response {
        try response(method: "GET", path: path, queryItems: queryItems)
    }

    func post<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody
    ) async throws -> Response {
        requestBodies["POST /\(path)"] = try JSONEncoder().encode(body)
        return try response(method: "POST", path: path)
    }

    func post<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        try response(method: "POST", path: path)
    }

    func patch<RequestBody: Encodable & Sendable, Response: Decodable & Sendable>(
        _ path: String,
        body: RequestBody
    ) async throws -> Response {
        requestBodies["PATCH /\(path)"] = try JSONEncoder().encode(body)
        return try response(method: "PATCH", path: path)
    }

    func delete<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        try response(method: "DELETE", path: path)
    }

    private func response<Response: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = []
    ) throws -> Response {
        let requestKey = Self.requestKey(method: method, path: path, queryItems: queryItems)
        requestPaths.append(requestKey)

        if let error = errors[requestKey] ?? errors["\(method) /\(path)"] {
            throw error
        }

        let baseKey = "\(method) /\(path)"
        guard let data = responses[requestKey] ?? responses[baseKey] else {
            throw SpyError.expectedRequest
        }
        return try APIClient.decoder.decode(Response.self, from: data)
    }

    private static func requestKey(
        method: String,
        path: String,
        queryItems: [URLQueryItem]
    ) -> String {
        guard !queryItems.isEmpty else {
            return "\(method) /\(path)"
        }

        var components = URLComponents()
        components.queryItems = queryItems
        return "\(method) /\(path)?\(components.percentEncodedQuery ?? "")"
    }
}

private enum SpyError: LocalizedError {
    case expectedRequest

    var errorDescription: String? {
        "Expected test request"
    }
}
