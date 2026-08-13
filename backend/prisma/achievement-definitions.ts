import {
  AchievementOwnerType,
  AchievementRuleType,
  AchievementTier,
  AchievementTrack,
  AchievementVisibility,
  AchievementWindowType,
  Prisma,
} from "@prisma/client";

export type AchievementDefinitionSeed = {
  key: string;
  nameKey: string;
  descriptionKey: string;
  unlockCopyKey: string;
  ownerType: AchievementOwnerType;
  track: AchievementTrack;
  tier: AchievementTier;
  ruleType: AchievementRuleType;
  ruleConfigJson: Prisma.InputJsonValue;
  targetValue: number;
  windowType: AchievementWindowType;
  windowSize?: number;
  maxDailyContribution?: number;
  minimumMemberCount?: number;
  rewardConfigJson?: Prisma.InputJsonValue;
  defaultVisibility: AchievementVisibility;
  definitionVersion: number;
  isHidden: boolean;
  isActive: boolean;
};

type DefinitionInput = Omit<
  AchievementDefinitionSeed,
  | "nameKey"
  | "descriptionKey"
  | "unlockCopyKey"
  | "tier"
  | "windowType"
  | "defaultVisibility"
  | "definitionVersion"
  | "isHidden"
  | "isActive"
> &
  Partial<
    Pick<
      AchievementDefinitionSeed,
      "tier" | "windowType" | "defaultVisibility" | "definitionVersion" | "isHidden" | "isActive"
    >
  >;

function definition(input: DefinitionInput): AchievementDefinitionSeed {
  const tier = input.tier ?? AchievementTier.NONE;
  const localizationStem = `achievement.${input.key.toLowerCase()}.${tier.toLowerCase()}`;

  return {
    ...input,
    tier,
    nameKey: `${localizationStem}.name`,
    descriptionKey: `${localizationStem}.description`,
    unlockCopyKey: `${localizationStem}.unlock`,
    windowType: input.windowType ?? AchievementWindowType.LIFETIME,
    defaultVisibility: input.defaultVisibility ?? AchievementVisibility.FAMILY,
    definitionVersion: input.definitionVersion ?? 1,
    isHidden: input.isHidden ?? false,
    isActive: input.isActive ?? true,
  };
}

const journeyDefinitions: AchievementDefinitionSeed[] = [
  definition({
    key: "FIRST_RECORD",
    ownerType: AchievementOwnerType.MEMBER,
    track: AchievementTrack.JOURNEY,
    ruleType: AchievementRuleType.FIRST_EVENT,
    ruleConfigJson: { eventType: "CHORE_CREATED" },
    targetValue: 1,
  }),
  definition({
    key: "ACTIVE_DAYS_3",
    ownerType: AchievementOwnerType.MEMBER,
    track: AchievementTrack.JOURNEY,
    ruleType: AchievementRuleType.ACTIVE_DAYS,
    ruleConfigJson: { distinctFamilyLocalDays: true },
    targetValue: 3,
    rewardConfigJson: { type: "COMMON_CHORE_SLOT", value: 1 },
  }),
  definition({
    key: "ACTIVE_DAYS_5",
    ownerType: AchievementOwnerType.MEMBER,
    track: AchievementTrack.JOURNEY,
    ruleType: AchievementRuleType.ACTIVE_DAYS,
    ruleConfigJson: { distinctFamilyLocalDays: true },
    targetValue: 5,
    rewardConfigJson: { type: "COMMON_CHORE_SLOT", value: 1 },
  }),
  definition({
    key: "ACTIVE_DAYS_7",
    ownerType: AchievementOwnerType.MEMBER,
    track: AchievementTrack.JOURNEY,
    ruleType: AchievementRuleType.ACTIVE_DAYS,
    ruleConfigJson: { distinctFamilyLocalDays: true },
    targetValue: 7,
    rewardConfigJson: { type: "CUSTOM_CHORE_SLOT", value: 1 },
  }),
  definition({
    key: "STREAK_7",
    ownerType: AchievementOwnerType.MEMBER,
    track: AchievementTrack.JOURNEY,
    ruleType: AchievementRuleType.STREAK,
    ruleConfigJson: { strictConsecutiveFamilyLocalDays: true },
    targetValue: 7,
  }),
  definition({
    key: "STREAK_14",
    ownerType: AchievementOwnerType.MEMBER,
    track: AchievementTrack.JOURNEY,
    ruleType: AchievementRuleType.STREAK,
    ruleConfigJson: { strictConsecutiveFamilyLocalDays: true },
    targetValue: 14,
  }),
  definition({
    key: "HABIT_30",
    ownerType: AchievementOwnerType.MEMBER,
    track: AchievementTrack.JOURNEY,
    ruleType: AchievementRuleType.ACTIVE_DAYS,
    ruleConfigJson: { distinctFamilyLocalDays: true, minimumActiveDays: 25 },
    targetValue: 25,
    windowType: AchievementWindowType.ROLLING_DAYS,
    windowSize: 30,
  }),
];

type MasterySeries = {
  key: string;
  metric: "count" | "duration" | "category_coverage";
  subcategories?: readonly string[];
  themes?: readonly string[];
  targets: readonly [number, number, number];
};

const masterySeries: readonly MasterySeries[] = [
  { key: "MASTERY_DISHES", metric: "count", subcategories: ["dishes"], targets: [5, 25, 100] },
  { key: "MASTERY_COOKING", metric: "count", subcategories: ["cooking"], targets: [5, 25, 100] },
  { key: "MASTERY_TRASH", metric: "count", subcategories: ["trash"], targets: [5, 25, 100] },
  { key: "MASTERY_PET", metric: "count", themes: ["pet"], targets: [5, 25, 100] },
  { key: "MASTERY_CHILDCARE", metric: "count", themes: ["childcare"], targets: [5, 25, 100] },
  { key: "MASTERY_FLOOR", metric: "count", subcategories: ["floor"], targets: [5, 20, 60] },
  { key: "MASTERY_LAUNDRY", metric: "count", subcategories: ["laundry"], targets: [5, 20, 60] },
  { key: "MASTERY_ROMANCE", metric: "count", themes: ["love"], targets: [3, 10, 30] },
  { key: "MASTERY_ORGANIZE", metric: "duration", subcategories: ["organize"], targets: [60, 300, 1200] },
  { key: "MASTERY_ALL_ROUNDER", metric: "category_coverage", targets: [3, 5, 8] },
];

const masteryTiers = [AchievementTier.BRONZE, AchievementTier.SILVER, AchievementTier.GOLD] as const;

const masteryDefinitions = masterySeries.flatMap((series) =>
  masteryTiers.map((tier, index) =>
    definition({
      key: series.key,
      ownerType: AchievementOwnerType.MEMBER,
      track: AchievementTrack.MASTERY,
      tier,
      ruleType:
        series.metric === "duration"
          ? AchievementRuleType.DURATION
          : series.metric === "category_coverage"
            ? AchievementRuleType.CATEGORY_COVERAGE
            : AchievementRuleType.COUNT,
      ruleConfigJson: {
        metric: series.metric,
        ...(series.subcategories ? { subcategories: [...series.subcategories] } : {}),
        ...(series.themes ? { themes: [...series.themes] } : {}),
      },
      targetValue: series.targets[index],
      windowType:
        series.metric === "category_coverage" ? AchievementWindowType.MONTH : AchievementWindowType.LIFETIME,
      maxDailyContribution: series.metric === "count" ? 3 : undefined,
    }),
  ),
);

const bondDefinitions: AchievementDefinitionSeed[] = [
  definition({
    key: "REACTION_FIRST",
    ownerType: AchievementOwnerType.MEMBER,
    track: AchievementTrack.BOND,
    ruleType: AchievementRuleType.FIRST_EVENT,
    ruleConfigJson: { eventType: "REACTION_CREATED", excludeSelfReaction: true },
    targetValue: 1,
    maxDailyContribution: 3,
  }),
  definition({
    key: "REACTION_GIVEN_20",
    ownerType: AchievementOwnerType.MEMBER,
    track: AchievementTrack.BOND,
    ruleType: AchievementRuleType.COUNT,
    ruleConfigJson: { direction: "given", uniqueRecordAndReceiver: true, excludeSelfReaction: true },
    targetValue: 20,
    maxDailyContribution: 3,
  }),
  definition({
    key: "REACTION_RECEIVED_10",
    ownerType: AchievementOwnerType.MEMBER,
    track: AchievementTrack.BOND,
    ruleType: AchievementRuleType.COUNT,
    ruleConfigJson: { direction: "received", uniqueRecordAndSender: true, excludeSelfReaction: true },
    targetValue: 10,
  }),
  definition({
    key: "FAMILY_FORMED",
    ownerType: AchievementOwnerType.FAMILY,
    track: AchievementTrack.BOND,
    ruleType: AchievementRuleType.ALL_MEMBERS,
    ruleConfigJson: { activeMemberCount: 2 },
    targetValue: 2,
    minimumMemberCount: 2,
  }),
  definition({
    key: "FAMILY_ALL_IN",
    ownerType: AchievementOwnerType.FAMILY,
    track: AchievementTrack.BOND,
    ruleType: AchievementRuleType.ALL_MEMBERS,
    ruleConfigJson: { everySnapshotMemberHasActiveDay: true },
    targetValue: 1,
    windowType: AchievementWindowType.WEEK,
    minimumMemberCount: 2,
  }),
  definition({
    key: "FAMILY_RELAY",
    ownerType: AchievementOwnerType.FAMILY,
    track: AchievementTrack.BOND,
    ruleType: AchievementRuleType.COUNT,
    ruleConfigJson: { distinctActiveMembers: 3 },
    targetValue: 3,
    windowType: AchievementWindowType.DAY,
    minimumMemberCount: 3,
  }),
  definition({
    key: "FAMILY_VISIBLE_4W",
    ownerType: AchievementOwnerType.FAMILY,
    track: AchievementTrack.BOND,
    ruleType: AchievementRuleType.ALL_MEMBERS,
    ruleConfigJson: { consecutiveSuccessfulWeeks: 4 },
    targetValue: 4,
    windowType: AchievementWindowType.WEEK,
    windowSize: 4,
    minimumMemberCount: 2,
  }),
  definition({
    key: "FAMILY_FULL_SERVICE",
    ownerType: AchievementOwnerType.FAMILY,
    track: AchievementTrack.BOND,
    ruleType: AchievementRuleType.CATEGORY_COVERAGE,
    ruleConfigJson: { subcategories: ["cooking", "dishes", "floor"] },
    targetValue: 3,
    windowType: AchievementWindowType.DAY,
    minimumMemberCount: 2,
  }),
  definition({
    key: "FAMILY_CATEGORY_COVERAGE",
    ownerType: AchievementOwnerType.FAMILY,
    track: AchievementTrack.BOND,
    ruleType: AchievementRuleType.CATEGORY_COVERAGE,
    ruleConfigJson: { fixedStandardCategories: true },
    targetValue: 8,
    windowType: AchievementWindowType.MONTH,
    minimumMemberCount: 2,
  }),
  definition({
    key: "PAIR_COOK_AND_CLEAN",
    ownerType: AchievementOwnerType.PAIR,
    track: AchievementTrack.BOND,
    ruleType: AchievementRuleType.PAIR_COMBINATION,
    ruleConfigJson: { firstSubcategory: "cooking", secondSubcategory: "dishes", distinctMembers: true },
    targetValue: 1,
    windowType: AchievementWindowType.DAY,
    minimumMemberCount: 2,
  }),
];

const familyMilestoneSeries = [
  { key: "FAMILY_ACTIVE_DAYS", metric: "active_days", targets: [30, 100, 365] },
  { key: "FAMILY_RECORD_COUNT", metric: "record_count", targets: [100, 500, 1000] },
] as const;

const familyMilestoneDefinitions = familyMilestoneSeries.flatMap((series) =>
  masteryTiers.map((tier, index) =>
    definition({
      key: series.key,
      ownerType: AchievementOwnerType.FAMILY,
      track: AchievementTrack.BOND,
      tier,
      ruleType: AchievementRuleType.COUNT,
      ruleConfigJson: { metric: series.metric },
      targetValue: series.targets[index],
    }),
  ),
);

const hiddenDefinitions: AchievementDefinitionSeed[] = [
  definition({
    key: "FAMILY_ANNIVERSARY",
    ownerType: AchievementOwnerType.FAMILY,
    track: AchievementTrack.BOND,
    ruleType: AchievementRuleType.ANNIVERSARY,
    ruleConfigJson: { familyAgeDays: 365, requiresActiveMemberAndHistory: true },
    targetValue: 365,
  }),
  definition({
    key: "HIDDEN_DISHES_3",
    ownerType: AchievementOwnerType.MEMBER,
    track: AchievementTrack.HIDDEN,
    ruleType: AchievementRuleType.COUNT,
    ruleConfigJson: { subcategories: ["dishes"] },
    targetValue: 3,
    windowType: AchievementWindowType.DAY,
    isHidden: true,
    defaultVisibility: AchievementVisibility.PRIVATE,
  }),
  definition({
    key: "HIDDEN_SHINY_FLOOR",
    ownerType: AchievementOwnerType.MEMBER,
    track: AchievementTrack.HIDDEN,
    ruleType: AchievementRuleType.CATEGORY_COVERAGE,
    ruleConfigJson: { catalogKeys: ["core-sweep-vacuum", "core-mop-floor"] },
    targetValue: 2,
    windowType: AchievementWindowType.DAY,
    isHidden: true,
    defaultVisibility: AchievementVisibility.PRIVATE,
  }),
  definition({
    key: "HIDDEN_GUESTS",
    ownerType: AchievementOwnerType.MEMBER,
    track: AchievementTrack.HIDDEN,
    ruleType: AchievementRuleType.CATEGORY_COVERAGE,
    ruleConfigJson: { distinctStandardSubcategories: true },
    targetValue: 5,
    windowType: AchievementWindowType.DAY,
    isHidden: true,
    defaultVisibility: AchievementVisibility.PRIVATE,
  }),
  definition({
    key: "HIDDEN_NIGHT_SHIFT",
    ownerType: AchievementOwnerType.MEMBER,
    track: AchievementTrack.HIDDEN,
    ruleType: AchievementRuleType.FIRST_EVENT,
    ruleConfigJson: { localHourStart: 0, localHourEnd: 5, categories: ["照护"] },
    targetValue: 1,
    windowType: AchievementWindowType.DAY,
    isHidden: true,
    defaultVisibility: AchievementVisibility.PRIVATE,
  }),
  definition({
    key: "HIDDEN_ENDURANCE",
    ownerType: AchievementOwnerType.MEMBER,
    track: AchievementTrack.HIDDEN,
    ruleType: AchievementRuleType.DURATION,
    ruleConfigJson: { minimumSingleRecordMinutes: 120 },
    targetValue: 120,
    isHidden: true,
    defaultVisibility: AchievementVisibility.PRIVATE,
  }),
];

export const achievementDefinitions: AchievementDefinitionSeed[] = [
  ...journeyDefinitions,
  ...masteryDefinitions,
  ...bondDefinitions,
  ...familyMilestoneDefinitions,
  ...hiddenDefinitions,
];
