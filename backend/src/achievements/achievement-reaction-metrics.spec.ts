import { calculateReactionMetrics } from './achievement-reaction-metrics';
describe('calculateReactionMetrics', () => {
  it('excludes self reactions, deduplicates records and caps a daily relationship', () => {
    const records = [
      ...Array.from({ length: 4 }, (_, index) => ({
        recordId: `record-${index}`,
        senderUserId: 'a',
        receiverUserId: 'b',
        localDateKey: '2026-08-11',
      })),
      {
        recordId: 'record-0',
        senderUserId: 'a',
        receiverUserId: 'b',
        localDateKey: '2026-08-11',
      },
      {
        recordId: 'self',
        senderUserId: 'a',
        receiverUserId: 'a',
        localDateKey: '2026-08-11',
      },
    ];

    expect(calculateReactionMetrics(records, 'a')).toEqual({
      firstGiven: 1,
      given: 3,
      received: 0,
    });
    expect(calculateReactionMetrics(records, 'b').received).toBe(4);
  });
});
