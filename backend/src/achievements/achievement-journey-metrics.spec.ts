import { calculateJourneyMetrics } from './achievement-journey-metrics';

describe('calculateJourneyMetrics', () => {
  it('counts multiple records on the same family-local day once', () => {
    expect(
      calculateJourneyMetrics(
        ['2026-08-01', '2026-08-01', '2026-08-03', '2026-08-04'],
        '2026-08-04',
      ),
    ).toEqual({
      validRecordCount: 4,
      activeDays: 3,
      currentStreak: 2,
      longestStreak: 2,
      rolling30ActiveDays: 3,
    });
  });

  it('keeps an in-progress streak through the current unfinished day', () => {
    expect(
      calculateJourneyMetrics(['2026-08-01', '2026-08-02', '2026-08-03'], '2026-08-04'),
    ).toMatchObject({ currentStreak: 3, longestStreak: 3 });
  });

  it('resets the current streak after a missed full day but keeps the historical maximum', () => {
    expect(
      calculateJourneyMetrics(
        ['2026-07-01', '2026-07-02', '2026-07-03', '2026-08-10'],
        '2026-08-10',
      ),
    ).toMatchObject({ currentStreak: 1, longestStreak: 3, rolling30ActiveDays: 1 });
  });

  it('uses an inclusive rolling 30-day window', () => {
    const days = Array.from({ length: 31 }, (_, index) =>
      new Date(Date.UTC(2026, 6, 12 + index)).toISOString().slice(0, 10),
    );

    expect(calculateJourneyMetrics(days, '2026-08-11').rolling30ActiveDays).toBe(30);
  });
});
