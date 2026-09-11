import { Injectable } from '@nestjs/common';
import {
  AchievementArchiveStatus,
  AchievementEvent,
  AchievementParticipantDisplayRole,
  MemberStatus,
  Prisma,
} from '@prisma/client';

@Injectable()
export class AchievementLifecycleService {
  async process(transaction: Prisma.TransactionClient, event: AchievementEvent) {
    if (!['MEMBER_JOINED', 'MEMBER_LEFT'].includes(event.eventType)) {
      return { participantUpdates: 0, pairArchiveUpdates: 0 };
    }
    const userId = this.subjectUserId(event);
    if (!userId) throw new Error(`MISSING_ACHIEVEMENT_SUBJECT:${event.id}`);
    const membership = await transaction.familyMember.findUnique({
      where: { userId_familyId: { userId, familyId: event.familyId } },
      select: { status: true },
    });
    const isActive = membership?.status === MemberStatus.ACTIVE;
    const [participants, pairs] = await Promise.all([
      transaction.familyAchievementParticipant.updateMany({
        where: {
          userId,
          familyAchievement: { familyId: event.familyId },
        },
        data: {
          displayRole: isActive
            ? AchievementParticipantDisplayRole.ACTIVE
            : AchievementParticipantDisplayRole.FORMER,
        },
      }),
      transaction.pairAchievement.updateMany({
        where: {
          familyId: event.familyId,
          OR: [{ memberAId: userId }, { memberBId: userId }],
        },
        data: {
          archiveStatus: isActive
            ? AchievementArchiveStatus.ACTIVE
            : AchievementArchiveStatus.HISTORICAL,
        },
      }),
    ]);

    await transaction.achievementAuditLog.create({
      data: {
        familyId: event.familyId,
        actorUserId: userId,
        actionType: isActive ? 'ACHIEVEMENT_MEMBER_REJOINED' : 'ACHIEVEMENT_MEMBER_LEFT',
        entityType: 'FamilyMember',
        entityId: userId,
        afterJson: {
          participantDisplayRole: isActive ? 'ACTIVE' : 'FORMER',
          pairArchiveStatus: isActive ? 'ACTIVE' : 'HISTORICAL',
        },
      },
    });
    return { participantUpdates: participants.count, pairArchiveUpdates: pairs.count };
  }

  private subjectUserId(event: AchievementEvent) {
    const payload = event.payloadJson && typeof event.payloadJson === 'object' && !Array.isArray(event.payloadJson)
      ? event.payloadJson as Prisma.JsonObject
      : {};
    return typeof payload.userId === 'string' ? payload.userId : event.actorUserId;
  }
}
