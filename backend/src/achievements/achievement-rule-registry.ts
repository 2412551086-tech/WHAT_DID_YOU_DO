import { Injectable } from '@nestjs/common';
import { AchievementRuleType } from '@prisma/client';

const choreRuleTypes = [
  AchievementRuleType.FIRST_EVENT,
  AchievementRuleType.ACTIVE_DAYS,
  AchievementRuleType.STREAK,
  AchievementRuleType.COUNT,
  AchievementRuleType.DURATION,
  AchievementRuleType.CATEGORY_COVERAGE,
  AchievementRuleType.ALL_MEMBERS,
  AchievementRuleType.PAIR_COMBINATION,
  AchievementRuleType.ANNIVERSARY,
];

const registry: Record<string, readonly AchievementRuleType[]> = {
  CHORE_CREATED: choreRuleTypes,
  CHORE_UPDATED: choreRuleTypes,
  CHORE_DELETED: choreRuleTypes,
  CHORE_RESTORED: choreRuleTypes,
  REACTION_CREATED: [AchievementRuleType.FIRST_EVENT, AchievementRuleType.COUNT],
  REACTION_CHANGED: [AchievementRuleType.COUNT],
  REACTION_DELETED: [AchievementRuleType.COUNT],
  MEMBER_JOINED: [AchievementRuleType.ALL_MEMBERS, AchievementRuleType.PAIR_COMBINATION, AchievementRuleType.ANNIVERSARY],
  MEMBER_LEFT: [AchievementRuleType.ALL_MEMBERS, AchievementRuleType.PAIR_COMBINATION, AchievementRuleType.ANNIVERSARY],
  PLAN_CHANGED: [],
};

@Injectable()
export class AchievementRuleRegistry {
  affectedRuleTypes(eventType: string) {
    return registry[eventType] ?? [];
  }

  supports(eventType: string) {
    return Object.prototype.hasOwnProperty.call(registry, eventType);
  }
}
