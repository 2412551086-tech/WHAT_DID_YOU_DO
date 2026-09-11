import Foundation

enum LocalAchievementAvailability: String, Hashable {
    case local
    case requiresSync
}

enum LocalAchievementRewardStatus: String, Hashable {
    case none
    case requiresAccountConfirmation
}

struct LocalAchievementItem: Identifiable, Hashable {
    let item: AchievementItem
    let availability: LocalAchievementAvailability
    let unavailableReason: String?
    let rewardStatus: LocalAchievementRewardStatus

    var id: String { item.id }
}

struct LocalCharacterQualification: Identifiable, Hashable {
    let character: CollectibleCharacter
    let achievementUnlocked: Bool
    let requiredTier: String
    let hasPremium: Bool
    let isOwned: Bool

    var id: String { character.id }
    var canClaimOffline: Bool { false }
    var requiresAccountVerification: Bool { achievementUnlocked }
    var verificationReason: String? {
        achievementUnlocked ? "需登录验证高级会员资格与账号所有权" : nil
    }
}

struct LocalAchievementEvaluation: Hashable {
    let summary: AchievementSummary
    let evaluatedItems: [LocalAchievementItem]
    let hiddenUndiscoveredCount: Int
    let characterQualifications: [LocalCharacterQualification]
    let updatedUnlocks: [String: Date]
    let evaluatedAt: Date

    var items: [AchievementItem] { evaluatedItems.map(\.item) }
    var localItems: [AchievementItem] {
        evaluatedItems.filter { $0.availability == .local }.map(\.item)
    }
    var synchronizationRequiredItems: [LocalAchievementItem] {
        evaluatedItems.filter { $0.availability == .requiresSync }
    }
    var pendingRewardKeys: [String] {
        evaluatedItems
            .filter { $0.rewardStatus == .requiresAccountConfirmation }
            .map { $0.item.key }
    }
    var availabilityByID: [String: LocalAchievementAvailability] {
        Dictionary(uniqueKeysWithValues: evaluatedItems.map { ($0.item.id, $0.availability) })
    }

    var collection: AchievementCollection {
        AchievementCollection(
            familyId: summary.familyId,
            userId: summary.userId,
            showAchievementsToFamily: summary.showAchievementsToFamily,
            achievements: items.filter { !$0.isHidden || $0.isUnlocked },
            capacity: summary.capacity,
            updatedAt: evaluatedAt,
            undiscoveredHiddenCount: hiddenUndiscoveredCount
        )
    }
}

struct LocalAchievementDefinition: Hashable {
    let key: String
    let ownerType: String
    let track: String
    let tier: String
    let targetValue: Int
    let rule: LocalAchievementRule
    let reward: AchievementReward?
    let isHidden: Bool
    let minimumMemberCount: Int?
    let visibility: AchievementVisibility

    init(
        key: String,
        ownerType: String = "MEMBER",
        track: String,
        tier: String = "NONE",
        targetValue: Int,
        rule: LocalAchievementRule,
        reward: AchievementReward? = nil,
        isHidden: Bool = false,
        minimumMemberCount: Int? = nil,
        visibility: AchievementVisibility = .family
    ) {
        self.key = key
        self.ownerType = ownerType
        self.track = track
        self.tier = tier
        self.targetValue = targetValue
        self.rule = rule
        self.reward = reward
        self.isHidden = isHidden
        self.minimumMemberCount = minimumMemberCount
        self.visibility = visibility
    }
}

enum LocalAchievementRule: Hashable {
    case firstRecord
    case activeDays
    case streak
    case habit30
    case masteryCount(subcategories: [String] = [], themes: [String] = [], dailyLimit: Int = 3)
    case masteryDuration(subcategories: [String])
    case monthlyCategoryCoverage
    case familyRecordCount
    case familyActiveDays
    case familyAnniversary
    case hiddenDishes
    case hiddenShinyFloor
    case hiddenGuests
    case hiddenNightShift
    case hiddenEndurance
    case scene(first: String, second: String, theme: String, team: Bool)
    case requiresSync(String)
}

enum LocalAchievementEvaluator {
    private static let localUserIDPrefix = "local-user-"
    private static let localDefinitionPrefix = "local-definition-"
    private static let secondsPerDay = 86_400

    static func evaluate(
        family: LocalDraftFamily,
        asOf: Date = Date(),
        timeZone: TimeZone = .current,
        definitions: [LocalAchievementDefinition] = defaultDefinitions,
        previousUnlocks: [String: Date] = [:]
    ) -> LocalAchievementEvaluation {
        let calendar = calendar(for: timeZone)
        let records = family.records
            .filter { $0.occurredAt <= asOf }
            .map { LocalRecord(record: $0, chores: family.selectedChores, calendar: calendar) }
        let anchor = dayKey(for: asOf, calendar: calendar)
        let userID = localUserID(for: family)
        let familyID = localFamilyID(for: family)
        let ownerKey = "\(familyID):\(userID)"
        let sortedRecords = records.sorted { $0.date < $1.date }
        let masteryValues = currentMasteryValues(records: records, definitions: definitions, anchor: anchor)
        let masteryUnlockDates = firstMasteryUnlockDates(records: sortedRecords, definitions: definitions)

        var updatedUnlocks = previousUnlocks
        let results = definitions.map { definition -> LocalAchievementItem in
            let unlockIdentity = unlockIdentity(for: definition)
            let result = value(
                for: definition.rule,
                definition: definition,
                records: records,
                family: family,
                anchor: anchor,
                asOf: asOf,
                calendar: calendar,
                masteryValues: masteryValues,
                masteryUnlockDates: masteryUnlockDates
            )
            let available = result.availability
            let locallyAchieved = available == .local && result.unlockDate != nil
            let previousUnlockDate = previousUnlocks[unlockIdentity]
            let unlocked = previousUnlockDate != nil || locallyAchieved
            if unlocked {
                updatedUnlocks[unlockIdentity] = previousUnlockDate ?? result.unlockDate ?? asOf
            }
            let current = unlocked ? max(result.value, definition.targetValue) : result.value
            let item = AchievementItem(
                definitionId: definitionID(for: definition),
                key: definition.key,
                track: definition.track,
                tier: definition.tier,
                targetValue: definition.targetValue,
                currentValue: max(0, current),
                rawCurrentValue: max(0, result.value),
                progressStatus: unlocked ? "COMPLETED" : (available == .local ? "ACTIVE" : "SYNC_REQUIRED"),
                isUnlocked: unlocked,
                memberAchievementId: nil,
                unlockedAt: unlocked ? (previousUnlockDate ?? result.unlockDate ?? asOf) : nil,
                visibility: definition.isHidden ? .privateOnly : definition.visibility,
                reward: definition.reward,
                ownerType: definition.ownerType,
                ownerKey: definition.ownerType == "FAMILY" ? familyID : ownerKey,
                familyId: familyID,
                userId: userID,
                relationshipId: nil,
                familyAchievementId: nil,
                pairAchievementId: nil,
                participantUserIds: nil,
                minimumMemberCount: definition.minimumMemberCount,
                serverIsHidden: definition.isHidden
            )
            return LocalAchievementItem(
                item: item,
                availability: available,
                unavailableReason: result.reason,
                rewardStatus: unlocked && definition.reward != nil
                    ? .requiresAccountConfirmation
                    : .none
            )
        }

        let items = results.map(\.item)
        let collectionItems = items.filter { !$0.isHidden || $0.isUnlocked }
        let unlocked = collectionItems.filter(\.isUnlocked)
        let next = collectionItems.first { !$0.isUnlocked && $0.progressStatus == "ACTIVE" }
        let recent = unlocked.sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }.prefix(3)
        let hiddenCount = items.filter { $0.isHidden && !$0.isUnlocked }.count
        let summary = AchievementSummary(
            familyId: familyID,
            userId: userID,
            showAchievementsToFamily: false,
            unlockedCount: unlocked.count,
            totalCount: collectionItems.count,
            nextAchievement: next,
            recentUnlocks: Array(recent),
            capacity: AchievementCapacity(
                common: AchievementCapacityBucket(base: 8, earned: 0, limit: 8),
                custom: AchievementCapacityBucket(base: 2, earned: 0, limit: 2)
            )
        )
        let qualifications = CollectibleCharacter.all.map { character in
            LocalCharacterQualification(
                character: character,
                achievementUnlocked: silverOrGoldUnlocked(character.achievementKey, in: items),
                requiredTier: "SILVER",
                hasPremium: false,
                isOwned: false
            )
        }
        return LocalAchievementEvaluation(
            summary: summary,
            evaluatedItems: results,
            hiddenUndiscoveredCount: hiddenCount,
            characterQualifications: qualifications,
            updatedUnlocks: updatedUnlocks,
            evaluatedAt: asOf
        )
    }

    static func canClaimCharacter(
        _ character: CollectibleCharacter,
        in items: [AchievementItem],
        hasPremium: Bool,
        isOwned: Bool
    ) -> Bool {
        guard !isOwned, hasPremium else { return false }
        return silverOrGoldUnlocked(character.achievementKey, in: items)
    }

    static let defaultDefinitions: [LocalAchievementDefinition] = {
        var definitions: [LocalAchievementDefinition] = [
            .init(key: "FIRST_RECORD", track: "JOURNEY", targetValue: 1, rule: .firstRecord),
            .init(key: "ACTIVE_DAYS_3", track: "JOURNEY", targetValue: 3, rule: .activeDays, reward: AchievementReward(type: "COMMON_CHORE_SLOT", value: 1)),
            .init(key: "ACTIVE_DAYS_5", track: "JOURNEY", targetValue: 5, rule: .activeDays, reward: AchievementReward(type: "COMMON_CHORE_SLOT", value: 1)),
            .init(key: "ACTIVE_DAYS_7", track: "JOURNEY", targetValue: 7, rule: .activeDays, reward: AchievementReward(type: "CUSTOM_CHORE_SLOT", value: 1)),
            .init(key: "STREAK_7", track: "JOURNEY", targetValue: 7, rule: .streak),
            .init(key: "STREAK_14", track: "JOURNEY", targetValue: 14, rule: .streak),
            .init(key: "HABIT_30", track: "JOURNEY", targetValue: 25, rule: .habit30),
        ]
        let mastery: [(String, LocalAchievementRule, [Int])] = [
            ("MASTERY_DISHES", .masteryCount(subcategories: ["dishes"]), [5, 25, 100]),
            ("MASTERY_COOKING", .masteryCount(subcategories: ["cooking"]), [5, 25, 100]),
            ("MASTERY_TRASH", .masteryCount(subcategories: ["trash"]), [5, 25, 100]),
            ("MASTERY_PET", .masteryCount(themes: ["pet"]), [5, 25, 100]),
            ("MASTERY_CHILDCARE", .masteryCount(themes: ["childcare"]), [5, 25, 100]),
            ("MASTERY_FLOOR", .masteryCount(subcategories: ["floor"]), [5, 20, 60]),
            ("MASTERY_LAUNDRY", .masteryCount(subcategories: ["laundry"]), [5, 20, 60]),
            ("MASTERY_ROMANCE", .masteryCount(themes: ["love"]), [3, 10, 30]),
            ("MASTERY_ORGANIZE", .masteryDuration(subcategories: ["organize"]), [60, 300, 1200]),
            ("MASTERY_ALL_ROUNDER", .monthlyCategoryCoverage, [3, 5, 8]),
        ]
        for (key, rule, targets) in mastery {
            for (index, tier) in ["BRONZE", "SILVER", "GOLD"].enumerated() {
                definitions.append(.init(key: key, track: "MASTERY", tier: tier, targetValue: targets[index], rule: rule))
            }
        }
        definitions += [
            .init(key: "REACTION_FIRST", track: "BOND", targetValue: 1, rule: .requiresSync("反应记录属于云端成员数据")),
            .init(key: "REACTION_GIVEN_20", track: "BOND", targetValue: 20, rule: .requiresSync("赠送反应及接收者只能由云端确认")),
            .init(key: "REACTION_RECEIVED_10", track: "BOND", targetValue: 10, rule: .requiresSync("其他成员的反应只能由云端确认")),
            .init(key: "FAMILY_FORMED", ownerType: "FAMILY", track: "BOND", targetValue: 2, rule: .requiresSync("需要至少两名云端活跃成员"), minimumMemberCount: 2),
            .init(key: "FAMILY_ALL_IN", ownerType: "FAMILY", track: "BOND", targetValue: 1, rule: .requiresSync("需要云端成员周快照"), minimumMemberCount: 2),
            .init(key: "FAMILY_RELAY", ownerType: "FAMILY", track: "BOND", targetValue: 3, rule: .requiresSync("需要同一天的多名云端成员"), minimumMemberCount: 3),
            .init(key: "FAMILY_VISIBLE_4W", ownerType: "FAMILY", track: "BOND", targetValue: 4, rule: .requiresSync("需要四周云端资格快照"), minimumMemberCount: 2),
            .init(key: "FAMILY_FULL_SERVICE", ownerType: "FAMILY", track: "BOND", targetValue: 3, rule: .requiresSync("需要至少两名成员的当日分工"), minimumMemberCount: 2),
            .init(key: "FAMILY_CATEGORY_COVERAGE", ownerType: "FAMILY", track: "BOND", targetValue: 8, rule: .requiresSync("需要至少两名成员的月度覆盖"), minimumMemberCount: 2),
            .init(key: "PAIR_COOK_AND_CLEAN", ownerType: "PAIR", track: "BOND", targetValue: 1, rule: .requiresSync("需要两名不同云端成员"), minimumMemberCount: 2),
            .init(key: "FAMILY_ACTIVE_DAYS", ownerType: "FAMILY", track: "BOND", tier: "BRONZE", targetValue: 30, rule: .familyActiveDays),
            .init(key: "FAMILY_ACTIVE_DAYS", ownerType: "FAMILY", track: "BOND", tier: "SILVER", targetValue: 100, rule: .familyActiveDays),
            .init(key: "FAMILY_ACTIVE_DAYS", ownerType: "FAMILY", track: "BOND", tier: "GOLD", targetValue: 365, rule: .familyActiveDays),
            .init(key: "FAMILY_RECORD_COUNT", ownerType: "FAMILY", track: "BOND", tier: "BRONZE", targetValue: 100, rule: .familyRecordCount),
            .init(key: "FAMILY_RECORD_COUNT", ownerType: "FAMILY", track: "BOND", tier: "SILVER", targetValue: 500, rule: .familyRecordCount),
            .init(key: "FAMILY_RECORD_COUNT", ownerType: "FAMILY", track: "BOND", tier: "GOLD", targetValue: 1000, rule: .familyRecordCount),
            .init(key: "FAMILY_ANNIVERSARY", ownerType: "FAMILY", track: "BOND", targetValue: 365, rule: .familyAnniversary),
        ]
        definitions += [
            .init(key: "SCENE_PET_CARE", track: "MASTERY", targetValue: 1, rule: .scene(first: "premium-clean-litter", second: "pet-general-care", theme: "pet", team: false)),
            .init(key: "SCENE_PET_TEAM", track: "MASTERY", targetValue: 1, rule: .scene(first: "pet", second: "pet", theme: "pet", team: true), minimumMemberCount: 2),
            .init(key: "SCENE_CHILDCARE_STORY", track: "MASTERY", targetValue: 1, rule: .scene(first: "child-quality-time", second: "child-food-prep", theme: "childcare", team: false)),
            .init(key: "SCENE_CHILDCARE_TEAM", track: "MASTERY", targetValue: 1, rule: .scene(first: "childcare", second: "childcare", theme: "childcare", team: true), minimumMemberCount: 2),
            .init(key: "SCENE_LOVE_MOMENT", track: "MASTERY", targetValue: 1, rule: .scene(first: "love-date-plan", second: "love-cook-meal", theme: "love", team: false)),
            .init(key: "SCENE_LOVE_TEAM", track: "MASTERY", targetValue: 1, rule: .scene(first: "love-date-plan", second: "love-cook-meal", theme: "love", team: true), minimumMemberCount: 2),
            .init(key: "HIDDEN_FRESH_START", track: "HIDDEN", targetValue: 1, rule: .scene(first: "premium-change-bedding", second: "core-laundry", theme: "daily", team: false), isHidden: true, visibility: .privateOnly),
            .init(key: "HIDDEN_WARM_WELCOME", track: "HIDDEN", targetValue: 1, rule: .scene(first: "core-cook-prepare", second: "core-organize-storage", theme: "daily", team: false), isHidden: true, visibility: .privateOnly),
            .init(key: "HIDDEN_DISHES_3", track: "HIDDEN", targetValue: 3, rule: .hiddenDishes, isHidden: true, visibility: .privateOnly),
            .init(key: "HIDDEN_SHINY_FLOOR", track: "HIDDEN", targetValue: 2, rule: .hiddenShinyFloor, isHidden: true, visibility: .privateOnly),
            .init(key: "HIDDEN_GUESTS", track: "HIDDEN", targetValue: 5, rule: .hiddenGuests, isHidden: true, visibility: .privateOnly),
            .init(key: "HIDDEN_NIGHT_SHIFT", track: "HIDDEN", targetValue: 1, rule: .hiddenNightShift, isHidden: true, visibility: .privateOnly),
            .init(key: "HIDDEN_ENDURANCE", track: "HIDDEN", targetValue: 120, rule: .hiddenEndurance, isHidden: true, visibility: .privateOnly),
        ]
        return definitions
    }()

    private struct LocalRecord {
        let id: UUID
        let date: Date
        let dayKey: String
        let localHour: Int
        let catalogKey: String?
        let subcategory: String?
        let standardCategory: String?
        let themeKey: String
        let actualMinutes: Int
        let category: String
        let isCustom: Bool

        init(record: LocalDraftChoreRecord, chores: [LocalDraftChore], calendar: Calendar) {
            let chore = chores.first { $0.id == record.choreID }
            let custom = record.isCustomSnapshot ?? (chore?.source == .custom)
            let catalog = custom ? nil : (record.catalogKeySnapshot ?? chore?.catalogKey)
            let theme = record.themeKeySnapshot ?? chore?.themeKey ?? "daily"
            let category = record.category
            let taxonomy = classify(catalogKey: catalog, themeKey: theme, category: category, isCustom: custom)
            self.id = record.id
            self.date = record.occurredAt
            self.dayKey = LocalAchievementEvaluator.dayKey(for: record.occurredAt, calendar: calendar)
            self.localHour = calendar.component(.hour, from: record.occurredAt)
            self.catalogKey = catalog
            self.subcategory = taxonomy.subcategory
            self.standardCategory = taxonomy.standardCategory
            self.themeKey = theme
            self.actualMinutes = record.actualMinutes
            self.category = category
            self.isCustom = custom
        }
    }

    private struct RuleValue {
        let value: Int
        let availability: LocalAchievementAvailability
        let reason: String?
        let unlockDate: Date?

        init(value: Int, availability: LocalAchievementAvailability = .local, reason: String? = nil, unlockDate: Date? = nil) {
            self.value = value
            self.availability = availability
            self.reason = reason
            self.unlockDate = unlockDate
        }
    }

    private static func value(
        for rule: LocalAchievementRule,
        definition: LocalAchievementDefinition,
        records: [LocalRecord],
        family: LocalDraftFamily,
        anchor: String,
        asOf: Date,
        calendar: Calendar,
        masteryValues: [LocalAchievementRule: Int],
        masteryUnlockDates: [LocalAchievementRule: [Int: Date]]
    ) -> RuleValue {
        switch rule {
        case .firstRecord:
            let first = records.min { $0.date < $1.date }
            return RuleValue(value: min(1, records.count), unlockDate: first?.date)
        case .activeDays:
            let days = Set(records.map(\.dayKey))
            return metric(value: days.count, target: definition.targetValue, date: firstDateForCount(days, target: definition.targetValue, records: records))
        case .streak:
            let days = sortedEpochDays(Set(records.map(\.dayKey)))
            let longest = longestStreak(days)
            let unlock = firstStreakDate(target: definition.targetValue, records: records)
            return metric(value: currentStreak(days, anchor: anchor), target: definition.targetValue, date: unlock, achievedValue: longest)
        case .habit30:
            let days = sortedEpochDays(Set(records.map(\.dayKey)))
            let current = rollingActiveDays(days, anchor: anchor)
            let unlock = firstRollingThresholdDate(days: days, target: definition.targetValue, records: records)
            return metric(value: current, target: definition.targetValue, date: unlock, achievedValue: maxRollingActiveDays(days))
        case let .masteryCount(subcategories, themes, dailyLimit):
            let current = masteryValues[rule] ?? masteryCount(records, subcategories: subcategories, themes: themes, dailyLimit: dailyLimit)
            let unlock = masteryUnlockDates[rule]?[definition.targetValue]
            return RuleValue(value: current, unlockDate: unlock)
        case let .masteryDuration(subcategories):
            let current = masteryValues[rule] ?? records.filter { subcategories.contains($0.subcategory ?? "") && validMinutes($0.actualMinutes) }.reduce(0) { $0 + $1.actualMinutes }
            let unlock = masteryUnlockDates[rule]?[definition.targetValue]
            return RuleValue(value: current, unlockDate: unlock)
        case .monthlyCategoryCoverage:
            let month = String(anchor.prefix(7))
            let current = masteryValues[rule] ?? Set(records.filter { $0.dayKey.hasPrefix(month) }.compactMap(\.standardCategory)).count
            let unlock = masteryUnlockDates[rule]?[definition.targetValue]
            return RuleValue(value: current, unlockDate: unlock)
        case .familyRecordCount:
            let first = records.sorted { $0.date < $1.date }.dropFirst(max(0, definition.targetValue - 1)).first?.date
            return metric(value: records.count, target: definition.targetValue, date: first)
        case .familyActiveDays:
            let days = Set(records.map(\.dayKey))
            return metric(value: days.count, target: definition.targetValue, date: firstDateForCount(days, target: definition.targetValue, records: records))
        case .familyAnniversary:
            let age = calendarDayDistance(from: dayKey(for: family.createdAt, calendar: calendar), to: dayKey(for: asOf, calendar: calendar))
            let eligible = !records.isEmpty
            return RuleValue(value: age, unlockDate: eligible && age >= definition.targetValue ? calendar.date(byAdding: .day, value: definition.targetValue, to: family.createdAt) : nil)
        case .hiddenDishes:
            let matchingDays = Dictionary(grouping: records.filter { $0.subcategory == "dishes" }, by: \.dayKey)
            let best = matchingDays.max { $0.value.count < $1.value.count }
            let count = best?.value.count ?? 0
            let date = count >= definition.targetValue ? best?.value.sorted { $0.date < $1.date }.dropFirst(definition.targetValue - 1).first?.date : nil
            let current = records.filter { $0.dayKey == anchor && $0.subcategory == "dishes" }.count
            return RuleValue(value: max(current, count), unlockDate: date)
        case .hiddenShinyFloor:
            let matchingDays = Dictionary(grouping: records, by: \.dayKey)
            let qualifyingDay = matchingDays.first { _, day in
                let keys = Set(day.compactMap(\.catalogKey))
                return keys.contains("core-sweep-vacuum") && keys.contains("core-mop-floor")
            }
            let value = qualifyingDay == nil ? 0 : 2
            return RuleValue(value: value, unlockDate: qualifyingDay?.value.map(\.date).min())
        case .hiddenGuests:
            let matchingDays = Dictionary(grouping: records, by: \.dayKey)
            let best = matchingDays.max { left, right in
                Set(left.value.compactMap { $0.standardCategory ?? $0.subcategory }).count < Set(right.value.compactMap { $0.standardCategory ?? $0.subcategory }).count
            }
            let bestValue = best.map { Set($0.value.compactMap { $0.standardCategory ?? $0.subcategory }).count } ?? 0
            let current = Set(records.filter { $0.dayKey == anchor }.compactMap { $0.standardCategory ?? $0.subcategory }).count
            return RuleValue(value: max(current, bestValue), unlockDate: bestValue >= definition.targetValue ? best?.value.map(\.date).min() : nil)
        case .hiddenNightShift:
            let matching = records.filter {
                (0..<5).contains($0.localHour) &&
                [$0.standardCategory, $0.subcategory, $0.category]
                    .contains { ["care", "childcare", "照护", "照顾"].contains($0 ?? "") }
            }
            let current = matching.contains { $0.dayKey == anchor } ? 1 : 0
            return RuleValue(value: max(current, matching.isEmpty ? 0 : 1), unlockDate: matching.map(\.date).min())
        case .hiddenEndurance:
            let matching = records.filter { $0.actualMinutes >= 120 }
            let maximum = matching.map(\.actualMinutes).max() ?? 0
            return RuleValue(value: maximum, unlockDate: matching.min { $0.date < $1.date }?.date)
        case let .scene(first, second, theme, team):
            guard !team else { return RuleValue(value: 0, availability: .requiresSync, reason: "需要两名不同云端成员") }
            let enabledThemes = Set(["daily"] + family.selectedChores.map(\.themeKey))
            guard enabledThemes.contains(theme) else { return RuleValue(value: 0, availability: .local) }
            let matching = records.filter { !$0.isCustom && $0.catalogKey != nil }
            let days = Set(matching.map(\.dayKey))
            for day in days.sorted() {
                let dayRecords = matching.filter { $0.dayKey == day }
                if dayRecords.contains(where: { $0.catalogKey == first }) && dayRecords.contains(where: { $0.catalogKey == second }) {
                    return RuleValue(value: 1, unlockDate: dayRecords.map(\.date).min())
                }
            }
            return RuleValue(value: 0)
        case let .requiresSync(reason):
            return RuleValue(value: 0, availability: .requiresSync, reason: reason)
        }
    }

    private static func metric(value: Int, target: Int, date: Date?, achievedValue: Int? = nil) -> RuleValue {
        let achieved = achievedValue ?? value
        return RuleValue(value: value, unlockDate: achieved >= target ? date : nil)
    }

    private static func masteryCount(_ records: [LocalRecord], subcategories: [String], themes: [String], dailyLimit: Int) -> Int {
        let matching = records.filter { record in
            if !themes.isEmpty { return themes.contains(record.themeKey) }
            return subcategories.contains(record.subcategory ?? "")
        }
        var contributionByDay = [String: Int]()
        for record in matching where record.subcategory != nil {
            let key = "\(record.dayKey):\(record.subcategory!)"
            contributionByDay[key] = min(max(1, dailyLimit), (contributionByDay[key] ?? 0) + 1)
        }
        return contributionByDay.values.reduce(0, +)
    }

    private static func firstMasteryUnlockDates(
        records: [LocalRecord],
        definitions: [LocalAchievementDefinition]
    ) -> [LocalAchievementRule: [Int: Date]] {
        let groups = Dictionary(grouping: definitions.filter { isMasteryRule($0.rule) }, by: \.rule)
        var datesByRule: [LocalAchievementRule: [Int: Date]] = [:]
        for (rule, definitions) in groups {
            datesByRule[rule] = firstMasteryUnlockDates(
                records: records,
                rule: rule,
                targets: Set(definitions.map(\.targetValue))
            )
        }
        return datesByRule
    }

    private static func firstMasteryUnlockDates(
        records: [LocalRecord],
        rule: LocalAchievementRule,
        targets: Set<Int>
    ) -> [Int: Date] {
        var remaining = Set(targets.filter { $0 > 0 })
        var dates: [Int: Date] = [:]
        guard !remaining.isEmpty else { return dates }

        func capture(_ value: Int, at date: Date) {
            for target in remaining where value >= target {
                dates[target] = date
            }
            remaining.subtract(dates.keys)
        }

        switch rule {
        case let .masteryCount(subcategories, themes, dailyLimit):
            let matching = records.filter { record in
                if !themes.isEmpty { return themes.contains(record.themeKey) }
                return subcategories.contains(record.subcategory ?? "")
            }
            let limit = max(1, dailyLimit)
            var contributionByDayAndSubcategory: [String: Int] = [:]
            var total = 0
            for record in matching {
                guard let subcategory = record.subcategory else { continue }
                let key = "\(record.dayKey):\(subcategory)"
                let previous = contributionByDayAndSubcategory[key] ?? 0
                let contribution = min(limit, previous + 1)
                guard contribution > previous else { continue }
                contributionByDayAndSubcategory[key] = contribution
                total += contribution - previous
                capture(total, at: record.date)
                if remaining.isEmpty { break }
            }
        case let .masteryDuration(subcategories):
            var total = 0
            for record in records where subcategories.contains(record.subcategory ?? "") && validMinutes(record.actualMinutes) {
                total += record.actualMinutes
                capture(total, at: record.date)
                if remaining.isEmpty { break }
            }
        case .monthlyCategoryCoverage:
            var categoriesByMonth: [String: Set<String>] = [:]
            for record in records {
                guard let category = record.standardCategory else { continue }
                let month = String(record.dayKey.prefix(7))
                categoriesByMonth[month, default: []].insert(category)
                capture(categoriesByMonth[month, default: []].count, at: record.date)
                if remaining.isEmpty { break }
            }
        default:
            break
        }
        return dates
    }

    private static func isMasteryRule(_ rule: LocalAchievementRule) -> Bool {
        switch rule {
        case .masteryCount, .masteryDuration, .monthlyCategoryCoverage: true
        default: false
        }
    }

    private static func currentMasteryValues(
        records: [LocalRecord],
        definitions: [LocalAchievementDefinition],
        anchor: String
    ) -> [LocalAchievementRule: Int] {
        let rules = Set(definitions.map(\.rule).filter(isMasteryRule))
        var values: [LocalAchievementRule: Int] = [:]
        for rule in rules {
            switch rule {
            case let .masteryCount(subcategories, themes, dailyLimit):
                values[rule] = masteryCount(records, subcategories: subcategories, themes: themes, dailyLimit: dailyLimit)
            case let .masteryDuration(subcategories):
                values[rule] = records
                    .filter { subcategories.contains($0.subcategory ?? "") && validMinutes($0.actualMinutes) }
                    .reduce(0) { $0 + $1.actualMinutes }
            case .monthlyCategoryCoverage:
                let month = String(anchor.prefix(7))
                values[rule] = Set(records.filter { $0.dayKey.hasPrefix(month) }.compactMap(\.standardCategory)).count
            default:
                break
            }
        }
        return values
    }

    private static func firstDateForCount(_ days: Set<String>, target: Int, records: [LocalRecord]) -> Date? {
        guard target > 0 else { return records.map(\.date).min() }
        let ordered = records.sorted { $0.date < $1.date }
        var seen = Set<String>()
        for record in ordered where seen.insert(record.dayKey).inserted {
            if seen.count >= target { return record.date }
        }
        return nil
    }

    private static func firstStreakDate(target: Int, records: [LocalRecord]) -> Date? {
        guard target > 0 else { return records.map(\.date).min() }
        let days = sortedEpochDays(Set(records.map(\.dayKey)))
        var running = 0
        for (index, day) in days.enumerated() {
            running = index > 0 && day == days[index - 1] + 1 ? running + 1 : 1
            if running >= target { return records.filter { epochDay(for: $0.dayKey) == day }.map(\.date).min() }
        }
        return nil
    }

    private static func firstRollingThresholdDate(days: [Int], target: Int, records: [LocalRecord]) -> Date? {
        guard target > 0 else { return nil }
        for day in days where rollingActiveDays(days, anchor: dateKey(forEpochDay: day)) >= target {
            return records.filter { epochDay(for: $0.dayKey) == day }.map(\.date).min()
        }
        return nil
    }

    private static func maxRollingActiveDays(_ days: [Int]) -> Int {
        days.map { rollingActiveDays(days, anchor: dateKey(forEpochDay: $0)) }.max() ?? 0
    }

    private static func sortedEpochDays(_ keys: Set<String>) -> [Int] { keys.map(epochDay(for:)).sorted() }

    private static func longestStreak(_ days: [Int]) -> Int {
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var running = 1
        for index in 1..<days.count {
            running = days[index] == days[index - 1] + 1 ? running + 1 : 1
            longest = max(longest, running)
        }
        return longest
    }

    private static func currentStreak(_ days: [Int], anchor: String) -> Int {
        let anchorDay = epochDay(for: anchor)
        let latest = days.contains(anchorDay) ? anchorDay : days.contains(anchorDay - 1) ? anchorDay - 1 : nil
        guard var day = latest else { return 0 }
        var streak = 0
        let set = Set(days)
        while set.contains(day) { streak += 1; day -= 1 }
        return streak
    }

    private static func rollingActiveDays(_ days: [Int], anchor: String) -> Int {
        let day = epochDay(for: anchor)
        return days.filter { $0 >= day - 29 && $0 <= day }.count
    }

    private static func calendarDayDistance(from start: String, to end: String) -> Int { max(0, epochDay(for: end) - epochDay(for: start)) }

    private static func validMinutes(_ value: Int) -> Bool { (1...180).contains(value) }

    private static func classify(catalogKey: String?, themeKey: String, category: String, isCustom: Bool) -> (subcategory: String?, standardCategory: String?) {
        let categories = ["烹饪": "cooking", "清洁": "cleaning", "洗护": "laundry", "整理": "organize", "照顾": "care", "家庭事务": "household"]
        if isCustom {
            let standard = categories[category]
            return (standard, standard)
        }
        let catalog: [String: String] = [
            "core-cook-prepare": "cooking", "core-dishes-cleanup": "dishes", "core-laundry": "laundry", "core-fold-clothes": "laundry",
            "core-sweep-vacuum": "floor", "core-mop-floor": "floor", "core-organize-storage": "organize", "core-trash-recycling": "trash",
            "premium-change-bedding": "laundry", "daily-make-bed": "organize"
        ]
        let subcategory = catalog[catalogKey ?? ""] ?? (["pet", "childcare", "love"].contains(themeKey) ? themeKey : nil)
        return (subcategory, subcategory ?? categories[category])
    }

    private static func calendar(for timeZone: TimeZone) -> Calendar { var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone; return calendar }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static func epochDay(for key: String) -> Int {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let date = utcCalendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return 0 }
        return Int(floor(date.timeIntervalSince1970 / Double(secondsPerDay)))
    }

    private static func dateKey(forEpochDay day: Int) -> String {
        let date = Date(timeIntervalSince1970: Double(day * secondsPerDay))
        let components = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func localUserID(for family: LocalDraftFamily) -> String {
        localUserIDPrefix + family.id.uuidString.lowercased()
    }

    private static func localFamilyID(for family: LocalDraftFamily) -> String {
        "local-family-\(family.id.uuidString.lowercased())"
    }

    private static func definitionID(for definition: LocalAchievementDefinition) -> String {
        "\(localDefinitionPrefix)\(definition.key)-\(definition.tier)"
    }

    private static func unlockIdentity(for definition: LocalAchievementDefinition) -> String {
        "\(definition.key):\(definition.tier)"
    }

    private static func silverOrGoldUnlocked(_ key: String, in items: [AchievementItem]) -> Bool {
        items.contains { $0.key == key && ["SILVER", "GOLD"].contains($0.tier) && $0.isUnlocked }
    }
}
