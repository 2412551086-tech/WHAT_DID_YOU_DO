import { Injectable } from '@nestjs/common';
import {
  AchievementEvent,
  AchievementOwnerType,
  AchievementProgressStatus,
  MemberStatus,
  Prisma,
} from '@prisma/client';
import { getDayRangeForTimeZone } from '../common/timezone-ranges';
import { PAIR_ACHIEVEMENT_KEYS } from './achievement-bond.constants';
import { classifyMasteryRecord } from './achievement-mastery-taxonomy';

@Injectable()
export class AchievementPairService {
  async process(transaction: Prisma.TransactionClient, event: AchievementEvent) {
    if (!['CHORE_CREATED', 'CHORE_UPDATED', 'CHORE_DELETED', 'CHORE_RESTORED', 'MEMBER_JOINED', 'MEMBER_LEFT'].includes(event.eventType)) {
      return { progressUpdateCount: 0, unlockedKeys: [] as string[] };
    }

    await transaction.$executeRaw(
      Prisma.sql`SELECT pg_advisory_xact_lock(hashtext(${`achievement-family:${event.familyId}`}))`,
    );
    const [family, activeMembers, definition] = await Promise.all([
      transaction.family.findUnique({
        where: { id: event.familyId },
        select: { timezone: true },
      }),
      transaction.familyMember.findMany({
        where: { familyId: event.familyId, status: MemberStatus.ACTIVE },
        select: { userId: true },
      }),
      transaction.achievementDefinition.findFirst({
        where: {
          key: PAIR_ACHIEVEMENT_KEYS[0],
          ownerType: AchievementOwnerType.PAIR,
          isActive: true,
        },
      }),
    ]);
    if (!family || !definition || activeMembers.length < 2) {
      return { progressUpdateCount: 0, unlockedKeys: [] as string[] };
    }

    const range = getDayRangeForTimeZone(family.timezone, event.occurredAt);
    const activeIds = new Set(activeMembers.map((member) => member.userId));
    const records = await transaction.choreRecord.findMany({
      where: {
        familyId: event.familyId,
        deletedAt: null,
        occurredAt: { gte: range.start, lt: range.end },
        userId: { in: [...activeIds] },
      },
      select: {
        userId: true,
        chore: {
          select: { catalogKey: true, themeKey: true, category: true, isCustom: true },
        },
      },
    });
    const cookingUsers = new Set<string>();
    const dishesUsers = new Set<string>();
    for (const record of records) {
      const category = classifyMasteryRecord(record.chore).subcategory;
      if (category === 'cooking') cookingUsers.add(record.userId);
      if (category === 'dishes') dishesUsers.add(record.userId);
    }

    const pairs = new Map<string, [string, string]>();
    for (const cookingUserId of cookingUsers) {
      for (const dishesUserId of dishesUsers) {
        if (cookingUserId === dishesUserId) continue;
        const pair = [cookingUserId, dishesUserId].sort() as [string, string];
        pairs.set(`${pair[0]}:${pair[1]}`, pair);
      }
    }
    if (pairs.size === 0) {
      return { progressUpdateCount: 0, unlockedKeys: [] as string[] };
    }

    let unlockBatch = await transaction.achievementUnlockBatch.findUnique({
      where: { triggerEventId: event.id },
    });
    const unlockedKeys: string[] = [];
    for (const [pairKey, [memberAId, memberBId]] of pairs) {
      const ownerKey = `${event.familyId}:${pairKey}`;
      const existing = await transaction.pairAchievement.findUnique({
        where: {
          familyId_memberAId_memberBId_achievementKey_tier_definitionVersion: {
            familyId: event.familyId,
            memberAId,
            memberBId,
            achievementKey: definition.key,
            tier: definition.tier,
            definitionVersion: definition.definitionVersion,
          },
        },
      });
      await transaction.achievementProgress.upsert({
        where: {
          ownerType_ownerKey_achievementKey_tier_definitionVersion: {
            ownerType: AchievementOwnerType.PAIR,
            ownerKey,
            achievementKey: definition.key,
            tier: definition.tier,
            definitionVersion: definition.definitionVersion,
          },
        },
        create: {
          ownerType: AchievementOwnerType.PAIR,
          ownerKey,
          familyId: event.familyId,
          definitionId: definition.id,
          achievementKey: definition.key,
          tier: definition.tier,
          definitionVersion: definition.definitionVersion,
          rawCurrentValue: 1,
          displayCurrentValue: 1,
          targetValue: definition.targetValue,
          progressStatus: AchievementProgressStatus.COMPLETED,
          lastEventId: event.id,
        },
        update: {
          rawCurrentValue: 1,
          displayCurrentValue: 1,
          progressStatus: AchievementProgressStatus.COMPLETED,
          lastEventId: event.id,
        },
      });
      if (existing) continue;
      unlockBatch ??= await transaction.achievementUnlockBatch.create({
        data: { familyId: event.familyId, triggerEventId: event.id },
      });
      const unlock = await transaction.pairAchievement.create({
        data: {
          familyId: event.familyId,
          memberAId,
          memberBId,
          definitionId: definition.id,
          achievementKey: definition.key,
          tier: definition.tier,
          definitionVersion: definition.definitionVersion,
          unlockBatchId: unlockBatch.id,
          triggerEventId: event.id,
          unlockedAt: event.occurredAt,
        },
      });
      unlockedKeys.push(`${definition.key}:${memberAId}:${memberBId}`);
      await transaction.achievementAuditLog.create({
        data: {
          familyId: event.familyId,
          actorUserId: event.actorUserId,
          actionType: 'ACHIEVEMENT_UNLOCKED',
          entityType: 'PairAchievement',
          entityId: unlock.id,
          afterJson: {
            achievementKey: definition.key,
            memberAId,
            memberBId,
            triggerEventId: event.id,
          },
        },
      });
    }

    return { progressUpdateCount: pairs.size, unlockedKeys };
  }
}
