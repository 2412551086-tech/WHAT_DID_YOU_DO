import {
  ACHIEVEMENT_UNDO_WINDOW_MS,
  achievementWorkerConfig,
  isAchievementsEnabled,
  isAchievementsEnabledForFamily,
} from './achievement-config';

describe('achievement configuration', () => {
  it('keeps achievements disabled when the environment variable is absent', () => {
    expect(isAchievementsEnabled({})).toBe(false);
  });

  it.each(['true', 'TRUE', '1', 'yes', 'on'])('enables achievements for %s', (value) => {
    expect(isAchievementsEnabled({ ACHIEVEMENTS_ENABLED: value })).toBe(true);
  });

  it.each(['false', '0', 'off', 'unexpected'])('keeps achievements disabled for %s', (value) => {
    expect(isAchievementsEnabled({ ACHIEVEMENTS_ENABLED: value })).toBe(false);
  });

  it('uses the frozen ten-second undo window', () => {
    expect(ACHIEVEMENT_UNDO_WINDOW_MS).toBe(10_000);
  });

  it('uses bounded worker defaults and accepts positive overrides', () => {
    expect(achievementWorkerConfig({})).toEqual({
      pollIntervalMs: 1_000,
      leaseMs: 30_000,
      batchSize: 20,
      maxRetries: 36,
      retryBaseMs: 1_000,
      retryMaxMs: 3_600_000,
    });
    expect(
      achievementWorkerConfig({
        ACHIEVEMENT_POLL_INTERVAL_MS: '250',
        ACHIEVEMENT_MAX_RETRIES: '8',
      }),
    ).toMatchObject({ pollIntervalMs: 250, maxRetries: 8 });
  });

  it('supports an optional family allowlist for gradual rollout', () => {
    expect(isAchievementsEnabledForFamily('family-a', { ACHIEVEMENTS_ENABLED: 'true' })).toBe(true);
    const environment = {
      ACHIEVEMENTS_ENABLED: 'true',
      ACHIEVEMENT_FAMILY_ALLOWLIST: 'family-a, family-b',
    };
    expect(isAchievementsEnabledForFamily('family-a', environment)).toBe(true);
    expect(isAchievementsEnabledForFamily('family-c', environment)).toBe(false);
  });
});
