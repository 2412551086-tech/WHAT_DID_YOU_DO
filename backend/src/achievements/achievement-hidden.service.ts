import { Injectable } from '@nestjs/common';
import {
  AchievementEvent,
  AchievementOwnerType,
  AchievementProgressStatus,
  AchievementVisibility,
  Prisma,
} from '@prisma/client';
import { getLocalDateKeyForTimeZone, getLocalHourForTimeZone } from '../common/timezone-ranges';
import { HIDDEN_ACHIEVEMENT_KEYS } from './achievement-long-term.constants';
import { calculateHiddenMetrics, HiddenMetrics, LongTermMetricRecord } from './achievement-long-term-metrics';
import { classifyMasteryRecord } from './achievement-mastery-taxonomy';

@Injectable()
export class AchievementHiddenService {
  async process(transaction: Prisma.TransactionClient, event: AchievementEvent) {
    if (!['CHORE_CREATED', 'CHORE_UPDATED', 'CHORE_DELETED', 'CHORE_RESTORED'].includes(event.eventType)) {
      return { progressUpdateCount: 0, unlockedKeys: [] as string[] };
    }
    const userId = this.subjectUserId(event);
    if (!userId) throw new Error(`MISSING_ACHIEVEMENT_SUBJECT:${event.id}`);

    const membership = await transaction.familyMember.findUnique({
      where: { userId_familyId: { userId, familyId: event.familyId } },
      select: { showAchievementsToFamily: true },
    });
    const [family, sourceRecord, records, definitions] = await Promise.all([
      transaction.family.findUnique({ where: { id: event.familyId }, select: { timezone: true } }),
      transaction.choreRecord.findUnique({ where: { id: event.sourceId }, select: { occurredAt: true } }),
      transaction.choreRecord.findMany({
        where: { familyId: event.familyId, userId, deletedAt: null },
        select: {
          id: true,
          occurredAt: true,
          actualMinutes: true,
          chore: { select: { catalogKey: true, themeKey: true, category: true, isCustom: true } },
        },
      }),
      transaction.achievementDefinition.findMany({
        where: {
          key: { in: [...HIDDEN_ACHIEVEMENT_KEYS] },
          ownerType: AchievementOwnerType.MEMBER,
          isActive: true,
          isHidden: true,
        },
      }),
    ]);
    if (!family) throw new Error(`FAMILY_NOT_FOUND:${event.familyId}`);
    const timezoneByRecord = await this.timezoneSnapshotsByRecord(transaction, event.familyId, records.map((record) => record.id));
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
    const anchorDateKey = getLocalDateKeyForTimeZone(
      sourceRecord?.occurredAt ?? event.occurredAt,
      event.familyTimezoneSnapshot,
    );
    const metrics = calculateHiddenMetrics(metricRecords, anchorDateKey);
    const ownerKey = `${event.familyId}:${userId}`;
    const existingUnlocks = await transaction.memberAchievement.findMany({
      where: { familyId: event.familyId, userId, achievementKey: { in: [...HIDDEN_ACHIEVEMENT_KEYS] } },
    });
    const unlockByDefinition = new Map(existingUnlocks.map((unlock) => [unlock.definitionId, unlock]));
    let unlockBatch = await transaction.achievementUnlockBatch.findUnique({ where: { triggerEventId: event.id } });
    const unlockedKeys: string[] = [];

    for (const definition of definitions) {
      const currentValue = this.currentValue(definition.key, metrics);
      const wasUnlocked = unlockByDefinition.has(definition.id);
      const achieved = wasUnlocked || currentValue >= definition.targetValue;
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
          rawCurrentValue: currentValue,
          displayCurrentValue: achieved ? Math.max(currentValue, definition.targetValue) : currentValue,
          progressStatus: achieved ? AchievementProgressStatus.COMPLETED : AchievementProgressStatus.ACTIVE,
          lastEventId: event.id,
        },
      });
      if (!achieved || wasUnlocked) continue;

      unlockBatch ??= await transaction.achievementUnlockBatch.create({ data: { familyId: event.familyId, triggerEventId: event.id } });
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
          actionType: 'HIDDEN_ACHIEVEMENT_DISCOVERED',
          entityType: 'MemberAchievement',
          entityId: unlock.id,
          afterJson: { achievementKey: definition.key, triggerEventId: event.id },
        },
      });
    }
    return { progressUpdateCount: definitions.length, unlockedKeys };
  }

  private currentValue(key: string, metrics: HiddenMetrics) {
    if (key === 'HIDDEN_DISHES_3') return metrics.dishes;
    if (key === 'HIDDEN_SHINY_FLOOR') return metrics.shinyFloor;
    if (key === 'HIDDEN_GUESTS') return metrics.guests;
    if (key === 'HIDDEN_NIGHT_SHIFT') return metrics.nightShift;
    return metrics.endurance;
  }

  private subjectUserId(event: AchievementEvent) {
    const payload = event.payloadJson && typeof event.payloadJson === 'object' && !Array.isArray(event.payloadJson)
      ? event.payloadJson as Prisma.JsonObject
      : {};
    const value = event.eventType === 'CHORE_CREATED' ? payload.userId : payload.recordUserId;
    return typeof value === 'string' && value ? value : event.actorUserId;
  }

  private async timezoneSnapshotsByRecord(transaction: Prisma.TransactionClient, familyId: string, recordIds: string[]) {
    if (recordIds.length === 0) return new Map<string, string>();
    const events = await transaction.achievementEvent.findMany({
      where: { familyId, eventType: 'CHORE_CREATED', sourceId: { in: recordIds } },
      select: { sourceId: true, familyTimezoneSnapshot: true },
    });
    return new Map(events.map((item) => [item.sourceId, item.familyTimezoneSnapshot]));
  }
}
