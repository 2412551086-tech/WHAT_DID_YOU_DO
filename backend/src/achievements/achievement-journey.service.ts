import { Injectable } from '@nestjs/common';
import {
  AchievementEvent,
  AchievementOwnerType,
  AchievementProgressStatus,
  AchievementRewardType,
  AchievementRuleType,
  AchievementVisibility,
  Prisma,
} from '@prisma/client';
import { getLocalDateKeyForTimeZone } from '../common/timezone-ranges';
import { calculateJourneyMetrics, JourneyMetrics } from './achievement-journey-metrics';

export const STAGE_THREE_JOURNEY_KEYS = [
  'FIRST_RECORD',
  'ACTIVE_DAYS_3',
  'ACTIVE_DAYS_5',
  'ACTIVE_DAYS_7',
  'STREAK_7',
  'STREAK_14',
  'HABIT_30',
] as const;

type StageThreeJourneyKey = (typeof STAGE_THREE_JOURNEY_KEYS)[number];

@Injectable()
export class AchievementJourneyService {
  async process(transaction: Prisma.TransactionClient, event: AchievementEvent) {
    if (!['CHORE_CREATED', 'CHORE_UPDATED', 'CHORE_DELETED', 'CHORE_RESTORED'].includes(event.eventType)) {
      return { progressUpdateCount: 0, unlockedKeys: [], grantedRewards: [] };
    }

    const userId = this.subjectUserId(event);
    if (!userId) {
      throw new Error(`MISSING_ACHIEVEMENT_SUBJECT:${event.id}`);
    }

    await transaction.$executeRaw(
      Prisma.sql`SELECT pg_advisory_xact_lock(hashtext(${`achievement-family:${event.familyId}`}))`,
    );

    const membership = await transaction.familyMember.findUnique({
      where: { userId_familyId: { userId, familyId: event.familyId } },
      select: { showAchievementsToFamily: true },
    });
    const [family, records, definitions] = await Promise.all([
      transaction.family.findUnique({
        where: { id: event.familyId },
        select: { timezone: true },
      }),
      transaction.choreRecord.findMany({
        where: { familyId: event.familyId, userId, deletedAt: null },
        select: { id: true, occurredAt: true },
      }),
      transaction.achievementDefinition.findMany({
        where: {
          key: { in: [...STAGE_THREE_JOURNEY_KEYS] },
          ownerType: AchievementOwnerType.MEMBER,
          isActive: true,
        },
        orderBy: [{ targetValue: 'asc' }, { key: 'asc' }],
      }),
    ]);

    if (!family) {
      throw new Error(`FAMILY_NOT_FOUND:${event.familyId}`);
    }

    const timezoneByRecord = await this.timezoneSnapshotsByRecord(
      transaction,
      event.familyId,
      records.map((record) => record.id),
    );
    const localDateKeys = records.map((record) =>
      getLocalDateKeyForTimeZone(
        record.occurredAt,
        timezoneByRecord.get(record.id) ?? family.timezone,
      ),
    );
    const anchorDateKey = getLocalDateKeyForTimeZone(
      event.occurredAt,
      event.familyTimezoneSnapshot,
    );
    const metrics = calculateJourneyMetrics(localDateKeys, anchorDateKey);
    const ownerKey = `${event.familyId}:${userId}`;
    const existingUnlocks = await transaction.memberAchievement.findMany({
      where: {
        userId,
        familyId: event.familyId,
        achievementKey: { in: [...STAGE_THREE_JOURNEY_KEYS] },
      },
    });
    const unlockByDefinition = new Map(
      existingUnlocks.map((unlock) => [unlock.definitionId, unlock]),
    );
    let unlockBatch = await transaction.achievementUnlockBatch.findUnique({
      where: { triggerEventId: event.id },
    });
    const newlyUnlocked: Array<{ id: string; key: string }> = [];
    const grantedRewards: Array<{ key: string; type: AchievementRewardType; value: number }> = [];

    for (const definition of definitions) {
      const key = definition.key as StageThreeJourneyKey;
      const currentValue = this.currentValue(key, definition.ruleType, metrics);
      const wasUnlocked = unlockByDefinition.has(definition.id);
      const achieved = wasUnlocked || this.isAchieved(key, definition.targetValue, metrics);

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
          displayCurrentValue: achieved
            ? Math.max(currentValue, definition.targetValue)
            : currentValue,
          targetValue: definition.targetValue,
          progressStatus: achieved
            ? AchievementProgressStatus.COMPLETED
            : AchievementProgressStatus.ACTIVE,
          lastEventId: event.id,
        },
        update: {
          definitionId: definition.id,
          familyId: event.familyId,
          rawCurrentValue: currentValue,
          displayCurrentValue: achieved
            ? Math.max(currentValue, definition.targetValue)
            : currentValue,
          targetValue: definition.targetValue,
          progressStatus: achieved
            ? AchievementProgressStatus.COMPLETED
            : AchievementProgressStatus.ACTIVE,
          lastEventId: event.id,
        },
      });

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
      newlyUnlocked.push({ id: unlock.id, key: definition.key });

      await transaction.achievementAuditLog.create({
        data: {
          familyId: event.familyId,
          actorUserId: userId,
          actionType: 'ACHIEVEMENT_UNLOCKED',
          entityType: 'MemberAchievement',
          entityId: unlock.id,
          afterJson: {
            achievementKey: definition.key,
            definitionVersion: definition.definitionVersion,
            triggerEventId: event.id,
          },
        },
      });

      const reward = this.rewardConfig(definition.rewardConfigJson);
      if (reward) {
        const existingGrant = await transaction.familyRewardGrant.findUnique({
          where: {
            familyId_achievementKey_rewardType: {
              familyId: event.familyId,
              achievementKey: definition.key,
              rewardType: reward.type,
            },
          },
        });
        if (!existingGrant) {
          const grant = await transaction.familyRewardGrant.create({
            data: {
              familyId: event.familyId,
              achievementKey: definition.key,
              rewardType: reward.type,
              rewardValue: reward.value,
              grantedByUserId: userId,
              triggerEventId: event.id,
              grantedAt: event.occurredAt,
            },
          });
          grantedRewards.push({ key: definition.key, ...reward });
          await transaction.achievementAuditLog.create({
            data: {
              familyId: event.familyId,
              actorUserId: userId,
              actionType: 'FAMILY_REWARD_GRANTED',
              entityType: 'FamilyRewardGrant',
              entityId: grant.id,
              afterJson: {
                achievementKey: definition.key,
                rewardType: reward.type,
                rewardValue: reward.value,
              },
            },
          });
        }
      }
    }

    if (unlockBatch && newlyUnlocked.length > 0) {
      await transaction.achievementUnlockBatch.update({
        where: { id: unlockBatch.id },
        data: {
          primaryUnlockId: newlyUnlocked[0].id,
          unlockCount: newlyUnlocked.length,
        },
      });
    }

    return {
      progressUpdateCount: definitions.length,
      unlockedKeys: newlyUnlocked.map((unlock) => unlock.key),
      grantedRewards,
      metrics,
    };
  }

  private async timezoneSnapshotsByRecord(
    transaction: Prisma.TransactionClient,
    familyId: string,
    recordIds: string[],
  ) {
    if (recordIds.length === 0) {
      return new Map<string, string>();
    }
    const events = await transaction.achievementEvent.findMany({
      where: {
        familyId,
        eventType: 'CHORE_CREATED',
        sourceId: { in: recordIds },
      },
      select: { sourceId: true, familyTimezoneSnapshot: true },
    });
    return new Map(events.map((item) => [item.sourceId, item.familyTimezoneSnapshot]));
  }

  private subjectUserId(event: AchievementEvent) {
    const payload = this.payload(event.payloadJson);
    const value = event.eventType === 'CHORE_CREATED' ? payload.userId : payload.recordUserId;
    return typeof value === 'string' && value ? value : event.actorUserId;
  }

  private payload(value: Prisma.JsonValue) {
    return value && typeof value === 'object' && !Array.isArray(value)
      ? (value as Prisma.JsonObject)
      : {};
  }

  private currentValue(
    key: StageThreeJourneyKey,
    ruleType: AchievementRuleType,
    metrics: JourneyMetrics,
  ) {
    if (key === 'FIRST_RECORD') {
      return Math.min(1, metrics.validRecordCount);
    }
    if (key === 'HABIT_30') {
      return metrics.rolling30ActiveDays;
    }
    if (ruleType === AchievementRuleType.STREAK) {
      return metrics.currentStreak;
    }
    return metrics.activeDays;
  }

  private isAchieved(key: StageThreeJourneyKey, target: number, metrics: JourneyMetrics) {
    if (key === 'FIRST_RECORD') {
      return metrics.validRecordCount >= target;
    }
    if (key === 'HABIT_30') {
      return metrics.rolling30ActiveDays >= target;
    }
    if (key === 'STREAK_7' || key === 'STREAK_14') {
      return metrics.longestStreak >= target;
    }
    return metrics.activeDays >= target;
  }

  private rewardConfig(value: Prisma.JsonValue) {
    const object = this.payload(value);
    const type = object.type;
    const rawValue = object.value;
    if (
      (type === AchievementRewardType.COMMON_CHORE_SLOT ||
        type === AchievementRewardType.CUSTOM_CHORE_SLOT ||
        type === AchievementRewardType.COSMETIC) &&
      typeof rawValue === 'number' &&
      Number.isInteger(rawValue) &&
      rawValue > 0
    ) {
      return { type, value: rawValue };
    }
    return null;
  }
}
