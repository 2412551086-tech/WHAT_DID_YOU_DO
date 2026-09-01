import { BadRequestException, Injectable } from '@nestjs/common';
import { AuthUser } from '../auth/auth-user';
import { getLocalDateKeyForTimeZone, getMonthRangeForTimeZone } from '../common/timezone-ranges';
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
    const timezone = await this.familiesService.getFamilyTimeZone(familyId);

    const { start, end } = this.getMonthRange(month, timezone);
    const previousMonth = this.previousMonth(month);
    const previousRange = this.getMonthRange(previousMonth, timezone);
    const trendMonths = Array.from({ length: 6 }, (_, index) => this.monthAtOffset(month, index - 5));
    const trendStart = this.getMonthRange(trendMonths[0], timezone).start;
    const [records, previousRecords, trendRecords] = await Promise.all([
      this.prisma.choreRecord.findMany({
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
      }),
      this.prisma.choreRecord.findMany({
        where: {
          familyId,
          deletedAt: null,
          createdAt: {
            gte: previousRange.start,
            lt: previousRange.end,
          },
        },
        select: {
          points: true,
          actualMinutes: true,
        },
      }),
      this.prisma.choreRecord.findMany({
        where: {
          familyId,
          deletedAt: null,
          createdAt: {
            gte: trendStart,
            lt: end,
          },
        },
        select: {
          createdAt: true,
          points: true,
          actualMinutes: true,
        },
      }),
    ]);

    const byMember = new Map<
      string,
      { userId: string; displayName: string; points: number; recordCount: number; totalMinutes: number }
    >();
    const byCategory = new Map<
      string,
      {
        category: string;
        points: number;
        recordCount: number;
        memberContributions: Map<
          string,
          { userId: string; displayName: string; points: number; recordCount: number; totalMinutes: number }
        >;
      }
    >();
    const byTheme = new Map<string, { themeKey: string; points: number; recordCount: number }>();

    for (const record of records) {
      const member = byMember.get(record.userId) ?? {
        userId: record.userId,
        displayName: record.user.displayName,
        points: 0,
        recordCount: 0,
        totalMinutes: 0,
      };
      member.points += record.points;
      member.recordCount += 1;
      member.totalMinutes += record.actualMinutes;
      byMember.set(record.userId, member);

      const category = byCategory.get(record.chore.category) ?? {
        category: record.chore.category,
        points: 0,
        recordCount: 0,
        memberContributions: new Map(),
      };
      category.points += record.points;
      category.recordCount += 1;
      const categoryMember = category.memberContributions.get(record.userId) ?? {
        userId: record.userId,
        displayName: record.user.displayName,
        points: 0,
        recordCount: 0,
        totalMinutes: 0,
      };
      categoryMember.points += record.points;
      categoryMember.recordCount += 1;
      categoryMember.totalMinutes += record.actualMinutes;
      category.memberContributions.set(record.userId, categoryMember);
      byCategory.set(record.chore.category, category);

      const theme = byTheme.get(record.chore.themeKey) ?? {
        themeKey: record.chore.themeKey,
        points: 0,
        recordCount: 0,
      };
      theme.points += record.points;
      theme.recordCount += 1;
      byTheme.set(record.chore.themeKey, theme);
    }

    const totalPoints = records.reduce((sum, record) => sum + record.points, 0);
    const totalMinutes = records.reduce((sum, record) => sum + record.actualMinutes, 0);
    const previousTotalPoints = previousRecords.reduce((sum, record) => sum + record.points, 0);
    const previousTotalMinutes = previousRecords.reduce((sum, record) => sum + record.actualMinutes, 0);
    const memberContributions = Array.from(byMember.values()).sort((left, right) => right.points - left.points);

    return {
      familyId,
      month,
      totalPoints,
      totalRecords: records.length,
      totalMinutes,
      headline: records.length > 0 ? '本月家务宇宙稳定运转' : '本月还没有家务记录，沙发暂时领先',
      comparison: {
        previousMonth,
        totalPoints: previousTotalPoints,
        totalRecords: previousRecords.length,
        totalMinutes: previousTotalMinutes,
      },
      monthlyTrend: this.buildMonthlyTrend(trendMonths, timezone, trendRecords),
      weeklyTrend: this.buildWeeklyTrend(month, timezone, records),
      memberContributions,
      leaderboard: memberContributions,
      themeStats: Array.from(byTheme.values()).sort((left, right) => right.points - left.points),
      categoryStats: Array.from(byCategory.values())
        .map((category) => ({
          category: category.category,
          points: category.points,
          recordCount: category.recordCount,
          memberContributions: Array.from(category.memberContributions.values()).sort(
            (left, right) => right.points - left.points,
          ),
        }))
        .sort((left, right) => right.points - left.points),
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

  private getMonthRange(month: string, timezone: string) {
    try {
      return getMonthRangeForTimeZone(month, timezone);
    } catch {
      throw new BadRequestException('Invalid month');
    }
  }

  private previousMonth(month: string): string {
    return this.monthAtOffset(month, -1);
  }

  private monthAtOffset(month: string, offset: number): string {
    const match = /^(\d{4})-(\d{2})$/.exec(month);
    if (!match) {
      throw new BadRequestException('Invalid month');
    }

    const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1 + offset, 1));
    return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
  }

  private buildMonthlyTrend(
    months: string[],
    timezone: string,
    records: Array<{ createdAt: Date; points: number; actualMinutes: number }>,
  ) {
    const buckets = new Map(
      months.map((month) => [
        month,
        { month, points: 0, recordCount: 0, totalMinutes: 0 },
      ]),
    );

    for (const record of records) {
      const monthKey = getLocalDateKeyForTimeZone(record.createdAt, timezone).slice(0, 7);
      const bucket = buckets.get(monthKey);
      if (!bucket) {
        continue;
      }
      bucket.points += record.points;
      bucket.recordCount += 1;
      bucket.totalMinutes += record.actualMinutes;
    }

    return months.map((month) => buckets.get(month));
  }

  private buildWeeklyTrend(
    month: string,
    timezone: string,
    records: Array<{ createdAt: Date; points: number; actualMinutes: number }>,
  ) {
    const [year, monthNumber] = month.split('-').map(Number);
    const daysInMonth = new Date(Date.UTC(year, monthNumber, 0)).getUTCDate();
    const buckets = new Map<
      string,
      { weekStart: string; weekEnd: string; label: string; points: number; recordCount: number; totalMinutes: number }
    >();

    for (let day = 1; day <= daysInMonth; day += 1) {
      const localDate = new Date(Date.UTC(year, monthNumber - 1, day));
      const key = this.weekStartKey(localDate);
      const existing = buckets.get(key);
      const dateKey = this.dateKey(localDate);

      if (existing) {
        existing.weekEnd = dateKey;
        existing.label = this.weekLabel(existing.weekStart, existing.weekEnd);
      } else {
        buckets.set(key, {
          weekStart: dateKey,
          weekEnd: dateKey,
          label: this.weekLabel(dateKey, dateKey),
          points: 0,
          recordCount: 0,
          totalMinutes: 0,
        });
      }
    }

    for (const record of records) {
      const localDateKey = getLocalDateKeyForTimeZone(record.createdAt, timezone);
      const localDate = new Date(`${localDateKey}T00:00:00.000Z`);
      const bucket = buckets.get(this.weekStartKey(localDate));
      if (!bucket) {
        continue;
      }
      bucket.points += record.points;
      bucket.recordCount += 1;
      bucket.totalMinutes += record.actualMinutes;
    }

    return Array.from(buckets.values());
  }

  private weekStartKey(date: Date): string {
    const mondayOffset = (date.getUTCDay() + 6) % 7;
    const monday = new Date(date);
    monday.setUTCDate(monday.getUTCDate() - mondayOffset);
    return this.dateKey(monday);
  }

  private dateKey(date: Date): string {
    return [date.getUTCFullYear(), date.getUTCMonth() + 1, date.getUTCDate()]
      .map((part, index) => (index === 0 ? String(part) : String(part).padStart(2, '0')))
      .join('-');
  }

  private weekLabel(start: string, end: string): string {
    const startDate = new Date(`${start}T00:00:00.000Z`);
    const endDate = new Date(`${end}T00:00:00.000Z`);
    return `${startDate.getUTCMonth() + 1}/${startDate.getUTCDate()}–${endDate.getUTCMonth() + 1}/${endDate.getUTCDate()}`;
  }
}
