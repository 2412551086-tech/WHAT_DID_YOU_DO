export type LongTermMetricRecord = {
  localDateKey: string;
  catalogKey: string | null;
  subcategory: string | null;
  standardCategory: string | null;
  category: string;
  actualMinutes: number;
  localHour: number;
};

export type HiddenMetrics = {
  dishes: number;
  shinyFloor: number;
  guests: number;
  nightShift: number;
  endurance: number;
};

export function calculateFamilyMilestones(records: readonly LongTermMetricRecord[]) {
  return {
    activeDays: new Set(records.map((record) => record.localDateKey)).size,
    recordCount: records.length,
  };
}

export function calculateHiddenMetrics(
  records: readonly LongTermMetricRecord[],
  anchorDateKey: string,
): HiddenMetrics {
  const dayRecords = records.filter((record) => record.localDateKey === anchorDateKey);
  const catalogKeys = new Set(dayRecords.map((record) => record.catalogKey).filter(Boolean));
  const subcategories = new Set(
    dayRecords.map((record) => record.standardCategory ?? record.subcategory).filter(Boolean),
  );

  return {
    dishes: dayRecords.filter((record) => record.subcategory === 'dishes').length,
    shinyFloor:
      catalogKeys.has('core-sweep-vacuum') && catalogKeys.has('core-mop-floor') ? 2 : 0,
    guests: subcategories.size,
    nightShift: dayRecords.some(
      (record) =>
        record.localHour >= 0 &&
        record.localHour < 5 &&
        [record.standardCategory, record.subcategory, record.category].some(
          (value) => value !== null && ['care', 'childcare', '照护', '照顾'].includes(value),
        ),
    )
      ? 1
      : 0,
    endurance: records.reduce(
      (maximum, record) => Math.max(maximum, record.actualMinutes >= 120 ? record.actualMinutes : 0),
      0,
    ),
  };
}

export function calendarDayDistance(startDateKey: string, endDateKey: string) {
  return Math.max(0, dateKeyToEpochDay(endDateKey) - dateKeyToEpochDay(startDateKey));
}

function dateKeyToEpochDay(key: string) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(key);
  if (!match) throw new Error(`INVALID_LOCAL_DATE_KEY:${key}`);
  return Math.floor(
    Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])) / 86_400_000,
  );
}
