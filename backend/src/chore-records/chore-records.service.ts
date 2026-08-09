import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { MemberRole, MemberStatus, Prisma } from '@prisma/client';
import { AuthUser } from '../auth/auth-user';
import { getDayRangeForTimeZone, getMonthRangeForTimeZone, getWeekRangeForTimeZone } from '../common/timezone-ranges';
import { FamiliesService } from '../families/families.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateChoreRecordDto } from './dto/create-chore-record.dto';
import { CHORE_REACTION_KEYS, ChoreReactionKey } from './dto/react-to-chore-record.dto';

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
  ) {}

  async createRecord(user: AuthUser, dto: CreateChoreRecordDto) {
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

    if (dto.pointsMultiplier !== undefined) {
      const hasPremiumAccess = await this.familiesService.hasPremiumAccess(dto.familyId);
      if (!hasPremiumAccess) {
        throw new ForbiddenException('Custom points multiplier requires family premium access');
      }

      const multiplier = Math.round(dto.pointsMultiplier * 10) / 10;
      points = Math.max(1, Math.round(actualMinutes * multiplier));
    }

    const createdRecord = await this.prisma.choreRecord.create({
      data: {
        familyId: dto.familyId,
        userId: user.id,
        choreId: chore.id,
        note: dto.note,
        imageUrls: dto.imageUrls ?? [],
        minutes: chore.standardMinutes,
        actualMinutes,
        points,
        creatorDisplayNameSnapshot: user.displayName,
        creatorIdentityLabelSnapshot: membership.identityLabel,
        creatorCustomIdentitySnapshot: membership.customIdentity,
        creatorAvatarKeySnapshot: membership.avatarKey,
      },
      select: {
        id: true,
      },
    });

    const record = await this.findRecordWithDetails(createdRecord.id, dto.familyId);

    if (!record) {
      throw new NotFoundException('Chore record not found');
    }

    return this.formatRecord(record, user.id, membership.memberRole);
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
    const deletedRecord = await this.prisma.choreRecord.update({
      where: { id: record.id },
      data: {
        deletedAt,
        deletedById: user.id,
      },
      select: {
        id: true,
        deletedAt: true,
        deletedById: true,
      },
    });

    return {
      recordId: deletedRecord.id,
      ...deletedRecord,
    };
  }

  async likeRecord(user: AuthUser, recordId: string, reactionKey: ChoreReactionKey = 'like') {
    const record = await this.findActiveRecord(recordId);
    await this.familiesService.assertActiveMember(record.familyId, user.id);

    await this.prisma.choreRecordLike.upsert({
      where: {
        recordId_userId: {
          recordId,
          userId: user.id,
        },
      },
      update: { reactionKey },
      create: {
        recordId,
        userId: user.id,
        reactionKey,
      },
    });

    return this.likeState(recordId, user.id);
  }

  async unlikeRecord(user: AuthUser, recordId: string) {
    const record = await this.findActiveRecord(recordId);
    await this.familiesService.assertActiveMember(record.familyId, user.id);

    await this.prisma.choreRecordLike.deleteMany({
      where: {
        recordId,
        userId: user.id,
      },
    });

    return this.likeState(recordId, user.id);
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

  private calculatePoints(defaultPoints: number, actualMinutes: number, standardMinutes: number) {
    if (standardMinutes <= 0) {
      return defaultPoints;
    }

    return Math.round((defaultPoints * actualMinutes) / standardMinutes);
  }

  private formatRecord(record: RecordWithDetails, currentUserId: string, currentMemberRole: MemberRole) {
    const createdBy = {
      id: record.user.id,
      displayName: record.creatorDisplayNameSnapshot,
      identityLabel: record.creatorIdentityLabelSnapshot,
      customIdentity: record.creatorCustomIdentitySnapshot,
      avatarKey: record.creatorAvatarKeySnapshot,
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
      },
      choreName: record.chore.name,
      minutes: record.minutes,
      actualMinutes: record.actualMinutes,
      points: record.points,
      note: record.note,
      imageUrls: record.imageUrls,
      likeCount: record._count.likes,
      likedBy,
      likedByMe: Boolean(currentReaction),
      myReaction: currentReaction?.reactionKey ?? null,
      reactionCounts: this.countReactions(record.likes),
      canDelete: record.userId === currentUserId || currentMemberRole === MemberRole.OWNER,
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
