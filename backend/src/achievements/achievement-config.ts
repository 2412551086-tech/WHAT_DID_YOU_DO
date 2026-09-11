export const ACHIEVEMENT_UNDO_WINDOW_MS = 10_000;

function positiveInteger(value: string | undefined, fallback: number) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

export function isAchievementsEnabled(environment: NodeJS.ProcessEnv = process.env) {
  const value = environment.ACHIEVEMENTS_ENABLED?.trim().toLowerCase();
  return value === 'true' || value === '1' || value === 'yes' || value === 'on';
}

export function isAchievementsEnabledForFamily(
  familyId: string,
  environment: NodeJS.ProcessEnv = process.env,
) {
  if (!isAchievementsEnabled(environment)) return false;
  const allowlist = environment.ACHIEVEMENT_FAMILY_ALLOWLIST
    ?.split(',')
    .map((value) => value.trim())
    .filter(Boolean) ?? [];
  return allowlist.length === 0 || allowlist.includes(familyId);
}

export function achievementWorkerConfig(environment: NodeJS.ProcessEnv = process.env) {
  return {
    pollIntervalMs: positiveInteger(environment.ACHIEVEMENT_POLL_INTERVAL_MS, 1_000),
    leaseMs: positiveInteger(environment.ACHIEVEMENT_PROCESSING_LEASE_MS, 30_000),
    batchSize: positiveInteger(environment.ACHIEVEMENT_WORKER_BATCH_SIZE, 20),
    maxRetries: positiveInteger(environment.ACHIEVEMENT_MAX_RETRIES, 36),
    retryBaseMs: positiveInteger(environment.ACHIEVEMENT_RETRY_BASE_MS, 1_000),
    retryMaxMs: positiveInteger(environment.ACHIEVEMENT_RETRY_MAX_MS, 60 * 60 * 1_000),
  };
}
