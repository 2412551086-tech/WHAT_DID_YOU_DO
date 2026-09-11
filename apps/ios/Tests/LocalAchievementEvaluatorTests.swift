import Foundation
import SwiftUI
import XCTest
@testable import WhatDidYouDo

@MainActor
final class LocalAchievementEvaluatorTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testJourneyUsesRealDatesForActiveDaysStreakAndRollingWindow() {
        let start = date(year: 2026, month: 1, day: 1)
        let records = (0..<7).map { offset in
            record(id: offset, choreID: "cook", occurredAt: calendar.date(byAdding: .day, value: offset, to: start)!)
        }
        let evaluation = evaluate(chores: [chore(id: "cook", catalogKey: "core-cook-prepare")], records: records, asOf: date(year: 2026, month: 1, day: 7))

        XCTAssertTrue(item("ACTIVE_DAYS_7", in: evaluation).isUnlocked)
        XCTAssertEqual(item("ACTIVE_DAYS_7", in: evaluation).rawCurrentValue, 7)
        XCTAssertTrue(item("STREAK_7", in: evaluation).isUnlocked)
        XCTAssertEqual(item("HABIT_30", in: evaluation).rawCurrentValue, 7)
        XCTAssertEqual(item("STREAK_7", in: evaluation).unlockedAt, records[6].occurredAt)
        XCTAssertTrue(evaluation.pendingRewardKeys.contains("ACTIVE_DAYS_3"))
        XCTAssertTrue(evaluation.pendingRewardKeys.contains("ACTIVE_DAYS_5"))
        XCTAssertTrue(evaluation.pendingRewardKeys.contains("ACTIVE_DAYS_7"))
        XCTAssertEqual(evaluation.summary.capacity.common.base, 8)
        XCTAssertEqual(evaluation.summary.capacity.common.earned, 0)
        XCTAssertEqual(evaluation.summary.capacity.common.limit, 8)
        XCTAssertEqual(evaluation.summary.capacity.custom.base, 2)
        XCTAssertEqual(evaluation.summary.capacity.custom.earned, 0)
        XCTAssertEqual(evaluation.summary.capacity.custom.limit, 2)
    }

    func testPreviouslyUnlockedAchievementsStayUnlockedAfterRecordsAreDeleted() {
        let start = date(year: 2026, month: 1, day: 1)
        let chores = [chore(id: "cook", catalogKey: "core-cook-prepare")]
        let records = (0..<7).map { offset in
            record(id: offset, choreID: "cook", occurredAt: calendar.date(byAdding: .day, value: offset, to: start)!)
        }
        let beforeDeletion = evaluate(chores: chores, records: records, asOf: date(year: 2026, month: 1, day: 7))
        XCTAssertEqual(beforeDeletion.updatedUnlocks["ACTIVE_DAYS_7:NONE"], item("ACTIVE_DAYS_7", in: beforeDeletion).unlockedAt)
        let afterDeletion = evaluate(
            chores: chores,
            records: [],
            asOf: date(year: 2026, month: 1, day: 8),
            previousUnlocks: beforeDeletion.updatedUnlocks
        )

        let activeDays = item("ACTIVE_DAYS_7", in: afterDeletion)
        let firstRecord = item("FIRST_RECORD", in: afterDeletion)
        XCTAssertTrue(activeDays.isUnlocked)
        XCTAssertEqual(activeDays.unlockedAt, item("ACTIVE_DAYS_7", in: beforeDeletion).unlockedAt)
        XCTAssertEqual(activeDays.rawCurrentValue, 0)
        XCTAssertTrue(firstRecord.isUnlocked)
        XCTAssertEqual(afterDeletion.updatedUnlocks, beforeDeletion.updatedUnlocks)
    }

    func testHistoricalThresholdsUseFirstUnlockDateAfterCurrentStreakWindowBreaks() {
        let january = date(year: 2026, month: 1, day: 1)
        let february = date(year: 2026, month: 2, day: 1)
        let chores = [
            chore(id: "cook", catalogKey: "core-cook-prepare"),
            chore(id: "dishes", catalogKey: "core-dishes-cleanup"),
            chore(id: "floor", catalogKey: "core-sweep-vacuum"),
        ]
        var records = (0..<25).map { offset in
            record(id: offset, choreID: "cook", occurredAt: calendar.date(byAdding: .day, value: offset, to: january)!)
        }
        records += [
            record(id: 30, choreID: "cook", occurredAt: february),
            record(id: 31, choreID: "dishes", occurredAt: calendar.date(byAdding: .minute, value: 1, to: february)!),
            record(id: 32, choreID: "floor", occurredAt: calendar.date(byAdding: .minute, value: 2, to: february)!),
        ]
        let evaluation = evaluate(chores: chores, records: records, asOf: date(year: 2026, month: 4, day: 10))

        let streak = item("STREAK_7", in: evaluation)
        let habit = item("HABIT_30", in: evaluation)
        let coverage = item("MASTERY_ALL_ROUNDER", tier: "BRONZE", in: evaluation)
        XCTAssertEqual(streak.rawCurrentValue, 0)
        XCTAssertTrue(streak.isUnlocked)
        XCTAssertEqual(habit.rawCurrentValue, 0)
        XCTAssertTrue(habit.isUnlocked)
        XCTAssertEqual(coverage.rawCurrentValue, 0)
        XCTAssertTrue(coverage.isUnlocked)
        XCTAssertNotNil(streak.unlockedAt)
        XCTAssertNotNil(habit.unlockedAt)
        XCTAssertNotNil(coverage.unlockedAt)
    }

    func testAnniversaryDoesNotUnlockWithoutAnyRecordHistory() {
        let family = LocalDraftFamily(
            createdAt: date(year: 2025, month: 1, day: 1),
            selectedChores: [],
            records: []
        )
        let evaluation = LocalAchievementEvaluator.evaluate(
            family: family,
            asOf: date(year: 2026, month: 1, day: 1),
            timeZone: calendar.timeZone
        )

        let anniversary = item("FAMILY_ANNIVERSARY", in: evaluation)
        XCTAssertEqual(anniversary.rawCurrentValue, 365)
        XCTAssertFalse(anniversary.isUnlocked)
        XCTAssertNil(anniversary.unlockedAt)
    }

    func testFutureRecordsAreExcludedFromAsOfMetrics() {
        let start = date(year: 2026, month: 6, day: 1)
        let records = [
            record(id: 1, choreID: "cook", occurredAt: calendar.date(byAdding: .hour, value: 10, to: start)!),
            record(id: 2, choreID: "cook", occurredAt: calendar.date(byAdding: .day, value: 1, to: start)!),
        ]
        let evaluation = evaluate(
            chores: [chore(id: "cook", catalogKey: "core-cook-prepare")],
            records: records,
            asOf: calendar.date(byAdding: .hour, value: 12, to: start)!
        )

        XCTAssertEqual(item("FIRST_RECORD", in: evaluation).rawCurrentValue, 1)
        XCTAssertEqual(item("ACTIVE_DAYS_3", in: evaluation).rawCurrentValue, 1)
    }

    func testRecordTaxonomySnapshotsSurviveRemovedSelectedChore() {
        let start = date(year: 2026, month: 7, day: 1)
        var records = (0..<3).map { index in
            record(
                id: index,
                choreID: "removed-trash",
                occurredAt: start,
                catalogKeySnapshot: "core-trash-recycling",
                themeKeySnapshot: "daily",
                isCustomSnapshot: false
            )
        }
        records += (0..<2).map { index in
            record(
                id: 10 + index,
                choreID: "removed-trash",
                occurredAt: calendar.date(byAdding: .day, value: 1, to: start)!,
                catalogKeySnapshot: "core-trash-recycling",
                themeKeySnapshot: "daily",
                isCustomSnapshot: false
            )
        }
        let evaluation = evaluate(chores: [], records: records, asOf: calendar.date(byAdding: .day, value: 1, to: start)!)

        XCTAssertTrue(item("MASTERY_TRASH", tier: "BRONZE", in: evaluation).isUnlocked)
        XCTAssertEqual(item("MASTERY_TRASH", tier: "BRONZE", in: evaluation).rawCurrentValue, 5)
    }

    func testLocalAchievementIDsMatchTheIDsUsedWhenApplyingTheLocalDraft() {
        let id = UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")!
        let family = LocalDraftFamily(id: id)
        let evaluation = LocalAchievementEvaluator.evaluate(family: family, asOf: date(year: 2026, month: 1, day: 1), timeZone: calendar.timeZone)
        let expectedFamilyID = "local-family-\(id.uuidString.lowercased())"
        let expectedUserID = "local-user-\(id.uuidString.lowercased())"

        XCTAssertEqual(evaluation.summary.familyId, expectedFamilyID)
        XCTAssertEqual(evaluation.summary.userId, expectedUserID)
        XCTAssertEqual(evaluation.items.first?.ownerKey, "\(expectedFamilyID):\(expectedUserID)")
    }

    func testMasteryCountAppliesBackendDailyContributionLimitAndDurationValidation() {
        let firstDay = date(year: 2026, month: 2, day: 1)
        var records = (0..<5).map { index in
            record(id: index, choreID: "dishes", actualMinutes: 15, occurredAt: firstDay)
        }
        records += (0..<2).map { index in
            record(id: 10 + index, choreID: "dishes", actualMinutes: 15, occurredAt: calendar.date(byAdding: .day, value: 1, to: firstDay)!)
        }
        records += [
            record(id: 20, choreID: "organize", actualMinutes: 100, occurredAt: firstDay),
            record(id: 21, choreID: "organize", actualMinutes: 100, occurredAt: firstDay),
            record(id: 22, choreID: "organize", actualMinutes: 200, occurredAt: firstDay),
        ]
        let evaluation = evaluate(
            chores: [
                chore(id: "dishes", catalogKey: "core-dishes-cleanup"),
                chore(id: "organize", catalogKey: "core-organize-storage"),
            ],
            records: records,
            asOf: calendar.date(byAdding: .day, value: 1, to: firstDay)!
        )

        let dishes = item("MASTERY_DISHES", tier: "BRONZE", in: evaluation)
        XCTAssertTrue(dishes.isUnlocked)
        XCTAssertEqual(dishes.rawCurrentValue, 5)
        XCTAssertEqual(item("MASTERY_ORGANIZE", tier: "BRONZE", in: evaluation).rawCurrentValue, 200)
        XCTAssertFalse(item("MASTERY_ORGANIZE", tier: "SILVER", in: evaluation).isUnlocked)
    }

    func testHiddenAchievementScansHistoricalLocalRecordsAndRemainsPrivate() {
        let day = date(year: 2026, month: 3, day: 3)
        let records = (0..<3).map { index in
            record(id: index, choreID: "dishes", occurredAt: calendar.date(byAdding: .minute, value: index, to: day)!)
        }
        let evaluation = evaluate(
            chores: [chore(id: "dishes", catalogKey: "core-dishes-cleanup")],
            records: records,
            asOf: date(year: 2026, month: 3, day: 10)
        )
        let hidden = item("HIDDEN_DISHES_3", in: evaluation)

        XCTAssertTrue(hidden.isUnlocked)
        XCTAssertEqual(hidden.visibility, .privateOnly)
        XCTAssertEqual(evaluation.hiddenUndiscoveredCount, 6)
        XCTAssertFalse(evaluation.collection.achievements.contains { $0.key == "HIDDEN_DISHES_3" && !$0.isUnlocked })
    }

    func testCloudOnlyRulesStayLockedAndExplainSynchronizationRequirement() {
        let evaluation = evaluate(chores: [], records: [], asOf: date(year: 2026, month: 4, day: 1))
        let keys = ["REACTION_FIRST", "FAMILY_FORMED", "PAIR_COOK_AND_CLEAN", "SCENE_PET_TEAM"]

        for key in keys {
            let result = try! XCTUnwrap(evaluation.evaluatedItems.first { $0.item.key == key })
            XCTAssertEqual(result.availability, .requiresSync, key)
            XCTAssertFalse(result.item.isUnlocked, key)
            XCTAssertEqual(result.item.progressStatus, "SYNC_REQUIRED", key)
            XCTAssertNotNil(result.unavailableReason, key)
        }
    }

    func testCharacterQualificationIsPureAndRequiresSilverOrGoldAndExplicitInputs() {
        let start = date(year: 2026, month: 5, day: 1)
        let records = (0..<25).map { index in
            record(
                id: index,
                choreID: "trash",
                occurredAt: calendar.date(byAdding: .day, value: index / 3, to: start)!
            )
        }
        let evaluation = evaluate(chores: [chore(id: "trash", catalogKey: "core-trash-recycling")], records: records, asOf: calendar.date(byAdding: .day, value: 8, to: start)!)
        let character = try! XCTUnwrap(CollectibleCharacter.all.first { $0.achievementKey == "MASTERY_TRASH" })

        let qualification = try! XCTUnwrap(evaluation.characterQualifications.first { $0.character.key == character.key })
        XCTAssertTrue(qualification.achievementUnlocked)
        XCTAssertFalse(qualification.hasPremium)
        XCTAssertFalse(qualification.canClaimOffline)
        XCTAssertTrue(qualification.requiresAccountVerification)
        XCTAssertNotNil(qualification.verificationReason)
        XCTAssertTrue(LocalAchievementEvaluator.canClaimCharacter(character, in: evaluation.items, hasPremium: true, isOwned: false))
        XCTAssertFalse(LocalAchievementEvaluator.canClaimCharacter(character, in: evaluation.items, hasPremium: false, isOwned: false))
        XCTAssertFalse(LocalAchievementEvaluator.canClaimCharacter(character, in: evaluation.items, hasPremium: true, isOwned: true))
    }

    private func evaluate(
        chores: [LocalDraftChore],
        records: [LocalDraftChoreRecord],
        asOf: Date,
        previousUnlocks: [String: Date] = [:]
    ) -> LocalAchievementEvaluation {
        let family = LocalDraftFamily(createdAt: records.map(\.occurredAt).min() ?? asOf, selectedChores: chores, records: records)
        return LocalAchievementEvaluator.evaluate(
            family: family,
            asOf: asOf,
            timeZone: calendar.timeZone,
            previousUnlocks: previousUnlocks
        )
    }

    private func item(_ key: String, tier: String? = nil, in evaluation: LocalAchievementEvaluation) -> AchievementItem {
        try! XCTUnwrap(evaluation.items.first { $0.key == key && (tier == nil || $0.tier == tier) })
    }

    private func chore(id: String, catalogKey: String, themeKey: String = "daily") -> LocalDraftChore {
        LocalDraftChore(chore: ChoreItem(
            id: id,
            catalogKey: catalogKey,
            name: id,
            category: "清洁",
            minutes: 15,
            points: 1,
            icon: "circle",
            color: .yellow,
            themeKey: themeKey
        ))
    }

    private func record(
        id: Int,
        choreID: String,
        actualMinutes: Int = 15,
        occurredAt: Date,
        catalogKeySnapshot: String? = nil,
        themeKeySnapshot: String? = nil,
        isCustomSnapshot: Bool? = nil
    ) -> LocalDraftChoreRecord {
        LocalDraftChoreRecord(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id + 1))!,
            choreID: choreID,
            choreName: choreID,
            category: "清洁",
            standardMinutes: 15,
            defaultPoints: 1,
            icon: "circle",
            actualMinutes: actualMinutes,
            points: 1,
            pointsMultiplier: nil,
            note: "",
            occurredAt: occurredAt,
            catalogKeySnapshot: catalogKeySnapshot,
            themeKeySnapshot: themeKeySnapshot,
            isCustomSnapshot: isCustomSnapshot
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
