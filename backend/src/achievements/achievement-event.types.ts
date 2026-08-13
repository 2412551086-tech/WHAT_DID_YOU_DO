import { AchievementEventSourceType, Prisma } from '@prisma/client';

export type AchievementEventClient = Pick<
  Prisma.TransactionClient,
  'achievementEvent' | '$executeRaw'
>;

export type EnqueueAchievementEventInput = {
  familyId: string;
  actorUserId?: string | null;
  eventType: string;
  sourceType: AchievementEventSourceType;
  sourceId: string;
  sourceVersion?: number;
  occurredAt: Date;
  familyTimezone: string;
  payload: Prisma.InputJsonValue;
};

export type AchievementEvaluation = {
  eventId: string;
  state: 'PENDING';
  retryAfterMs: number;
};
