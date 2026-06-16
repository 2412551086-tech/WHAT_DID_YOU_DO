import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AuthUser } from '../auth/auth-user';
import { FamiliesService } from '../families/families.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateChoreRecordDto } from './dto/create-chore-record.dto';

@Injectable()
export class ChoreRecordsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly familiesService: FamiliesService,
  ) {}

  async createRecord(user: AuthUser, dto: CreateChoreRecordDto) {
    await this.familiesService.assertMember(dto.familyId, user.id);

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

    const record = await this.prisma.choreRecord.create({
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
      include: {
        chore: true,
        user: true,
      },
    });

    return this.formatRecord(record);
  }

  async getActivity(user: AuthUser, familyId: string) {
    await this.familiesService.assertMember(familyId, user.id);

    const records = await this.prisma.choreRecord.findMany({
      where: { familyId },
      include: {
        chore: true,
        user: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 30,
    });

    return records.map((record) => this.formatRecord(record));
  }

  async getLeaderboard(user: AuthUser, familyId: string, range: 'day' | 'month' = 'month') {
    await this.familiesService.assertMember(familyId, user.id);

    const records = await this.prisma.choreRecord.findMany({
      where: {
        familyId,
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

  private formatRecord(record: {
    id: string;
    familyId: string;
    userId: string;
    note: string | null;
    imageUrls: string[];
    minutes: number;
    actualMinutes: number;
    points: number;
    createdAt: Date;
    chore: {
      id: string;
      name: string;
      category: string;
      icon: string;
    };
    user: {
      id: string;
      displayName: string;
    };
  }) {
    return {
      id: record.id,
      familyId: record.familyId,
      user: {
        id: record.user.id,
        displayName: record.user.displayName,
      },
      chore: {
        id: record.chore.id,
        name: record.chore.name,
        category: record.chore.category,
        icon: record.chore.icon,
      },
      minutes: record.minutes,
      actualMinutes: record.actualMinutes,
      points: record.points,
      note: record.note,
      imageUrls: record.imageUrls,
      createdAt: record.createdAt,
    };
  }
}
