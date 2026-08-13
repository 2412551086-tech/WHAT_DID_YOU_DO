import { AchievementRuleType } from '@prisma/client';
import { AchievementRuleRegistry } from './achievement-rule-registry';

describe('AchievementRuleRegistry', () => {
  const registry = new AchievementRuleRegistry();

  it('routes chore events to growth, mastery and collaboration rule families', () => {
    expect(registry.affectedRuleTypes('CHORE_CREATED')).toEqual(
      expect.arrayContaining([
        AchievementRuleType.FIRST_EVENT,
        AchievementRuleType.ACTIVE_DAYS,
        AchievementRuleType.STREAK,
        AchievementRuleType.COUNT,
      ]),
    );
  });

  it('re-evaluates the same chore rules after a record edit', () => {
    expect(registry.affectedRuleTypes('CHORE_UPDATED')).toEqual(
      registry.affectedRuleTypes('CHORE_CREATED'),
    );
  });

  it('rejects event types that are not in the versioned registry', () => {
    expect(registry.supports('UNKNOWN_EVENT')).toBe(false);
    expect(registry.affectedRuleTypes('UNKNOWN_EVENT')).toEqual([]);
  });
});
