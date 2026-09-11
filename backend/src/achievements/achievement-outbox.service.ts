import { Injectable } from '@nestjs/common';
import { AchievementEventStatus, Prisma } from '@prisma/client';
import { achievementWorkerConfig, isAchievementsEnabledForFamily } from './achievement-config';
import {
  AchievementEvaluation,
  AchievementEventClient,
  EnqueueAchievementEventInput,
} from './achievement-event.types';

@Injectable()
export class AchievementOutboxService {
  async enqueue(client: AchievementEventClient, input: EnqueueAchievementEventInput) {
    if (!isAchievementsEnabledForFamily(input.familyId)) {
      return null;
    }

    const sourceVersion = input.sourceVersion ?? 1;
    const idempotencyKey = this.idempotencyKey(input, sourceVersion);

    return client.achievementEvent.upsert({
      where: { idempotencyKey },
      update: {},
      create: {
        familyId: input.familyId,
        actorUserId: input.actorUserId,
        eventType: input.eventType,
        sourceType: input.sourceType,
        sourceId: input.sourceId,
        sourceVersion,
        idempotencyKey,
        occurredAt: input.occurredAt,
        familyTimezoneSnapshot: input.familyTimezone,
        payloadJson: input.payload,
        processStatus: AchievementEventStatus.PENDING,
      },
    });
  }

  async enqueueNextVersion(client: AchievementEventClient, input: EnqueueAchievementEventInput) {
    if (!isAchievementsEnabledForFamily(input.familyId)) {
      return null;
    }

    const sourceLockKey = `${input.sourceType}:${input.sourceId}`;
    await client.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${sourceLockKey}))`;
    const latest = await client.achievementEvent.findFirst({
      where: {
        sourceType: input.sourceType,
        sourceId: input.sourceId,
      },
      orderBy: { sourceVersion: 'desc' },
      select: { sourceVersion: true },
    });

    return this.enqueue(client, {
      ...input,
      sourceVersion: (latest?.sourceVersion ?? 0) + 1,
    });
  }

  evaluation(event: { id: string } | null): AchievementEvaluation | null {
    if (!event) {
      return null;
    }

    return {
      eventId: event.id,
      state: 'PENDING',
      retryAfterMs: achievementWorkerConfig().pollIntervalMs,
    };
  }

  private idempotencyKey(input: EnqueueAchievementEventInput, sourceVersion: number) {
    return `${input.sourceType}:${input.sourceId}:v${sourceVersion}:${input.eventType}`;
  }
}
