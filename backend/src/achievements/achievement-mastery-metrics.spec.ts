import { calculateMasteryValue, isValidActualMinutes, MasteryMetricRecord } from './achievement-mastery-metrics';
const record = (overrides: Partial<MasteryMetricRecord> = {}): MasteryMetricRecord => ({
  localDateKey: '2026-08-11',
  subcategory: 'dishes',
  standardCategory: 'dishes',
  themeKey: 'daily',
  actualMinutes: 15,
  ...overrides,
});

describe('mastery metrics', () => {
  it('caps the same subcategory at three contributions per local day', () => {
    const records = Array.from({ length: 4 }, () => record());
    expect(calculateMasteryValue(records, {
      metric: 'count',
      subcategories: ['dishes'],
      maxDailyContribution: 3,
    }, '2026-08')).toBe(3);
  });

  it('applies the daily cap independently to different subcategories and days', () => {
    const records = [
      ...Array.from({ length: 4 }, () => record()),
      ...Array.from({ length: 4 }, () => record({ subcategory: 'floor' })),
      record({ localDateKey: '2026-08-10' }),
    ];
    expect(calculateMasteryValue(records, {
      metric: 'count',
      themes: ['daily'],
      maxDailyContribution: 3,
    }, '2026-08')).toBe(7);
  });

  it('uses only validated actual minutes for duration mastery', () => {
    const records = [record({ subcategory: 'organize', actualMinutes: 20 }), record({ subcategory: 'organize', actualMinutes: 181 })];
    expect(calculateMasteryValue(records, {
      metric: 'duration',
      subcategories: ['organize'],
    }, '2026-08')).toBe(20);
    expect(isValidActualMinutes(1)).toBe(true);
    expect(isValidActualMinutes(180)).toBe(true);
    expect(isValidActualMinutes(0)).toBe(false);
    expect(isValidActualMinutes(181)).toBe(false);
  });

  it('counts fixed categories only inside the anchor family-local month', () => {
    const records = [
      record({ standardCategory: 'dishes' }),
      record({ standardCategory: 'floor' }),
      record({ standardCategory: 'floor' }),
      record({ localDateKey: '2026-07-31', standardCategory: 'cooking' }),
    ];
    expect(calculateMasteryValue(records, { metric: 'category_coverage' }, '2026-08')).toBe(2);
  });
});
