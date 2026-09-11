import { achievementDefinitions } from '../../prisma/achievement-definitions';

describe('achievement definition seed', () => {
  it('contains one unique definition for every key, tier, and version', () => {
    const identities = achievementDefinitions.map(
      (definition) => `${definition.key}:${definition.tier}:${definition.definitionVersion}`,
    );

    expect(new Set(identities).size).toBe(identities.length);
  });

  it('contains every frozen first-slice journey achievement', () => {
    const keys = new Set(achievementDefinitions.map((definition) => definition.key));

    expect(keys.has('FIRST_RECORD')).toBe(true);
    expect(keys.has('ACTIVE_DAYS_3')).toBe(true);
    expect(keys.has('ACTIVE_DAYS_5')).toBe(true);
    expect(keys.has('ACTIVE_DAYS_7')).toBe(true);
    expect(keys.has('STREAK_7')).toBe(true);
    expect(keys.has('STREAK_14')).toBe(true);
    expect(keys.has('HABIT_30')).toBe(true);
  });

  it('keeps seed definitions data-only and inactive behaviorally', () => {
    expect(achievementDefinitions.length).toBeGreaterThan(0);
    expect(achievementDefinitions.every((definition) => definition.definitionVersion === 1)).toBe(true);
    expect(achievementDefinitions.every((definition) => definition.targetValue > 0)).toBe(true);
  });

  it('contains the frozen stage-six interaction, family and pair definitions', () => {
    const keys = new Set(achievementDefinitions.map((definition) => definition.key));

    for (const key of [
      'REACTION_FIRST',
      'REACTION_GIVEN_20',
      'REACTION_RECEIVED_10',
      'FAMILY_FORMED',
      'FAMILY_ALL_IN',
      'FAMILY_RELAY',
      'FAMILY_VISIBLE_4W',
      'FAMILY_FULL_SERVICE',
      'FAMILY_CATEGORY_COVERAGE',
      'PAIR_COOK_AND_CLEAN',
    ]) {
      expect(keys.has(key)).toBe(true);
    }
  });
});
