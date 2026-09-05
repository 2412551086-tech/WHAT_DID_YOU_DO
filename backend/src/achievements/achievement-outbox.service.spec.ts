import { AchievementEventSourceType } from '@prisma/client';
import { AchievementOutboxService } from './achievement-outbox.service';

describe('AchievementOutboxService', () => {
  const originalFlag = process.env.ACHIEVEMENTS_ENABLED;

  afterEach(() => {
    if (originalFlag === undefined) {
      delete process.env.ACHIEVEMENTS_ENABLED;
    } else {
      process.env.ACHIEVEMENTS_ENABLED = originalFlag;
    }
  });

  const input = {
    familyId: 'family-1',
    actorUserId: 'user-1',
    eventType: 'CHORE_CREATED',
    sourceType: AchievementEventSourceType.CHORE,
    sourceId: 'record-1',
    occurredAt: new Date('2026-08-11T00:00:00.000Z'),
    familyTimezone: 'Asia/Shanghai',
    payload: { recordId: 'record-1' },
  };

  it('does not touch the database while the feature flag is disabled', async () => {
    delete process.env.ACHIEVEMENTS_ENABLED;
    const upsert = jest.fn();
    const service = new AchievementOutboxService();

    await expect(service.enqueue({ achievementEvent: { upsert } } as never, input)).resolves.toBeNull();
    expect(upsert).not.toHaveBeenCalled();
  });

  it('uses a deterministic idempotency key while enabled', async () => {
    process.env.ACHIEVEMENTS_ENABLED = 'true';
    const event = { id: 'event-1' };
    const upsert = jest.fn().mockResolvedValue(event);
    const service = new AchievementOutboxService();

    await expect(service.enqueue({ achievementEvent: { upsert } } as never, input)).resolves.toBe(event);
    expect(upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { idempotencyKey: 'CHORE:record-1:v1:CHORE_CREATED' },
        create: expect.objectContaining({ sourceVersion: 1 }),
      }),
    );
  });
});
