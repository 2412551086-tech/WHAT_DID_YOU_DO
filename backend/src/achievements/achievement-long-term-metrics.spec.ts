import {
  calculateFamilyMilestones,
  calculateHiddenMetrics,
  calendarDayDistance,
  LongTermMetricRecord,
} from './achievement-long-term-metrics';

const record = (overrides: Partial<LongTermMetricRecord>): LongTermMetricRecord => ({
  localDateKey: '2026-08-11',
  catalogKey: null,
  subcategory: null,
  standardCategory: null,
  category: '清洁',
  actualMinutes: 15,
  localHour: 12,
  ...overrides,
});

describe('stage seven long-term metrics', () => {
  it('counts family active days and valid records', () => {
    expect(calculateFamilyMilestones([
      record({}),
      record({}),
      record({ localDateKey: '2026-08-12' }),
    ])).toEqual({ activeDays: 2, recordCount: 3 });
  });

  it('evaluates all five hidden achievement metrics without leaking names into rules', () => {
    const metrics = calculateHiddenMetrics([
      record({ catalogKey: 'core-dishes-cleanup', subcategory: 'dishes' }),
      record({ catalogKey: 'core-dishes-cleanup', subcategory: 'dishes' }),
      record({ catalogKey: 'core-dishes-cleanup', subcategory: 'dishes' }),
      record({ catalogKey: 'core-sweep-vacuum', subcategory: 'floor', standardCategory: 'floor' }),
      record({ catalogKey: 'core-mop-floor', subcategory: 'floor', standardCategory: 'floor' }),
      record({ standardCategory: 'cooking' }),
      record({ standardCategory: 'laundry' }),
      record({ standardCategory: 'organize' }),
      record({ standardCategory: 'care', localHour: 2 }),
      record({ actualMinutes: 130 }),
    ], '2026-08-11');

    expect(metrics).toEqual({ dishes: 3, shinyFloor: 2, guests: 6, nightShift: 1, endurance: 130 });
  });

  it('uses calendar days for anniversary thresholds', () => {
    expect(calendarDayDistance('2025-08-11', '2026-08-11')).toBe(365);
  });
});
