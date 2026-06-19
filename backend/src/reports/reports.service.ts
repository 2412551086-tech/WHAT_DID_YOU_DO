import { Injectable } from '@nestjs/common';
import { AuthUser } from '../auth/auth-user';
import { FamiliesService } from '../families/families.service';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ReportsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly familiesService: FamiliesService,
  ) {}

  async getMonthlyReport(user: AuthUser, familyId: string, month: string) {
    await this.familiesService.assertMember(familyId, user.id);

    const [start, end] = this.getMonthRange(month);
    const records = await this.prisma.choreRecord.findMany({
      where: {
        familyId,
        deletedAt: null,
        createdAt: {
          gte: start,
          lt: end,
        },
      },
      include: {
        chore: true,
        user: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    const byMember = new Map<string, { userId: string; displayName: string; points: number; recordCount: number }>();
    const byCategory = new Map<string, { category: string; points: number; recordCount: number }>();

    for (const record of records) {
      const member = byMember.get(record.userId) ?? {
        userId: record.userId,
        displayName: record.user.displayName,
        points: 0,
        recordCount: 0,
      };
      member.points += record.points;
      member.recordCount += 1;
      byMember.set(record.userId, member);

      const category = byCategory.get(record.chore.category) ?? {
        category: record.chore.category,
        points: 0,
        recordCount: 0,
      };
      category.points += record.points;
      category.recordCount += 1;
      byCategory.set(record.chore.category, category);
    }

    const totalPoints = records.reduce((sum, record) => sum + record.points, 0);

    return {
      familyId,
      month,
      totalPoints,
      totalRecords: records.length,
      headline: records.length > 0 ? '本月家务宇宙稳定运转' : '本月还没有家务记录，沙发暂时领先',
      leaderboard: Array.from(byMember.values()).sort((left, right) => right.points - left.points),
      categoryStats: Array.from(byCategory.values()).sort((left, right) => right.points - left.points),
      recentRecords: records.slice(0, 10).map((record) => ({
        id: record.id,
        memberName: record.user.displayName,
        choreName: record.chore.name,
        category: record.chore.category,
        points: record.points,
        minutes: record.minutes,
        actualMinutes: record.actualMinutes,
        createdAt: record.createdAt,
      })),
    };
  }

  private getMonthRange(month: string): [Date, Date] {
    const [yearText, monthText] = month.split('-');
    const year = Number(yearText);
    const monthIndex = Number(monthText) - 1;
    const start = new Date(year, monthIndex, 1);
    const end = new Date(year, monthIndex + 1, 1);

    return [start, end];
  }
}
