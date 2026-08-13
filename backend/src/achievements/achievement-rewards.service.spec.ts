import { AchievementRewardType } from '@prisma/client';
import { AchievementRewardsService } from './achievement-rewards.service';

describe('AchievementRewardsService', () => {
  const groupBy = jest.fn();
  const service = new AchievementRewardsService({
    familyRewardGrant: { groupBy },
  } as never);

  beforeEach(() => groupBy.mockReset());

  it('adds permanent achievement grants to free family limits', async () => {
    groupBy.mockResolvedValue([
      { rewardType: AchievementRewardType.COMMON_CHORE_SLOT, _sum: { rewardValue: 2 } },
      { rewardType: AchievementRewardType.CUSTOM_CHORE_SLOT, _sum: { rewardValue: 1 } },
    ]);

    await expect(service.getFamilyCapacity('family-1', false)).resolves.toEqual({
      common: { base: 6, earned: 2, limit: 8 },
      custom: { base: 2, earned: 1, limit: 3 },
    });
  });

  it('keeps earned grants while premium uses its protection limits', async () => {
    groupBy.mockResolvedValue([
      { rewardType: AchievementRewardType.COMMON_CHORE_SLOT, _sum: { rewardValue: 2 } },
      { rewardType: AchievementRewardType.CUSTOM_CHORE_SLOT, _sum: { rewardValue: 1 } },
    ]);

    await expect(service.getFamilyCapacity('family-1', true)).resolves.toEqual({
      common: { base: 6, earned: 2, limit: null },
      custom: { base: 100, earned: 1, limit: 100 },
    });
  });
});
