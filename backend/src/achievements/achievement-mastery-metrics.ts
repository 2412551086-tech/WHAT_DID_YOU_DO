export type MasteryMetricRecord = {
  localDateKey: string;
  subcategory: string | null;
  standardCategory: string | null;
  themeKey: string;
  actualMinutes: number;
};
export type MasteryRule = {
  metric: 'count' | 'duration' | 'category_coverage';
  subcategories?: readonly string[];
  themes?: readonly string[];
  maxDailyContribution?: number | null;
};

export function calculateMasteryValue(
  records: readonly MasteryMetricRecord[],
  rule: MasteryRule,
  anchorMonthKey: string,
): number {
  const matching = records.filter((record) => matchesRule(record, rule));

  if (rule.metric === 'duration') {
    return matching.reduce(
      (total, record) => total + (isValidActualMinutes(record.actualMinutes) ? record.actualMinutes : 0),
      0,
    );
  }

  if (rule.metric === 'category_coverage') {
    return new Set(
      matching
        .filter((record) => record.localDateKey.startsWith(`${anchorMonthKey}-`))
        .map((record) => record.standardCategory)
        .filter((category): category is string => Boolean(category)),
    ).size;
  }

  const dailyLimit = Math.max(1, rule.maxDailyContribution ?? Number.MAX_SAFE_INTEGER);
  const contributionByDayAndSubcategory = new Map<string, number>();

  for (const record of matching) {
    if (!record.subcategory) {
      continue;
    }
    const key = `${record.localDateKey}:${record.subcategory}`;
    contributionByDayAndSubcategory.set(
      key,
      Math.min(dailyLimit, (contributionByDayAndSubcategory.get(key) ?? 0) + 1),
    );
  }

  return [...contributionByDayAndSubcategory.values()].reduce((total, value) => total + value, 0);
}

export function isValidActualMinutes(value: number) {
  return Number.isInteger(value) && value >= 1 && value <= 180;
}

function matchesRule(record: MasteryMetricRecord, rule: MasteryRule) {
  if (rule.metric === 'category_coverage') {
    return Boolean(record.standardCategory);
  }
  if (rule.themes?.length) {
    return rule.themes.includes(record.themeKey);
  }
  if (rule.subcategories?.length) {
    return record.subcategory !== null && rule.subcategories.includes(record.subcategory);
  }
  return false;
}
