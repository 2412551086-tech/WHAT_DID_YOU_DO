import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { MemberRole, Prisma } from '@prisma/client';
import { AuthUser } from '../auth/auth-user';
import { FamiliesService } from '../families/families.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateChoreRecordDto } from './dto/create-chore-record.dto';

type RecordWithDetails = Prisma.ChoreRecordGetPayload<{
  include: {
    chore: true;
    user: {
      include: {
        memberships: true;
      };
    };
    likes: {
      select: {
        userId: true;
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

    const chore = await this.prisma.chore.findUnique({
      where: { id: dto.choreId },
    });

    if (!chore) {
      throw new NotFoundException('Chore not found');
    }

    const actualMinutes = dto.actualMinutes ?? chore.standardMinutes;
    const points = this.calculatePoints(chore.defaultPoints, actualMinutes, chore.standardMinutes);

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

  async getActivity(user: AuthUser, familyId: string) {
    const membership = await this.familiesService.assertActiveMember(familyId, user.id);

    const records = await this.prisma.choreRecord.findMany({
      where: {
        familyId,
        deletedAt: null,
      },
      include: this.recordDetailsInclude(familyId),
      orderBy: {
        createdAt: 'desc',
      },
      take: 30,
    });

    return records.map((record) => this.formatRecord(record, user.id, membership.memberRole));
  }

  async getLeaderboard(user: AuthUser, familyId: string, range: 'day' | 'month' = 'month') {
    await this.familiesService.assertActiveMember(familyId, user.id);

    const records = await this.prisma.choreRecord.findMany({
      where: {
        familyId,
        deletedAt: null,
        createdAt: {
          gte: this.getRangeStart(range),
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

  async likeRecord(user: AuthUser, recordId: string) {
    const record = await this.findActiveRecord(recordId);
    await this.familiesService.assertActiveMember(record.familyId, user.id);

    const existingLike = await this.prisma.choreRecordLike.findUnique({
      where: {
        recordId_userId: {
          recordId,
          userId: user.id,
        },
      },
    });

    if (existingLike) {
      throw new ConflictException('Chore record already liked');
    }

    await this.prisma.choreRecordLike.create({
      data: {
        recordId,
        userId: user.id,
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
    const [likeCount, likedByMe] = await Promise.all([
      this.prisma.choreRecordLike.count({ where: { recordId } }),
      this.prisma.choreRecordLike.findUnique({
        where: {
          recordId_userId: {
            recordId,
            userId,
          },
        },
        select: { id: true },
      }),
    ]);

    return {
      recordId,
      likeCount,
      likedByMe: Boolean(likedByMe),
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
        select: {
          userId: true,
        },
      },
      _count: {
        select: {
          likes: true,
        },
      },
    } satisfies Prisma.ChoreRecordInclude;
  }

  private getRangeStart(range: 'day' | 'month') {
    const now = new Date();

    if (range === 'day') {
      return new Date(now.getFullYear(), now.getMonth(), now.getDate());
    }

    return new Date(now.getFullYear(), now.getMonth(), 1);
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
      displayName: record.user.displayName,
      identityLabel: creatorMembership?.identityLabel ?? '家庭成员',
      customIdentity: creatorMembership?.customIdentity ?? null,
      avatarKey: creatorMembership?.avatarKey ?? null,
    };

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
      likedByMe: record.likes.some((like) => like.userId === currentUserId),
      canDelete: record.userId === currentUserId || currentMemberRole === MemberRole.OWNER,
      createdAt: record.createdAt,
    };
  }
}
