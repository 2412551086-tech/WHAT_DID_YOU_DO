import { getWeekRangeForTimeZone } from './timezone-ranges';

describe('getWeekRangeForTimeZone', () => {
  it('moves a family-local Monday-to-Monday range by whole weeks', () => {
    const now = new Date('2026-08-05T04:00:00.000Z');

    const currentWeek = getWeekRangeForTimeZone('Asia/Shanghai', now, 0);
    const previousWeek = getWeekRangeForTimeZone('Asia/Shanghai', now, -1);

    expect(currentWeek.start.toISOString()).toBe('2026-08-02T16:00:00.000Z');
    expect(currentWeek.end.toISOString()).toBe('2026-08-09T16:00:00.000Z');
    expect(previousWeek.start.toISOString()).toBe('2026-07-26T16:00:00.000Z');
    expect(previousWeek.end.toISOString()).toBe('2026-08-02T16:00:00.000Z');
  });
});
