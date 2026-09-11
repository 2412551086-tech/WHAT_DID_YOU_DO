import { ForbiddenException, Injectable } from '@nestjs/common';
import {
  AchievementEventStatus,
  AchievementOwnerType,
  AchievementProgressStatus,
  AchievementRewardType,
  MemberRole,
  MemberStatus,
  Prisma,
} from '@prisma/client';
import { AuthUser } from '../auth/auth-user';
import { PrismaService } from '../prisma/prisma.service';
import { achievementWorkerConfig, isAchievementsEnabledForFamily } from './achievement-config';
import { AchievementEventProcessorService } from './achievement-event-processor.service';
import { AchievementWorkerService } from './achievement-worker.service';

@Injectable()
export class AchievementMaintenanceService {
  private readonly config = achievementWorkerConfig();

  constructor(
    private readonly prisma: PrismaService,
    private readonly processor: AchievementEventProcessorService,
    private readonly worker: AchievementWorkerService,
  ) {}

  async health(user: AuthUser, familyId: string) {
    await this.assertOwner(familyId, user.id);
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 86_400_000);
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 86_400_000);
    const [events, dirtyCount, rebuildingCount, batchMismatchCount, rewardIssueCount, activeMembers, unlockCount, recentRecords, deletedRecords, memberExits] = await Promise.all([
      this.prisma.achievementEvent.groupBy({
        by: ['processStatus'],
        where: { familyId },
        _count: { _all: true },
      }),
      this.prisma.achievementProgress.count({
        where: { familyId, progressStatus: AchievementProgressStatus.DIRTY },
      }),
      this.prisma.achievementProgress.count({
        where: { familyId, progressStatus: AchievementProgressStatus.REBUILDING },
      }),
      this.batchMismatchCount(familyId),
      this.rewardIssueCount(familyId),
      this.prisma.familyMember.count({ where: { familyId, status: MemberStatus.ACTIVE } }),
      this.prisma.achievementUnlockBatch.count({ where: { familyId } }),
      this.prisma.choreRecord.count({ where: { familyId, createdAt: { gte: sevenDaysAgo } } }),
      this.prisma.choreRecord.count({ where: { familyId, deletedAt: { gte: sevenDaysAgo } } }),
      this.prisma.familyMember.count({ where: { familyId, leftAt: { gte: thirtyDaysAgo } } }),
    ]);
    const oldestPending = await this.prisma.achievementEvent.findFirst({
      where: {
        familyId,
        processStatus: { in: [AchievementEventStatus.PENDING, AchievementEventStatus.PROCESSING] },
      },
      orderBy: { receivedAt: 'asc' },
      select: { receivedAt: true },
    });
    const counts = Object.fromEntries(events.map((item) => [item.processStatus, item._count._all]));
    const deadLetterCount = await this.prisma.achievementEvent.count({
      where: {
        familyId,
        processStatus: AchievementEventStatus.FAILED,
        retryCount: { gte: this.config.maxRetries },
      },
    });

    return {
      familyId,
      enabled: isAchievementsEnabledForFamily(familyId),
      eventCounts: {
        pending: counts.PENDING ?? 0,
        processing: counts.PROCESSING ?? 0,
        succeeded: counts.SUCCEEDED ?? 0,
        failed: counts.FAILED ?? 0,
        deadLetter: deadLetterCount,
      },
      progress: { dirty: dirtyCount, rebuilding: rebuildingCount },
      consistency: { unlockBatchMismatches: batchMismatchCount, rewardIssues: rewardIssueCount },
      oldestBacklogAgeMs: oldestPending ? now.getTime() - oldestPending.receivedAt.getTime() : 0,
      productSignals: {
        activeMembers,
        unlockBatchCount: unlockCount,
        recordsLast7Days: recentRecords,
      },
      negativeSignals: {
        deletedRecordsLast7Days: deletedRecords,
        memberExitsLast30Days: memberExits,
      },
      runtime: this.worker.getRuntimeMetrics(),
      checkedAt: now,
    };
  }

  async reconcile(user: AuthUser, familyId: string) {
    await this.assertOwner(familyId, user.id);
    const before = await this.health(user, familyId);
    const result = await this.prisma.$transaction(async (transaction) => {
      const dirty = await transaction.achievementProgress.findMany({
        where: {
          familyId,
          progressStatus: { in: [AchievementProgressStatus.DIRTY, AchievementProgressStatus.REBUILDING] },
          lastEventId: { not: null },
        },
        select: { id: true, lastEventId: true },
      });
      await transaction.achievementProgress.updateMany({
        where: { id: { in: dirty.map((item) => item.id) } },
        data: { progressStatus: AchievementProgressStatus.REBUILDING },
      });
      const eventIds = [...new Set(dirty.flatMap((item) => item.lastEventId ? [item.lastEventId] : []))];
      for (const eventId of eventIds) {
        const event = await transaction.achievementEvent.findUnique({ where: { id: eventId } });
        if (event) await this.processor.process(transaction, event);
      }

      const batches = await transaction.achievementUnlockBatch.findMany({
        where: { familyId },
        include: {
          memberUnlocks: { select: { id: true } },
          familyUnlocks: { select: { id: true } },
          pairUnlocks: { select: { id: true } },
        },
      });
      let repairedBatches = 0;
      for (const batch of batches) {
        const ids = [
          ...batch.memberUnlocks.map((item) => item.id),
          ...batch.familyUnlocks.map((item) => item.id),
          ...batch.pairUnlocks.map((item) => item.id),
        ];
        const primaryUnlockId = ids.includes(batch.primaryUnlockId ?? '') ? batch.primaryUnlockId : ids[0] ?? null;
        if (batch.unlockCount !== ids.length || batch.primaryUnlockId !== primaryUnlockId) {
          await transaction.achievementUnlockBatch.update({
            where: { id: batch.id },
            data: { unlockCount: ids.length, primaryUnlockId },
          });
          repairedBatches += 1;
        }
      }

      const rewardDefinitions = await transaction.achievementDefinition.findMany({
        where: { isActive: true, rewardConfigJson: { not: Prisma.JsonNull } },
      });
      let repairedRewards = 0;
      for (const definition of rewardDefinitions) {
        const reward = this.rewardConfig(definition.rewardConfigJson);
        if (!reward) continue;
        const unlock = await transaction.memberAchievement.findFirst({
          where: { familyId, definitionId: definition.id },
          orderBy: { unlockedAt: 'asc' },
        });
        if (!unlock) continue;
        const existing = await transaction.familyRewardGrant.findUnique({
          where: {
            familyId_achievementKey_rewardType: {
              familyId,
              achievementKey: definition.key,
              rewardType: reward.type,
            },
          },
        });
        if (!existing) {
          await transaction.familyRewardGrant.create({
            data: {
              familyId,
              achievementKey: definition.key,
              rewardType: reward.type,
              rewardValue: reward.value,
              grantedByUserId: unlock.userId,
              triggerEventId: unlock.triggerEventId,
              grantedAt: unlock.unlockedAt,
            },
          });
          repairedRewards += 1;
        }
      }
      await transaction.achievementAuditLog.create({
        data: {
          familyId,
          actorUserId: user.id,
          actionType: 'ACHIEVEMENT_RECONCILIATION_COMPLETED',
          entityType: 'Family',
          entityId: familyId,
          afterJson: {
            rebuiltEventCount: eventIds.length,
            repairedBatches,
            repairedRewards,
          },
        },
      });
      return { rebuiltEventCount: eventIds.length, repairedBatches, repairedRewards };
    });
    return { familyId, before, result, after: await this.health(user, familyId) };
  }

  private async batchMismatchCount(familyId: string) {
    const batches = await this.prisma.achievementUnlockBatch.findMany({
      where: { familyId },
      include: {
        memberUnlocks: { select: { id: true } },
        familyUnlocks: { select: { id: true } },
        pairUnlocks: { select: { id: true } },
      },
    });
    return batches.filter((batch) => {
      const ids = [...batch.memberUnlocks, ...batch.familyUnlocks, ...batch.pairUnlocks].map((item) => item.id);
      return batch.unlockCount !== ids.length || (ids.length > 0 && !ids.includes(batch.primaryUnlockId ?? ''));
    }).length;
  }

  private async rewardIssueCount(familyId: string) {
    const grants = await this.prisma.familyRewardGrant.findMany({ where: { familyId } });
    let issues = 0;
    for (const grant of grants) {
      const unlockCount = await this.prisma.memberAchievement.count({
        where: { familyId, achievementKey: grant.achievementKey },
      });
      if (unlockCount === 0) issues += 1;
    }
    return issues;
  }

  private rewardConfig(value: Prisma.JsonValue) {
    if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
    const object = value as Prisma.JsonObject;
    if (typeof object.type !== 'string' || typeof object.value !== 'number') return null;
    if (!Object.values(AchievementRewardType).includes(object.type as AchievementRewardType)) return null;
    return { type: object.type as AchievementRewardType, value: object.value };
  }

  private async assertOwner(familyId: string, userId: string) {
    const member = await this.prisma.familyMember.findUnique({
      where: { userId_familyId: { userId, familyId } },
    });
    if (member?.status !== MemberStatus.ACTIVE || member.memberRole !== MemberRole.OWNER) {
      throw new ForbiddenException('Family owner permission required');
    }
  }
}
