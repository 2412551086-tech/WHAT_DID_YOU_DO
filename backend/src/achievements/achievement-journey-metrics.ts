export type JourneyMetrics = {
  validRecordCount: number;
  activeDays: number;
  currentStreak: number;
  longestStreak: number;
  rolling30ActiveDays: number;
};

export function calculateJourneyMetrics(
  localDateKeys: readonly string[],
  anchorDateKey: string,
): JourneyMetrics {
  const uniqueKeys = [...new Set(localDateKeys)].sort();
  const activeDaySet = new Set(uniqueKeys);
  let longestStreak = 0;
  let runningStreak = 0;
  let previousDay: number | null = null;

  for (const key of uniqueKeys) {
    const day = dateKeyToEpochDay(key);
    runningStreak = previousDay !== null && day === previousDay + 1 ? runningStreak + 1 : 1;
    longestStreak = Math.max(longestStreak, runningStreak);
    previousDay = day;
  }

  const anchorDay = dateKeyToEpochDay(anchorDateKey);
  const latestEligibleDay = activeDaySet.has(anchorDateKey)
    ? anchorDay
    : activeDaySet.has(epochDayToDateKey(anchorDay - 1))
      ? anchorDay - 1
      : null;
  let currentStreak = 0;

  if (latestEligibleDay !== null) {
    for (let day = latestEligibleDay; activeDaySet.has(epochDayToDateKey(day)); day -= 1) {
      currentStreak += 1;
    }
  }

  const rollingWindowStart = anchorDay - 29;
  const rolling30ActiveDays = uniqueKeys.reduce((count, key) => {
    const day = dateKeyToEpochDay(key);
    return day >= rollingWindowStart && day <= anchorDay ? count + 1 : count;
  }, 0);

  return {
    validRecordCount: localDateKeys.length,
    activeDays: uniqueKeys.length,
    currentStreak,
    longestStreak,
    rolling30ActiveDays,
  };
}

function dateKeyToEpochDay(key: string) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(key);
  if (!match) {
    throw new Error(`INVALID_LOCAL_DATE_KEY:${key}`);
  }
  return Math.floor(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])) / 86_400_000);
}

function epochDayToDateKey(epochDay: number) {
  return new Date(epochDay * 86_400_000).toISOString().slice(0, 10);
}
