import { Injectable } from '@nestjs/common';
import {
  AchievementEvent,
  AchievementOwnerType,
  AchievementProgressStatus,
  MemberStatus,
  Prisma,
} from '@prisma/client';
import { getLocalDateKeyForTimeZone, getLocalHourForTimeZone } from '../common/timezone-ranges';
import { FAMILY_MILESTONE_KEYS } from './achievement-long-term.constants';
import {
  calculateFamilyMilestones,
  calendarDayDistance,
  LongTermMetricRecord,
} from './achievement-long-term-metrics';
import { classifyMasteryRecord } from './achievement-mastery-taxonomy';

@Injectable()
export class AchievementFamilyMilestoneService {
  async process(transaction: Prisma.TransactionClient, event: AchievementEvent) {
    if (!['CHORE_CREATED', 'CHORE_UPDATED', 'CHORE_DELETED', 'CHORE_RESTORED', 'MEMBER_JOINED', 'MEMBER_LEFT'].includes(event.eventType)) {
      return { progressUpdateCount: 0, unlockedKeys: [] as string[] };
    }

    await transaction.$executeRaw(
      Prisma.sql`SELECT pg_advisory_xact_lock(hashtext(${`achievement-family:${event.familyId}`}))`,
    );
    const [family, records, definitions, activeMemberCount] = await Promise.all([
      transaction.family.findUnique({
        where: { id: event.familyId },
        select: { timezone: true, createdAt: true },
      }),
      transaction.choreRecord.findMany({
        where: { familyId: event.familyId, deletedAt: null },
        select: {
          id: true,
          userId: true,
          occurredAt: true,
          actualMinutes: true,
          chore: { select: { catalogKey: true, themeKey: true, category: true, isCustom: true } },
        },
      }),
      transaction.achievementDefinition.findMany({
        where: {
          key: { in: [...FAMILY_MILESTONE_KEYS] },
          ownerType: AchievementOwnerType.FAMILY,
          isActive: true,
        },
        orderBy: [{ key: 'asc' }, { targetValue: 'asc' }],
      }),
      transaction.familyMember.count({
        where: { familyId: event.familyId, status: MemberStatus.ACTIVE },
      }),
    ]);
    if (!family) throw new Error(`FAMILY_NOT_FOUND:${event.familyId}`);

    const timezoneByRecord = await this.timezoneSnapshotsByRecord(
      transaction,
      event.familyId,
      records.map((record) => record.id),
    );
    const metricRecords: LongTermMetricRecord[] = records.map((record) => {
      const timezone = timezoneByRecord.get(record.id) ?? family.timezone;
      const taxonomy = classifyMasteryRecord(record.chore);
      return {
        localDateKey: getLocalDateKeyForTimeZone(record.occurredAt, timezone),
        localHour: getLocalHourForTimeZone(record.occurredAt, timezone),
        catalogKey: record.chore.catalogKey,
        subcategory: taxonomy.subcategory,
        standardCategory: taxonomy.standardCategory,
        category: record.chore.category,
        actualMinutes: record.actualMinutes,
      };
    });
    const totals = calculateFamilyMilestones(metricRecords);
    const familyAgeDays = calendarDayDistance(
      getLocalDateKeyForTimeZone(family.createdAt, family.timezone),
      getLocalDateKeyForTimeZone(event.occurredAt, family.timezone),
    );
    const existingUnlocks = await transaction.familyAchievement.findMany({
      where: { familyId: event.familyId, achievementKey: { in: [...FAMILY_MILESTONE_KEYS] } },
    });
    const unlockByDefinition = new Map(existingUnlocks.map((unlock) => [unlock.definitionId, unlock]));
    const participantIds = [...new Set(records.map((record) => record.userId))];
    let unlockBatch = await transaction.achievementUnlockBatch.findUnique({
      where: { triggerEventId: event.id },
    });
    const unlockedKeys: string[] = [];

    for (const definition of definitions) {
      const currentValue = definition.key === 'FAMILY_ACTIVE_DAYS'
        ? totals.activeDays
        : definition.key === 'FAMILY_RECORD_COUNT'
          ? totals.recordCount
          : familyAgeDays;
      const anniversaryEligible = definition.key !== 'FAMILY_ANNIVERSARY'
        || (activeMemberCount > 0 && totals.recordCount > 0);
      const wasUnlocked = unlockByDefinition.has(definition.id);
      const achieved = wasUnlocked || (anniversaryEligible && currentValue >= definition.targetValue);

      await transaction.achievementProgress.upsert({
        where: {
          ownerType_ownerKey_achievementKey_tier_definitionVersion: {
            ownerType: AchievementOwnerType.FAMILY,
            ownerKey: event.familyId,
            achievementKey: definition.key,
            tier: definition.tier,
            definitionVersion: definition.definitionVersion,
          },
        },
        create: {
          ownerType: AchievementOwnerType.FAMILY,
          ownerKey: event.familyId,
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
      if (!achieved || wasUnlocked) continue;

      unlockBatch ??= await transaction.achievementUnlockBatch.create({
        data: { familyId: event.familyId, triggerEventId: event.id },
      });
      const unlock = await transaction.familyAchievement.create({
        data: {
          familyId: event.familyId,
          definitionId: definition.id,
          achievementKey: definition.key,
          tier: definition.tier,
          definitionVersion: definition.definitionVersion,
          triggeredByUserId: event.actorUserId,
          unlockBatchId: unlockBatch.id,
          triggerEventId: event.id,
          unlockedAt: event.occurredAt,
        },
      });
      if (participantIds.length > 0) {
        await transaction.familyAchievementParticipant.createMany({
          data: participantIds.map((userId) => ({
            familyAchievementId: unlock.id,
            userId,
            contributionSummaryJson: { narrativeKey: `achievement.${definition.key.toLowerCase()}.family_history` },
          })),
          skipDuplicates: true,
        });
      }
      unlockByDefinition.set(definition.id, unlock);
      unlockedKeys.push(`${definition.key}:${definition.tier}`);
      await transaction.achievementAuditLog.create({
        data: {
          familyId: event.familyId,
          actorUserId: event.actorUserId,
          actionType: 'ACHIEVEMENT_UNLOCKED',
          entityType: 'FamilyAchievement',
          entityId: unlock.id,
          afterJson: { achievementKey: definition.key, tier: definition.tier, triggerEventId: event.id },
        },
      });
    }

    return { progressUpdateCount: definitions.length, unlockedKeys };
  }

  private async timezoneSnapshotsByRecord(
    transaction: Prisma.TransactionClient,
    familyId: string,
    recordIds: string[],
  ) {
    if (recordIds.length === 0) return new Map<string, string>();
    const events = await transaction.achievementEvent.findMany({
      where: { familyId, eventType: 'CHORE_CREATED', sourceId: { in: recordIds } },
      select: { sourceId: true, familyTimezoneSnapshot: true },
    });
    return new Map(events.map((item) => [item.sourceId, item.familyTimezoneSnapshot]));
  }
}
