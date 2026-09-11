import { Injectable } from '@nestjs/common';
import {
  AchievementEvent,
  AchievementOwnerType,
  AchievementProgressStatus,
  AchievementRuleType,
  AchievementTier,
  AchievementTrack,
  AchievementVisibility,
  Prisma,
} from '@prisma/client';
import { getLocalDateKeyForTimeZone } from '../common/timezone-ranges';
import { calculateMasteryValue, MasteryRule } from './achievement-mastery-metrics';
import {
  classifyMasteryRecord,
  isMasteryRuleEnabled,
  MASTERY_KEYS,
} from './achievement-mastery-taxonomy';

@Injectable()
export class AchievementMasteryService {
  async process(transaction: Prisma.TransactionClient, event: AchievementEvent) {
    if (!['CHORE_CREATED', 'CHORE_UPDATED', 'CHORE_DELETED', 'CHORE_RESTORED'].includes(event.eventType)) {
      return { progressUpdateCount: 0, unlockedKeys: [] as string[] };
    }

    const userId = this.subjectUserId(event);
    if (!userId) {
      throw new Error(`MISSING_ACHIEVEMENT_SUBJECT:${event.id}`);
    }

    const membership = await transaction.familyMember.findUnique({
      where: { userId_familyId: { userId, familyId: event.familyId } },
      select: { showAchievementsToFamily: true },
    });
    const [family, records, definitions] = await Promise.all([
      transaction.family.findUnique({
        where: { id: event.familyId },
        select: { timezone: true, choreOrder: true },
      }),
      transaction.choreRecord.findMany({
        where: { familyId: event.familyId, userId, deletedAt: null },
        select: {
          id: true,
          occurredAt: true,
          actualMinutes: true,
          chore: {
            select: {
              catalogKey: true,
              themeKey: true,
              category: true,
              isCustom: true,
            },
          },
        },
      }),
      transaction.achievementDefinition.findMany({
        where: {
          key: { in: [...MASTERY_KEYS] },
          ownerType: AchievementOwnerType.MEMBER,
          track: AchievementTrack.MASTERY,
          isActive: true,
        },
        orderBy: [{ key: 'asc' }, { targetValue: 'asc' }],
      }),
    ]);

    if (!family) {
      throw new Error(`FAMILY_NOT_FOUND:${event.familyId}`);
    }

    const enabledThemes = await this.enabledThemes(transaction, family.choreOrder);
    const eligibleDefinitions = definitions.filter((definition) =>
      isMasteryRuleEnabled(definition.ruleConfigJson, enabledThemes),
    );
    const timezoneByRecord = await this.timezoneSnapshotsByRecord(
      transaction,
      event.familyId,
      records.map((record) => record.id),
    );
    const metricRecords = records.map((record) => {
      const taxonomy = classifyMasteryRecord(record.chore);
      return {
        localDateKey: getLocalDateKeyForTimeZone(
          record.occurredAt,
          timezoneByRecord.get(record.id) ?? family.timezone,
        ),
        subcategory: taxonomy.subcategory,
        standardCategory: taxonomy.standardCategory,
        themeKey: record.chore.themeKey,
        actualMinutes: record.actualMinutes,
      };
    });
    const anchorMonthKey = getLocalDateKeyForTimeZone(
      event.occurredAt,
      event.familyTimezoneSnapshot,
    ).slice(0, 7);
    const ownerKey = `${event.familyId}:${userId}`;
    const existingUnlocks = await transaction.memberAchievement.findMany({
      where: { userId, familyId: event.familyId, achievementKey: { in: [...MASTERY_KEYS] } },
    });
    const unlockByDefinition = new Map(existingUnlocks.map((unlock) => [unlock.definitionId, unlock]));
    let unlockBatch = await transaction.achievementUnlockBatch.findUnique({
      where: { triggerEventId: event.id },
    });
    const newlyUnlocked: Array<{ id: string; key: string; tier: AchievementTier }> = [];

    await transaction.achievementProgress.updateMany({
      where: {
        ownerType: AchievementOwnerType.MEMBER,
        ownerKey,
        achievementKey: { in: [...MASTERY_KEYS] },
      },
      data: { progressStatus: AchievementProgressStatus.DIRTY, lastEventId: event.id },
    });

    for (const definition of eligibleDefinitions) {
      const rule = this.rule(definition.ruleConfigJson, definition.ruleType, definition.maxDailyContribution);
      const currentValue = calculateMasteryValue(metricRecords, rule, anchorMonthKey);
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
          definitionId: definition.id,
          familyId: event.familyId,
          rawCurrentValue: currentValue,
          displayCurrentValue: achieved ? Math.max(currentValue, definition.targetValue) : currentValue,
          targetValue: definition.targetValue,
          progressStatus: achieved ? AchievementProgressStatus.COMPLETED : AchievementProgressStatus.ACTIVE,
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
      newlyUnlocked.push({ id: unlock.id, key: definition.key, tier: definition.tier });
      await transaction.achievementAuditLog.create({
        data: {
          familyId: event.familyId,
          actorUserId: userId,
          actionType: 'ACHIEVEMENT_UNLOCKED',
          entityType: 'MemberAchievement',
          entityId: unlock.id,
          afterJson: {
            achievementKey: definition.key,
            tier: definition.tier,
            definitionVersion: definition.definitionVersion,
            triggerEventId: event.id,
          },
        },
      });
    }

    return {
      progressUpdateCount: eligibleDefinitions.length,
      unlockedKeys: newlyUnlocked.map((unlock) => `${unlock.key}:${unlock.tier}`),
    };
  }

  private async enabledThemes(transaction: Prisma.TransactionClient, choreOrder: string[]) {
    if (choreOrder.length === 0) {
      return new Set(['daily']);
    }
    const chores = await transaction.chore.findMany({
      where: { id: { in: choreOrder }, archivedAt: null },
      select: { themeKey: true },
    });
    return new Set(['daily', ...chores.map((chore) => chore.themeKey)]);
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
      where: { familyId, eventType: 'CHORE_CREATED', sourceId: { in: recordIds } },
      select: { sourceId: true, familyTimezoneSnapshot: true },
    });
    return new Map(events.map((item) => [item.sourceId, item.familyTimezoneSnapshot]));
  }

  private rule(
    value: Prisma.JsonValue,
    ruleType: AchievementRuleType,
    maxDailyContribution: number | null,
  ): MasteryRule {
    const object = value && typeof value === 'object' && !Array.isArray(value)
      ? value as Prisma.JsonObject
      : {};
    const values = (key: string) => Array.isArray(object[key])
      ? (object[key] as Prisma.JsonArray).filter((item): item is string => typeof item === 'string')
      : undefined;
    return {
      metric: ruleType === AchievementRuleType.DURATION
        ? 'duration'
        : ruleType === AchievementRuleType.CATEGORY_COVERAGE
          ? 'category_coverage'
          : 'count',
      subcategories: values('subcategories'),
      themes: values('themes'),
      maxDailyContribution,
    };
  }

  private subjectUserId(event: AchievementEvent) {
    const payload = event.payloadJson && typeof event.payloadJson === 'object' && !Array.isArray(event.payloadJson)
      ? event.payloadJson as Prisma.JsonObject
      : {};
    const value = event.eventType === 'CHORE_CREATED' ? payload.userId : payload.recordUserId;
    return typeof value === 'string' && value ? value : event.actorUserId;
  }
}
