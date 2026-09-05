import { Injectable } from '@nestjs/common';
import { AchievementRewardType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export const FREE_COMMON_CHORE_BASE_LIMIT = 6;
export const FREE_CUSTOM_CHORE_BASE_LIMIT = 2;
export const PREMIUM_CUSTOM_CHORE_PROTECTION_LIMIT = 100;

@Injectable()
export class AchievementRewardsService {
  constructor(private readonly prisma: PrismaService) {}

  async getFamilyCapacity(familyId: string, hasPremiumAccess: boolean) {
    const grants = await this.prisma.familyRewardGrant.groupBy({
      by: ['rewardType'],
      where: { familyId },
      _sum: { rewardValue: true },
    });
    const earned = new Map(
      grants.map((grant) => [grant.rewardType, grant._sum.rewardValue ?? 0]),
    );
    const commonEarned = earned.get(AchievementRewardType.COMMON_CHORE_SLOT) ?? 0;
    const customEarned = earned.get(AchievementRewardType.CUSTOM_CHORE_SLOT) ?? 0;

    return {
      common: {
        base: FREE_COMMON_CHORE_BASE_LIMIT,
        earned: commonEarned,
        limit: hasPremiumAccess ? null : FREE_COMMON_CHORE_BASE_LIMIT + commonEarned,
      },
      custom: {
        base: hasPremiumAccess
          ? PREMIUM_CUSTOM_CHORE_PROTECTION_LIMIT
          : FREE_CUSTOM_CHORE_BASE_LIMIT,
        earned: customEarned,
        limit: hasPremiumAccess
          ? PREMIUM_CUSTOM_CHORE_PROTECTION_LIMIT
          : FREE_CUSTOM_CHORE_BASE_LIMIT + customEarned,
      },
    };
  }
}
