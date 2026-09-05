import { Injectable } from '@nestjs/common';
import {
  AchievementEvent,
  AchievementOwnerType,
  AchievementPeriodType,
  AchievementProgressStatus,
  MemberStatus,
  Prisma,
} from '@prisma/client';
import {
  getDayRangeForTimeZone,
  getLocalDateKeyForTimeZone,
  getMonthRangeForTimeZone,
  getWeekRangeForTimeZone,
} from '../common/timezone-ranges';
import { FAMILY_COLLABORATION_KEYS } from './achievement-bond.constants';
import { classifyMasteryRecord } from './achievement-mastery-taxonomy';

type CollaborationRecord = {
  userId: string;
  occurredAt: Date;
  subcategory: string | null;
  standardCategory: string | null;
};

type FamilyMetric = {
  value: number;
  participantIds: string[];
  summary: Prisma.InputJsonValue;
};

@Injectable()
export class AchievementFamilyCollaborationService {
  async process(transaction: Prisma.TransactionClient, event: AchievementEvent) {
    if (!['CHORE_CREATED', 'CHORE_UPDATED', 'CHORE_DELETED', 'CHORE_RESTORED', 'MEMBER_JOINED', 'MEMBER_LEFT'].includes(event.eventType)) {
      return { progressUpdateCount: 0, unlockedKeys: [] as string[] };
    }

    await transaction.$executeRaw(
      Prisma.sql`SELECT pg_advisory_xact_lock(hashtext(${`achievement-family:${event.familyId}`}))`,
    );

    const [family, activeMembers] = await Promise.all([
      transaction.family.findUnique({
        where: { id: event.familyId },
        select: { timezone: true },
      }),
      transaction.familyMember.findMany({
        where: { familyId: event.familyId, status: MemberStatus.ACTIVE },
        select: { userId: true },
        orderBy: { approvedAt: 'asc' },
      }),
    ]);

    if (!family) {
      throw new Error(`FAMILY_NOT_FOUND:${event.familyId}`);
    }
    if (activeMembers.length < 2) {
      return { progressUpdateCount: 0, unlockedKeys: [] as string[] };
    }

    const [definitions, storedRecords] = await Promise.all([
      transaction.achievementDefinition.findMany({
        where: {
          key: { in: [...FAMILY_COLLABORATION_KEYS] },
          ownerType: AchievementOwnerType.FAMILY,
          isActive: true,
        },
      }),
      transaction.choreRecord.findMany({
        where: { familyId: event.familyId, deletedAt: null },
        select: {
          userId: true,
          occurredAt: true,
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
    ]);

    const activeMemberIds = activeMembers.map((member) => member.userId);
    const activeMemberSet = new Set(activeMemberIds);
    const records: CollaborationRecord[] = storedRecords.map((record) => {
      const taxonomy = classifyMasteryRecord(record.chore);
      return {
        userId: record.userId,
        occurredAt: record.occurredAt,
        subcategory: taxonomy.subcategory,
        standardCategory: taxonomy.standardCategory,
      };
    });
    const timezone = family.timezone;
    const dayRange = getDayRangeForTimeZone(timezone, event.occurredAt);
    const weekRange = getWeekRangeForTimeZone(timezone, event.occurredAt);
    const monthKey = getLocalDateKeyForTimeZone(event.occurredAt, timezone).slice(0, 7);
    const monthRange = getMonthRangeForTimeZone(monthKey, timezone);

    const weekSnapshot = activeMemberIds.length >= 2
      ? await this.getOrCreateSnapshot(
          transaction,
          event.familyId,
          AchievementPeriodType.WEEK,
          weekRange,
          timezone,
          activeMemberIds,
        )
      : null;
    if (activeMemberIds.length >= 2) {
      await this.getOrCreateSnapshot(
        transaction,
        event.familyId,
        AchievementPeriodType.MONTH,
        monthRange,
        timezone,
        activeMemberIds,
      );
    }

    const existingUnlocks = await transaction.familyAchievement.findMany({
      where: {
        familyId: event.familyId,
        achievementKey: { in: [...FAMILY_COLLABORATION_KEYS] },
      },
    });
    const unlockByDefinition = new Map(
      existingUnlocks.map((unlock) => [unlock.definitionId, unlock]),
    );
    const metrics = await this.metrics({
      transaction,
      familyId: event.familyId,
      timezone,
      activeMemberIds,
      activeMemberSet,
      records,
      dayRange,
      weekRange,
      monthRange,
      weekSnapshot,
      anchor: event.occurredAt,
    });
    let unlockBatch = await transaction.achievementUnlockBatch.findUnique({
      where: { triggerEventId: event.id },
    });
    const unlockedKeys: string[] = [];

    for (const definition of definitions) {
      const metric = metrics.get(definition.key) ?? {
        value: 0,
        participantIds: [],
        summary: { narrativeKey: 'achievement.family.not_ready' },
      };
      const wasUnlocked = unlockByDefinition.has(definition.id);
      const achieved = wasUnlocked || metric.value >= definition.targetValue;

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
          rawCurrentValue: metric.value,
          displayCurrentValue: achieved ? Math.max(metric.value, definition.targetValue) : metric.value,
          targetValue: definition.targetValue,
          progressStatus: achieved ? AchievementProgressStatus.COMPLETED : AchievementProgressStatus.ACTIVE,
          lastEventId: event.id,
        },
        update: {
          definitionId: definition.id,
          rawCurrentValue: metric.value,
          displayCurrentValue: achieved ? Math.max(metric.value, definition.targetValue) : metric.value,
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
      if (metric.participantIds.length > 0) {
        await transaction.familyAchievementParticipant.createMany({
          data: metric.participantIds.map((userId) => ({
            familyAchievementId: unlock.id,
            userId,
            contributionSummaryJson: metric.summary,
          })),
          skipDuplicates: true,
        });
      }
      unlockByDefinition.set(definition.id, unlock);
      unlockedKeys.push(definition.key);
      await transaction.achievementAuditLog.create({
        data: {
          familyId: event.familyId,
          actorUserId: event.actorUserId,
          actionType: 'ACHIEVEMENT_UNLOCKED',
          entityType: 'FamilyAchievement',
          entityId: unlock.id,
          afterJson: {
            achievementKey: definition.key,
            participantCount: metric.participantIds.length,
            narrative: metric.summary,
            triggerEventId: event.id,
          },
        },
      });
    }

    return { progressUpdateCount: definitions.length, unlockedKeys };
  }

  private async metrics(input: {
    transaction: Prisma.TransactionClient;
    familyId: string;
    timezone: string;
    activeMemberIds: string[];
    activeMemberSet: Set<string>;
    records: CollaborationRecord[];
    dayRange: { start: Date; end: Date };
    weekRange: { start: Date; end: Date };
    monthRange: { start: Date; end: Date };
    weekSnapshot: { eligibleMemberIdsJson: Prisma.JsonValue } | null;
    anchor: Date;
  }) {
    const dayRecords = this.inRange(input.records, input.dayRange).filter((record) =>
      input.activeMemberSet.has(record.userId),
    );
    const weekRecords = this.inRange(input.records, input.weekRange);
    const monthRecords = this.inRange(input.records, input.monthRange).filter((record) =>
      input.activeMemberSet.has(record.userId),
    );
    const dayParticipants = this.uniqueUsers(dayRecords);
    const snapshotMemberIds = this.snapshotMemberIds(input.weekSnapshot?.eligibleMemberIdsJson);
    const allInParticipants = snapshotMemberIds.filter((userId) =>
      weekRecords.some((record) => record.userId === userId),
    );
    const fullServiceCategories = new Set(
      dayRecords
        .map((record) => record.subcategory)
        .filter((category): category is string => ['cooking', 'dishes', 'floor'].includes(category ?? '')),
    );
    const fullServiceParticipants = this.uniqueUsers(
      dayRecords.filter((record) =>
        ['cooking', 'dishes', 'floor'].includes(record.subcategory ?? ''),
      ),
    );
    const monthCategories = new Set(
      monthRecords
        .map((record) => record.standardCategory)
        .filter((category): category is string => Boolean(category)),
    );
    const monthParticipants = this.uniqueUsers(monthRecords);
    const successfulWeeks = await this.consecutiveSuccessfulWeeks(
      input.transaction,
      input.familyId,
      input.timezone,
      input.records,
      input.anchor,
    );

    return new Map<string, FamilyMetric>([
      ['FAMILY_FORMED', {
        value: input.activeMemberIds.length,
        participantIds: input.activeMemberIds,
        summary: { narrativeKey: 'achievement.family.formed', memberCount: input.activeMemberIds.length },
      }],
      ['FAMILY_ALL_IN', {
        value: snapshotMemberIds.length >= 2 && allInParticipants.length === snapshotMemberIds.length ? 1 : 0,
        participantIds: allInParticipants,
        summary: { narrativeKey: 'achievement.family.all_in', activeMemberCount: allInParticipants.length },
      }],
      ['FAMILY_RELAY', {
        value: dayParticipants.length,
        participantIds: dayParticipants,
        summary: { narrativeKey: 'achievement.family.relay', activeMemberCount: dayParticipants.length },
      }],
      ['FAMILY_VISIBLE_4W', {
        value: successfulWeeks.value,
        participantIds: successfulWeeks.participantIds,
        summary: { narrativeKey: 'achievement.family.visible_4w', successfulWeeks: successfulWeeks.value },
      }],
      ['FAMILY_FULL_SERVICE', {
        value: fullServiceParticipants.length >= 2 ? fullServiceCategories.size : 0,
        participantIds: fullServiceParticipants,
        summary: { narrativeKey: 'achievement.family.full_service', categoryCount: fullServiceCategories.size },
      }],
      ['FAMILY_CATEGORY_COVERAGE', {
        value: monthParticipants.length >= 2 ? monthCategories.size : 0,
        participantIds: monthParticipants,
        summary: { narrativeKey: 'achievement.family.category_coverage', categoryCount: monthCategories.size },
      }],
    ]);
  }

  private async consecutiveSuccessfulWeeks(
    transaction: Prisma.TransactionClient,
    familyId: string,
    timezone: string,
    records: CollaborationRecord[],
    anchor: Date,
  ) {
    let value = 0;
    const participants = new Set<string>();

    for (let offset = 0; offset >= -3; offset -= 1) {
      const range = getWeekRangeForTimeZone(timezone, anchor, offset);
      const snapshot = await transaction.achievementEligibilitySnapshot.findUnique({
        where: {
          familyId_periodType_periodStart: {
            familyId,
            periodType: AchievementPeriodType.WEEK,
            periodStart: range.start,
          },
        },
      });
      const memberIds = this.snapshotMemberIds(snapshot?.eligibleMemberIdsJson);
      if (memberIds.length < 2) break;
      const weekRecords = this.inRange(records, range);
      if (!memberIds.every((userId) => weekRecords.some((record) => record.userId === userId))) {
        break;
      }
      value += 1;
      memberIds.forEach((userId) => participants.add(userId));
    }

    return { value, participantIds: [...participants] };
  }

  private async getOrCreateSnapshot(
    transaction: Prisma.TransactionClient,
    familyId: string,
    periodType: AchievementPeriodType,
    range: { start: Date; end: Date },
    timezone: string,
    eligibleMemberIds: string[],
  ) {
    return transaction.achievementEligibilitySnapshot.upsert({
      where: {
        familyId_periodType_periodStart: { familyId, periodType, periodStart: range.start },
      },
      create: {
        familyId,
        periodType,
        periodStart: range.start,
        periodEnd: range.end,
        timezone,
        eligibleMemberIdsJson: eligibleMemberIds,
      },
      update: {},
    });
  }

  private inRange(records: CollaborationRecord[], range: { start: Date; end: Date }) {
    return records.filter(
      (record) => record.occurredAt >= range.start && record.occurredAt < range.end,
    );
  }

  private uniqueUsers(records: CollaborationRecord[]) {
    return [...new Set(records.map((record) => record.userId))];
  }

  private snapshotMemberIds(value: Prisma.JsonValue | undefined) {
    return Array.isArray(value)
      ? value.filter((item): item is string => typeof item === 'string')
      : [];
  }
}
