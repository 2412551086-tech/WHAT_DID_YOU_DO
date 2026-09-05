import { Injectable } from '@nestjs/common';
import {
  AchievementEvent,
  AchievementOwnerType,
  AchievementProgressStatus,
  AchievementVisibility,
  MemberStatus,
  Prisma,
} from '@prisma/client';
import { getLocalDateKeyForTimeZone } from '../common/timezone-ranges';
import { REACTION_ACHIEVEMENT_KEYS } from './achievement-bond.constants';
import { calculateReactionMetrics } from './achievement-reaction-metrics';

@Injectable()
export class AchievementReactionService {
  async process(transaction: Prisma.TransactionClient, event: AchievementEvent) {
    if (!event.eventType.startsWith('REACTION_')) {
      return { progressUpdateCount: 0, unlockedKeys: [] as string[] };
    }

    const payload = this.payload(event.payloadJson);
    const senderUserId = this.string(payload.senderUserId);
    const receiverUserId = this.string(payload.receiverUserId);
    if (!senderUserId || !receiverUserId || senderUserId === receiverUserId) {
      return { progressUpdateCount: 0, unlockedKeys: [] as string[] };
    }

    await transaction.$executeRaw(
      Prisma.sql`SELECT pg_advisory_xact_lock(hashtext(${`achievement-family:${event.familyId}`}))`,
    );

    const [family, activeMemberCount, definitions, reactions] = await Promise.all([
      transaction.family.findUnique({
        where: { id: event.familyId },
        select: { timezone: true },
      }),
      transaction.familyMember.count({
        where: { familyId: event.familyId, status: MemberStatus.ACTIVE },
      }),
      transaction.achievementDefinition.findMany({
        where: {
          key: { in: [...REACTION_ACHIEVEMENT_KEYS] },
          ownerType: AchievementOwnerType.MEMBER,
          isActive: true,
        },
      }),
      transaction.choreRecordLike.findMany({
        where: {
          record: { familyId: event.familyId, deletedAt: null },
        },
        select: {
          recordId: true,
          userId: true,
          createdAt: true,
          record: { select: { userId: true } },
        },
      }),
    ]);

    if (!family || activeMemberCount < 2) {
      return { progressUpdateCount: 0, unlockedKeys: [] as string[] };
    }

    const metricRecords = reactions.map((reaction) => ({
      recordId: reaction.recordId,
      senderUserId: reaction.userId,
      receiverUserId: reaction.record.userId,
      localDateKey: getLocalDateKeyForTimeZone(reaction.createdAt, family.timezone),
    }));
    const subjects = new Set([senderUserId, receiverUserId]);
    let progressUpdateCount = 0;
    const unlockedKeys: string[] = [];
    let unlockBatch = await transaction.achievementUnlockBatch.findUnique({
      where: { triggerEventId: event.id },
    });

    for (const userId of subjects) {
      const membership = await transaction.familyMember.findUnique({
        where: { userId_familyId: { userId, familyId: event.familyId } },
        select: { showAchievementsToFamily: true },
      });
      const metrics = calculateReactionMetrics(metricRecords, userId);
      const existingUnlocks = await transaction.memberAchievement.findMany({
        where: {
          familyId: event.familyId,
          userId,
          achievementKey: { in: [...REACTION_ACHIEVEMENT_KEYS] },
        },
      });
      const unlockByDefinition = new Map(
        existingUnlocks.map((unlock) => [unlock.definitionId, unlock]),
      );

      for (const definition of definitions) {
        if (!this.definitionAppliesToUser(definition.key, userId, senderUserId, receiverUserId)) {
          continue;
        }
        const currentValue = this.currentValue(definition.key, metrics);
        const wasUnlocked = unlockByDefinition.has(definition.id);
        const achieved = wasUnlocked || currentValue >= definition.targetValue;
        const ownerKey = `${event.familyId}:${userId}`;

        await transaction.achievementProgress.upsert({
          where: {
            ownerType_ownerKey_achievementKey_tier_definitionVersion: {
              ownerType: AchievementOwnerType.MEMBER,
              ownerKey,
              achievementKey: definition.key,
              tier: definition.tier,
              definitionVersion: definition.definitionVersion,
            },
          },
          create: {
            ownerType: AchievementOwnerType.MEMBER,
            ownerKey,
            familyId: event.familyId,
            definitionId: definition.id,
            achievementKey: definition.key,
            tier: definition.tier,
            definitionVersion: definition.definitionVersion,
            rawCurrentValue: currentValue,
            displayCurrentValue: achieved ? Math.max(currentValue, definition.targetValue) : currentValue,
            targetValue: definition.targetValue,
            progressStatus: achieved ? AchievementProgressStatus.COMPLETED : AchievementProgressStatus.ACTIVE,
            lastEventId: event.id,
          },
          update: {
            definitionId: definition.id,
            rawCurrentValue: currentValue,
            displayCurrentValue: achieved ? Math.max(currentValue, definition.targetValue) : currentValue,
            progressStatus: achieved ? AchievementProgressStatus.COMPLETED : AchievementProgressStatus.ACTIVE,
            lastEventId: event.id,
          },
        });
        progressUpdateCount += 1;

        if (!achieved || wasUnlocked) {
          continue;
        }
        unlockBatch ??= await transaction.achievementUnlockBatch.create({
          data: { familyId: event.familyId, triggerEventId: event.id },
        });
        const unlock = await transaction.memberAchievement.create({
          data: {
            userId,
            familyId: event.familyId,
            definitionId: definition.id,
            achievementKey: definition.key,
            tier: definition.tier,
            definitionVersion: definition.definitionVersion,
            visibility: membership?.showAchievementsToFamily === false
              ? AchievementVisibility.PRIVATE
              : AchievementVisibility.FAMILY,
            unlockBatchId: unlockBatch.id,
            triggerEventId: event.id,
            unlockedAt: event.occurredAt,
          },
        });
        unlockByDefinition.set(definition.id, unlock);
        unlockedKeys.push(definition.key);
        await transaction.achievementAuditLog.create({
          data: {
            familyId: event.familyId,
            actorUserId: userId,
            actionType: 'ACHIEVEMENT_UNLOCKED',
            entityType: 'MemberAchievement',
            entityId: unlock.id,
            afterJson: { achievementKey: definition.key, triggerEventId: event.id },
          },
        });
      }
    }

    return { progressUpdateCount, unlockedKeys };
  }

  private currentValue(key: string, metrics: ReturnType<typeof calculateReactionMetrics>) {
    if (key === 'REACTION_FIRST') return metrics.firstGiven;
    if (key === 'REACTION_GIVEN_20') return metrics.given;
    return metrics.received;
  }

  private definitionAppliesToUser(
    key: string,
    userId: string,
    senderUserId: string,
    receiverUserId: string,
  ) {
    return key === 'REACTION_RECEIVED_10'
      ? userId === receiverUserId
      : userId === senderUserId;
  }

  private payload(value: Prisma.JsonValue): Prisma.JsonObject {
    return value && typeof value === 'object' && !Array.isArray(value)
      ? (value as Prisma.JsonObject)
      : {};
  }

  private string(value: Prisma.JsonValue | undefined) {
    return typeof value === 'string' && value ? value : null;
  }
}
