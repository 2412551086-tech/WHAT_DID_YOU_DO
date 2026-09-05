import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AchievementEventSourceType, MemberRole, MemberStatus, Prisma } from '@prisma/client';
import { AuthUser } from '../auth/auth-user';
import { ACHIEVEMENT_UNDO_WINDOW_MS } from '../achievements/achievement-config';
import { AchievementOutboxService } from '../achievements/achievement-outbox.service';
import { getDayRangeForTimeZone, getMonthRangeForTimeZone, getWeekRangeForTimeZone } from '../common/timezone-ranges';
import { FamiliesService } from '../families/families.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateChoreRecordDto } from './dto/create-chore-record.dto';
import { CHORE_REACTION_KEYS, ChoreReactionKey } from './dto/react-to-chore-record.dto';
import { UpdateChoreRecordDto } from './dto/update-chore-record.dto';

type RecordWithDetails = Prisma.ChoreRecordGetPayload<{
  include: {
    chore: true;
    user: {
      include: {
        memberships: true;
      };
    };
    likes: {
      include: {
        user: {
          include: {
            memberships: true;
          };
        };
      };
    };
    _count: {
      select: {
        likes: true;
      };
    };
  };
}>;

@Injectable()
export class ChoreRecordsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly familiesService: FamiliesService,
    private readonly achievementOutbox: AchievementOutboxService,
  ) {}

  async createRecord(user: AuthUser, dto: CreateChoreRecordDto, rawIdempotencyKey?: string) {
    const membership = await this.familiesService.assertActiveMember(dto.familyId, user.id);

    const family = await this.prisma.family.findUnique({
      where: { id: dto.familyId },
    });

    if (!family) {
      throw new NotFoundException('Family not found');
    }

    if (family.requirePhotoProof && !dto.imageUrls?.length) {
      throw new BadRequestException('Image proof is required for this family');
    }

    const chore = await this.prisma.chore.findUnique({ where: { id: dto.choreId } });

    if (!chore) {
      throw new NotFoundException('Chore not found');
    }

    if (chore.isCustom && (chore.familyId !== dto.familyId || chore.archivedAt)) {
      throw new NotFoundException('Custom chore not found in this family');
    }

    const actualMinutes = dto.actualMinutes ?? chore.standardMinutes;
    let points = this.calculatePoints(chore.defaultPoints, actualMinutes, chore.standardMinutes);
    let pointsMultiplier: number | null = null;
    const clientRequestId = this.normalizeIdempotencyKey(rawIdempotencyKey);

    if (dto.pointsMultiplier !== undefined) {
      const hasPremiumAccess = await this.familiesService.hasPremiumAccess(dto.familyId);
      if (!hasPremiumAccess) {
        throw new ForbiddenException('Custom points multiplier requires family premium access');
      }

      pointsMultiplier = Math.round(dto.pointsMultiplier * 10) / 10;
      points = Math.max(1, Math.round(actualMinutes * pointsMultiplier));
    }

    const existing = clientRequestId
      ? await this.prisma.choreRecord.findUnique({
          where: {
            familyId_userId_clientRequestId: {
              familyId: dto.familyId,
              userId: user.id,
              clientRequestId,
            },
          },
        })
      : null;
    if (existing) {
      return this.existingIdempotentRecord(
        existing,
        user,
        membership.memberRole,
        dto,
        actualMinutes,
        points,
      );
    }

    let created: { recordId: string; event: { id: string } | null };
    try {
      created = await this.prisma.$transaction(async (transaction) => {
        const createdRecord = await transaction.choreRecord.create({
          data: {
            familyId: dto.familyId,
            userId: user.id,
            choreId: chore.id,
            note: dto.note,
            imageUrls: dto.imageUrls ?? [],
            minutes: chore.standardMinutes,
            actualMinutes,
            points,
            pointsMultiplier,
            creatorDisplayNameSnapshot: user.displayName,
            creatorIdentityLabelSnapshot: membership.identityLabel,
            creatorCustomIdentitySnapshot: membership.customIdentity,
            creatorAvatarKeySnapshot: membership.avatarKey,
            clientRequestId,
          },
          select: {
            id: true,
            occurredAt: true,
          },
        });
        const event = await this.achievementOutbox.enqueue(transaction, {
          familyId: dto.familyId,
          actorUserId: user.id,
          eventType: 'CHORE_CREATED',
          sourceType: AchievementEventSourceType.CHORE,
          sourceId: createdRecord.id,
          sourceVersion: 1,
          occurredAt: createdRecord.occurredAt,
          familyTimezone: family.timezone,
          payload: {
            recordId: createdRecord.id,
            choreId: chore.id,
            userId: user.id,
            actualMinutes,
            points,
            themeKey: chore.themeKey,
            category: chore.category,
          },
        });
        return { recordId: createdRecord.id, event };
      });
    } catch (error) {
      if (!clientRequestId || !this.isUniqueConstraintError(error)) {
        throw error;
      }
      const racedRecord = await this.prisma.choreRecord.findUnique({
        where: {
          familyId_userId_clientRequestId: {
            familyId: dto.familyId,
            userId: user.id,
            clientRequestId,
          },
        },
      });
      if (!racedRecord) {
        throw error;
      }
      return this.existingIdempotentRecord(
        racedRecord,
        user,
        membership.memberRole,
        dto,
        actualMinutes,
        points,
      );
    }

    const record = await this.findRecordWithDetails(created.recordId, dto.familyId);

    if (!record) {
      throw new NotFoundException('Chore record not found');
    }

    return {
      ...this.formatRecord(record, user.id, membership.memberRole),
      ...this.evaluationResponse(created.event),
    };
  }

  async getActivity(
    user: AuthUser,
    familyId: string,
    range: 'day' | 'week' | 'recent' = 'recent',
    weekOffset = 0,
  ) {
    const membership = await this.familiesService.assertActiveMember(familyId, user.id);
    const timezone = range === 'recent' ? null : await this.familiesService.getFamilyTimeZone(familyId);
    const dateRange = timezone
      ? range === 'week'
        ? getWeekRangeForTimeZone(timezone, new Date(), weekOffset)
        : getDayRangeForTimeZone(timezone)
      : null;

    const records = await this.prisma.choreRecord.findMany({
      where: {
        familyId,
        deletedAt: null,
        ...(dateRange
          ? {
              createdAt: {
                gte: dateRange.start,
                lt: dateRange.end,
              },
            }
          : {}),
      },
      include: this.recordDetailsInclude(familyId),
      orderBy: {
        createdAt: 'desc',
      },
      take: range === 'recent' ? 30 : undefined,
    });

    return records.map((record) => this.formatRecord(record, user.id, membership.memberRole));
  }

  async getMemberActivity(user: AuthUser, familyId: string, memberId: string) {
    const currentMembership = await this.familiesService.assertActiveMember(familyId, user.id);
    const targetMembership = await this.prisma.familyMember.findFirst({
      where: {
        id: memberId,
        familyId,
        status: MemberStatus.ACTIVE,
      },
      select: { userId: true },
    });

    if (!targetMembership) {
      throw new NotFoundException('Active family member not found');
    }

    const start = new Date();
    start.setUTCDate(start.getUTCDate() - 30);

    const records = await this.prisma.choreRecord.findMany({
      where: {
        familyId,
        userId: targetMembership.userId,
        deletedAt: null,
        createdAt: { gte: start },
      },
      include: this.recordDetailsInclude(familyId),
      orderBy: { createdAt: 'desc' },
      take: 100,
    });

    return records.map((record) => this.formatRecord(record, user.id, currentMembership.memberRole));
  }

  async getLeaderboard(
    user: AuthUser,
    familyId: string,
    range: 'day' | 'week' | 'month' = 'month',
    weekOffset = 0,
  ) {
    await this.familiesService.assertActiveMember(familyId, user.id);
    const timezone = await this.familiesService.getFamilyTimeZone(familyId);
    const dateRange =
      range === 'day'
        ? getDayRangeForTimeZone(timezone)
        : range === 'week'
          ? getWeekRangeForTimeZone(timezone, new Date(), weekOffset)
          : getMonthRangeForTimeZone(this.currentMonthForTimeZone(timezone), timezone);

    const records = await this.prisma.choreRecord.findMany({
      where: {
        familyId,
        deletedAt: null,
        createdAt: {
          gte: dateRange.start,
          lt: dateRange.end,
        },
      },
      include: {
        user: true,
      },
    });

    const pointsByUser = new Map<string, { userId: string; displayName: string; points: number; recordCount: number }>();

    for (const record of records) {
      const current = pointsByUser.get(record.userId) ?? {
        userId: record.userId,
        displayName: record.user.displayName,
        points: 0,
        recordCount: 0,
      };

      current.points += record.points;
      current.recordCount += 1;
      pointsByUser.set(record.userId, current);
    }

    return Array.from(pointsByUser.values())
      .sort((left, right) => right.points - left.points)
      .map((entry, index) => ({
        rank: index + 1,
        ...entry,
      }));
  }

  async deleteRecord(user: AuthUser, recordId: string) {
    const record = await this.prisma.choreRecord.findFirst({
      where: {
        id: recordId,
        deletedAt: null,
      },
      include: {
        family: { select: { timezone: true } },
      },
    });

    if (!record) {
      throw new NotFoundException('Chore record not found');
    }

    const membership = await this.familiesService.assertActiveMember(record.familyId, user.id);
    const canDelete = record.userId === user.id || membership.memberRole === MemberRole.OWNER;

    if (!canDelete) {
      throw new ForbiddenException('You cannot delete this chore record');
    }

    const deletedAt = new Date();
    const deleted = await this.prisma.$transaction(async (transaction) => {
      const update = await transaction.choreRecord.updateMany({
        where: { id: record.id, deletedAt: null },
        data: {
          deletedAt,
          deletedById: user.id,
        },
      });
      if (update.count !== 1) {
        throw new ConflictException('This chore record has already been deleted');
      }
      const event = await this.achievementOutbox.enqueueNextVersion(transaction, {
        familyId: record.familyId,
        actorUserId: user.id,
        eventType: 'CHORE_DELETED',
        sourceType: AchievementEventSourceType.CHORE,
        sourceId: record.id,
        occurredAt: deletedAt,
        familyTimezone: record.family.timezone,
        payload: {
          recordId: record.id,
          recordUserId: record.userId,
          recordOccurredAt: record.occurredAt.toISOString(),
          deletedById: user.id,
        },
      });
      return { event };
    });

    return {
      recordId: record.id,
      deletedAt,
      deletedById: user.id,
      undoExpiresAt: new Date(deletedAt.getTime() + ACHIEVEMENT_UNDO_WINDOW_MS),
      ...this.evaluationResponse(deleted.event),
    };
  }

  async updateRecord(user: AuthUser, recordId: string, dto: UpdateChoreRecordDto) {
    const record = await this.prisma.choreRecord.findFirst({
      where: { id: recordId, deletedAt: null },
      include: { chore: true, family: { select: { timezone: true } } },
    });
    if (!record) {
      throw new NotFoundException('Chore record not found');
    }

    await this.familiesService.assertActiveMember(record.familyId, user.id);
    if (record.userId !== user.id) {
      throw new ForbiddenException('You can only edit your own chore records');
    }

    const actualMinutes = dto.actualMinutes;
    let points = this.calculatePoints(record.chore.defaultPoints, actualMinutes, record.chore.standardMinutes);
    let pointsMultiplier: number | null = null;
    if (dto.pointsMultiplier !== undefined) {
      const hasPremiumAccess = await this.familiesService.hasPremiumAccess(record.familyId);
      if (!hasPremiumAccess) {
        throw new ForbiddenException('Custom points multiplier requires family premium access');
      }
      pointsMultiplier = Math.round(dto.pointsMultiplier * 10) / 10;
      points = Math.max(1, Math.round(actualMinutes * pointsMultiplier));
    }

    const result = await this.prisma.$transaction(async (transaction) => {
      await transaction.choreRecord.update({
        where: { id: record.id },
        data: { actualMinutes, points, pointsMultiplier },
      });
      const event = await this.achievementOutbox.enqueueNextVersion(transaction, {
        familyId: record.familyId,
        actorUserId: user.id,
        eventType: 'CHORE_UPDATED',
        sourceType: AchievementEventSourceType.CHORE,
        sourceId: record.id,
        occurredAt: new Date(),
        familyTimezone: record.family.timezone,
        payload: {
          recordId: record.id,
          recordUserId: record.userId,
          recordOccurredAt: record.occurredAt.toISOString(),
          actualMinutes,
          points,
          pointsMultiplier,
        },
      });
      return { event };
    });

    const updated = await this.findRecordWithDetails(record.id, record.familyId);
    if (!updated) {
      throw new NotFoundException('Chore record not found');
    }
    const membership = await this.familiesService.assertActiveMember(record.familyId, user.id);
    return {
      ...this.formatRecord(updated, user.id, membership.memberRole),
      ...this.evaluationResponse(result.event),
    };
  }

  async restoreRecord(user: AuthUser, recordId: string) {
    const record = await this.prisma.choreRecord.findUnique({
      where: { id: recordId },
      select: {
        id: true,
        familyId: true,
        userId: true,
        occurredAt: true,
        deletedAt: true,
        deletedById: true,
        family: { select: { timezone: true } },
      },
    });

    if (!record?.deletedAt) {
      throw new NotFoundException('Deleted chore record not found');
    }

    await this.familiesService.assertActiveMember(record.familyId, user.id);

    if (record.deletedById !== user.id) {
      throw new ForbiddenException('Only the member who deleted this record can undo it');
    }

    const undoExpiresAt = new Date(record.deletedAt.getTime() + ACHIEVEMENT_UNDO_WINDOW_MS);
    if (undoExpiresAt.getTime() < Date.now()) {
      throw new ConflictException('The 10-second undo window has expired');
    }

    const restored = await this.prisma.$transaction(async (transaction) => {
      const update = await transaction.choreRecord.updateMany({
        where: {
          id: record.id,
          deletedAt: record.deletedAt,
          deletedById: user.id,
        },
        data: {
          deletedAt: null,
          deletedById: null,
        },
      });

      if (update.count !== 1) {
        throw new ConflictException('This chore record can no longer be restored');
      }
      const restoredAt = new Date();
      const event = await this.achievementOutbox.enqueueNextVersion(transaction, {
        familyId: record.familyId,
        actorUserId: user.id,
        eventType: 'CHORE_RESTORED',
        sourceType: AchievementEventSourceType.CHORE,
        sourceId: record.id,
        occurredAt: restoredAt,
        familyTimezone: record.family.timezone,
        payload: {
          recordId: record.id,
          recordUserId: record.userId,
          recordOccurredAt: record.occurredAt.toISOString(),
          restoredById: user.id,
        },
      });
      return { event };
    });

    return {
      recordId: record.id,
      restored: true,
      ...this.evaluationResponse(restored.event),
    };
  }

  async likeRecord(user: AuthUser, recordId: string, reactionKey: ChoreReactionKey = 'like') {
    const record = await this.findActiveRecord(recordId);
    await this.familiesService.assertActiveMember(record.familyId, user.id);

    const result = await this.prisma.$transaction(async (transaction) => {
      const existing = await transaction.choreRecordLike.findUnique({
        where: { recordId_userId: { recordId, userId: user.id } },
      });
      if (existing?.reactionKey === reactionKey) {
        return { event: null };
      }

      const reaction = existing
        ? await transaction.choreRecordLike.update({
            where: { id: existing.id },
            data: { reactionKey },
          })
        : await transaction.choreRecordLike.create({
            data: { recordId, userId: user.id, reactionKey },
          });
      const event = existing
        ? await this.achievementOutbox.enqueueNextVersion(transaction, {
            familyId: record.familyId,
            actorUserId: user.id,
            eventType: 'REACTION_CHANGED',
            sourceType: AchievementEventSourceType.REACTION,
            sourceId: reaction.id,
            occurredAt: new Date(),
            familyTimezone: record.family.timezone,
            payload: {
              reactionId: reaction.id,
              recordId,
              senderUserId: user.id,
              receiverUserId: record.userId,
              previousReactionKey: existing.reactionKey,
              reactionKey,
            },
          })
        : await this.achievementOutbox.enqueue(transaction, {
            familyId: record.familyId,
            actorUserId: user.id,
            eventType: 'REACTION_CREATED',
            sourceType: AchievementEventSourceType.REACTION,
            sourceId: reaction.id,
            sourceVersion: 1,
            occurredAt: reaction.createdAt,
            familyTimezone: record.family.timezone,
            payload: {
              reactionId: reaction.id,
              recordId,
              senderUserId: user.id,
              receiverUserId: record.userId,
              reactionKey,
            },
          });
      return { event };
    });

    return {
      ...(await this.likeState(recordId, user.id)),
      ...this.evaluationResponse(result.event),
    };
  }

  async unlikeRecord(user: AuthUser, recordId: string) {
    const record = await this.findActiveRecord(recordId);
    await this.familiesService.assertActiveMember(record.familyId, user.id);

    const result = await this.prisma.$transaction(async (transaction) => {
      const existing = await transaction.choreRecordLike.findUnique({
        where: { recordId_userId: { recordId, userId: user.id } },
      });
      if (!existing) {
        return { event: null };
      }

      await transaction.choreRecordLike.delete({ where: { id: existing.id } });
      const event = await this.achievementOutbox.enqueueNextVersion(transaction, {
        familyId: record.familyId,
        actorUserId: user.id,
        eventType: 'REACTION_DELETED',
        sourceType: AchievementEventSourceType.REACTION,
        sourceId: existing.id,
        occurredAt: new Date(),
        familyTimezone: record.family.timezone,
        payload: {
          reactionId: existing.id,
          recordId,
          senderUserId: user.id,
          receiverUserId: record.userId,
          previousReactionKey: existing.reactionKey,
        },
      });
      return { event };
    });

    return {
      ...(await this.likeState(recordId, user.id)),
      ...this.evaluationResponse(result.event),
    };
  }

  private async findActiveRecord(recordId: string) {
    const record = await this.prisma.choreRecord.findFirst({
      where: {
        id: recordId,
        deletedAt: null,
      },
      select: {
        id: true,
        familyId: true,
        userId: true,
        family: { select: { timezone: true } },
      },
    });

    if (!record) {
      throw new NotFoundException('Chore record not found');
    }

    return record;
  }

  private async likeState(recordId: string, userId: string) {
    const reactions = await this.prisma.choreRecordLike.findMany({
      where: { recordId },
      select: { userId: true, reactionKey: true },
    });
    const currentReaction = reactions.find((reaction) => reaction.userId === userId);

    return {
      recordId,
      likeCount: reactions.length,
      likedByMe: Boolean(currentReaction),
      myReaction: currentReaction?.reactionKey ?? null,
      reactionCounts: this.countReactions(reactions),
    };
  }

  private findRecordWithDetails(recordId: string, familyId: string) {
    return this.prisma.choreRecord.findUnique({
      where: { id: recordId },
      include: this.recordDetailsInclude(familyId),
    });
  }

  private recordDetailsInclude(familyId: string) {
    return {
      chore: true,
      user: {
        include: {
          memberships: {
            where: { familyId },
            take: 1,
          },
        },
      },
      likes: {
        include: {
          user: {
            include: {
              memberships: {
                where: { familyId },
                take: 1,
              },
            },
          },
        },
      },
      _count: {
        select: {
          likes: true,
        },
      },
    } satisfies Prisma.ChoreRecordInclude;
  }

  private currentMonthForTimeZone(timezone: string) {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
    }).formatToParts(new Date());
    const year = parts.find((part) => part.type === 'year')?.value;
    const month = parts.find((part) => part.type === 'month')?.value;
    return `${year}-${month}`;
  }

  private normalizeIdempotencyKey(rawKey?: string) {
    if (rawKey === undefined) {
      return null;
    }
    const key = rawKey.trim();
    if (!key || key.length > 128) {
      throw new BadRequestException('Idempotency-Key must contain 1 to 128 characters');
    }
    return key;
  }

  private async existingIdempotentRecord(
    existing: {
      id: string;
      familyId: string;
      choreId: string;
      actualMinutes: number;
      points: number;
      note: string | null;
      imageUrls: string[];
    },
    user: AuthUser,
    memberRole: MemberRole,
    dto: CreateChoreRecordDto,
    actualMinutes: number,
    points: number,
  ) {
    const sameRequest =
      existing.choreId === dto.choreId &&
      existing.actualMinutes === actualMinutes &&
      existing.points === points &&
      existing.note === (dto.note ?? null) &&
      JSON.stringify(existing.imageUrls) === JSON.stringify(dto.imageUrls ?? []);
    if (!sameRequest) {
      throw new ConflictException('Idempotency-Key was already used for a different request');
    }

    const [record, event] = await Promise.all([
      this.findRecordWithDetails(existing.id, existing.familyId),
      this.prisma.achievementEvent.findFirst({
        where: {
          eventType: 'CHORE_CREATED',
          sourceType: AchievementEventSourceType.CHORE,
          sourceId: existing.id,
          sourceVersion: 1,
        },
        select: { id: true },
      }),
    ]);
    if (!record) {
      throw new NotFoundException('Chore record not found');
    }

    return {
      ...this.formatRecord(record, user.id, memberRole),
      ...this.evaluationResponse(event),
    };
  }

  private evaluationResponse(event: { id: string } | null) {
    const evaluation = this.achievementOutbox.evaluation(event);
    return evaluation ? { achievementEvaluation: evaluation } : {};
  }

  private isUniqueConstraintError(error: unknown) {
    return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
  }

  private calculatePoints(defaultPoints: number, actualMinutes: number, standardMinutes: number) {
    if (standardMinutes <= 0) {
      return defaultPoints;
    }

    return Math.round((defaultPoints * actualMinutes) / standardMinutes);
  }

  private formatRecord(record: RecordWithDetails, currentUserId: string, currentMemberRole: MemberRole) {
    const creatorMembership = record.user.memberships[0];
    const createdBy = {
      id: record.user.id,
      displayName: record.creatorDisplayNameSnapshot,
      identityLabel: record.creatorIdentityLabelSnapshot,
      customIdentity: record.creatorCustomIdentitySnapshot,
      avatarKey: creatorMembership?.avatarKey ?? record.creatorAvatarKeySnapshot,
    };
    const likedBy = record.likes.map((like) => {
      const likerMembership = like.user.memberships[0];
      return {
        id: like.user.id,
        displayName: like.user.displayName,
        identityLabel: likerMembership?.identityLabel ?? '家庭成员',
        customIdentity: likerMembership?.customIdentity ?? null,
        avatarKey: likerMembership?.avatarKey ?? null,
        reactionKey: like.reactionKey,
      };
    });
    const currentReaction = record.likes.find((like) => like.userId === currentUserId);

    return {
      id: record.id,
      recordId: record.id,
      familyId: record.familyId,
      user: createdBy,
      createdBy,
      chore: {
        id: record.chore.id,
        name: record.chore.name,
        category: record.chore.category,
        icon: record.chore.icon,
        standardMinutes: record.chore.standardMinutes,
        defaultPoints: record.chore.defaultPoints,
        difficultyMultiplier: record.chore.difficultyMultiplier,
      },
      choreName: record.chore.name,
      minutes: record.minutes,
      actualMinutes: record.actualMinutes,
      points: record.points,
      pointsMultiplier: record.pointsMultiplier,
      note: record.note,
      imageUrls: record.imageUrls,
      likeCount: record._count.likes,
      likedBy,
      likedByMe: Boolean(currentReaction),
      myReaction: currentReaction?.reactionKey ?? null,
      reactionCounts: this.countReactions(record.likes),
      canDelete: record.userId === currentUserId || currentMemberRole === MemberRole.OWNER,
      canEdit: record.userId === currentUserId,
      occurredAt: record.occurredAt,
      createdAt: record.createdAt,
    };
  }

  private countReactions(reactions: Array<{ reactionKey: string }>) {
    const counts = Object.fromEntries(CHORE_REACTION_KEYS.map((key) => [key, 0])) as Record<
      ChoreReactionKey,
      number
    >;

    for (const reaction of reactions) {
      if (CHORE_REACTION_KEYS.includes(reaction.reactionKey as ChoreReactionKey)) {
        counts[reaction.reactionKey as ChoreReactionKey] += 1;
      }
    }

    return counts;
  }
}
