import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { AchievementEventStatus, MemberRole, MemberStatus } from '@prisma/client';
import { AuthUser } from '../auth/auth-user';
import { PrismaService } from '../prisma/prisma.service';
import { achievementWorkerConfig } from './achievement-config';

@Injectable()
export class AchievementEventsService {
  private readonly config = achievementWorkerConfig();

  constructor(private readonly prisma: PrismaService) {}

  async getSyncState(user: AuthUser, familyId: string, eventId: string) {
    await this.assertActiveMember(familyId, user.id);
    const event = await this.findFamilyEvent(familyId, eventId);
    const [unlockBatch, rewards] = await Promise.all([
      this.prisma.achievementUnlockBatch.findUnique({
        where: { triggerEventId: event.id },
        include: {
          memberUnlocks: {
            where: { userId: user.id },
            select: {
              id: true,
              achievementKey: true,
              tier: true,
              unlockedAt: true,
              visibility: true,
            },
          },
          familyUnlocks: {
            select: {
              id: true,
              achievementKey: true,
              tier: true,
              unlockedAt: true,
            },
          },
          pairUnlocks: {
            where: { OR: [{ memberAId: user.id }, { memberBId: user.id }] },
            select: {
              id: true,
              achievementKey: true,
              tier: true,
              unlockedAt: true,
            },
          },
        },
      }),
      this.prisma.familyRewardGrant.findMany({
        where: { triggerEventId: event.id },
        select: {
          achievementKey: true,
          rewardType: true,
          rewardValue: true,
          grantedAt: true,
        },
      }),
    ]);
    return {
      ...this.formatEvent(event),
      unlockBatch: unlockBatch
        ? (() => {
            const sharedUnlocks = [
              ...unlockBatch.familyUnlocks,
              ...unlockBatch.pairUnlocks,
            ].map((unlock) => ({ ...unlock, visibility: 'FAMILY' as const }));
            const unlocks = [...unlockBatch.memberUnlocks, ...sharedUnlocks];
            return {
            id: unlockBatch.id,
            primaryUnlockId: unlockBatch.primaryUnlockId,
            unlockCount: unlocks.length,
            unlocks,
            rewards,
            };
          })()
        : null,
    };
  }

  async getFailedEvents(user: AuthUser, familyId: string) {
    await this.assertOwner(familyId, user.id);
    const events = await this.prisma.achievementEvent.findMany({
      where: {
        familyId,
        processStatus: AchievementEventStatus.FAILED,
        retryCount: { gte: this.config.maxRetries },
      },
      orderBy: { receivedAt: 'desc' },
      take: 100,
    });

    return events.map((event) => this.formatEvent(event));
  }

  async replayFailedEvent(user: AuthUser, familyId: string, eventId: string) {
    await this.assertOwner(familyId, user.id);
    const event = await this.findFamilyEvent(familyId, eventId);

    if (event.processStatus !== AchievementEventStatus.FAILED) {
      throw new ConflictException('Only failed achievement events can be replayed');
    }

    const replayed = await this.prisma.$transaction(async (transaction) => {
      const updated = await transaction.achievementEvent.update({
        where: { id: event.id },
        data: {
          processStatus: AchievementEventStatus.PENDING,
          retryCount: 0,
          nextAttemptAt: new Date(),
          processedAt: null,
          lastErrorCode: null,
        },
      });
      await transaction.achievementAuditLog.create({
        data: {
          familyId,
          actorUserId: user.id,
          actionType: 'EVENT_REPLAY_REQUESTED',
          entityType: 'AchievementEvent',
          entityId: event.id,
          beforeJson: {
            processStatus: event.processStatus,
            retryCount: event.retryCount,
            lastErrorCode: event.lastErrorCode,
          },
          afterJson: {
            processStatus: AchievementEventStatus.PENDING,
            retryCount: 0,
          },
        },
      });
      return updated;
    });

    return this.formatEvent(replayed);
  }

  private async assertActiveMember(familyId: string, userId: string) {
    const membership = await this.prisma.familyMember.findUnique({
      where: { userId_familyId: { userId, familyId } },
    });
    if (membership?.status !== MemberStatus.ACTIVE) {
      throw new ForbiddenException('Active family membership required');
    }
    return membership;
  }

  private async assertOwner(familyId: string, userId: string) {
    const membership = await this.assertActiveMember(familyId, userId);
    if (membership.memberRole !== MemberRole.OWNER) {
      throw new ForbiddenException('Family owner permission required');
    }
  }

  private async findFamilyEvent(familyId: string, eventId: string) {
    const event = await this.prisma.achievementEvent.findFirst({
      where: { id: eventId, familyId },
    });
    if (!event) {
      throw new NotFoundException('Achievement event not found');
    }
    return event;
  }

  private formatEvent(event: {
    id: string;
    eventType: string;
    sourceType: string;
    sourceId: string;
    sourceVersion: number;
    processStatus: AchievementEventStatus;
    retryCount: number;
    nextAttemptAt: Date;
    receivedAt: Date;
    processedAt: Date | null;
    lastErrorCode: string | null;
  }) {
    return {
      eventId: event.id,
      eventType: event.eventType,
      sourceType: event.sourceType,
      sourceId: event.sourceId,
      sourceVersion: event.sourceVersion,
      state: event.processStatus,
      retryCount: event.retryCount,
      retryAfterMs:
        event.processStatus === AchievementEventStatus.PENDING ||
        event.processStatus === AchievementEventStatus.FAILED
          ? Math.max(0, event.nextAttemptAt.getTime() - Date.now())
          : null,
      receivedAt: event.receivedAt,
      processedAt: event.processedAt,
      lastErrorCode: event.lastErrorCode,
      isDeadLetter:
        event.processStatus === AchievementEventStatus.FAILED &&
        event.retryCount >= this.config.maxRetries,
    };
  }
}
