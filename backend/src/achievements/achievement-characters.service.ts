import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { AchievementTier, MemberStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export const ACHIEVEMENT_CHARACTERS = [
  { key: 'avatar_v2_recycler', achievementKey: 'MASTERY_TRASH' },
  { key: 'avatar_v2_chef', achievementKey: 'MASTERY_COOKING' },
  { key: 'avatar_v2_trainer', achievementKey: 'MASTERY_PET' },
  { key: 'avatar_v2_dad', achievementKey: 'MASTERY_CHILDCARE' },
] as const;

// Used by every membership-avatar write, including creation and local draft imports.
export async function assertAchievementAvatarOwned(db: Prisma.TransactionClient, userId: string, rawKey?: string | null) {
  const key = rawKey?.trim();
  if (!key?.startsWith('avatar_v2_')) return;
  if (!ACHIEVEMENT_CHARACTERS.some((character) => character.key === key)) throw new ForbiddenException('Unknown achievement character');
  const owned = await db.achievementCharacter.findUnique({ where: { userId_key: { userId, key } } });
  if (!owned) throw new ForbiddenException('Achievement character ownership required');
}

@Injectable()
export class AchievementCharactersService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string) {
    return this.prisma.$transaction(async (tx) => ({ characters: await this.items(tx, userId) }));
  }

  async claim(userId: string, key: string) {
    const character = ACHIEVEMENT_CHARACTERS.find((item) => item.key === key);
    if (!character) throw new NotFoundException('Achievement character not found');
    return this.prisma.$transaction(async (tx) => {
      const item = (await this.items(tx, userId)).find((item) => item.key === key)!;
      if (item.isOwned) return item;
      if (!item.canClaim) throw new ForbiddenException('Personal silver achievement and current premium required');
      const award = await tx.memberAchievement.findFirstOrThrow({
        where: { userId, achievementKey: character.achievementKey, tier: { in: [AchievementTier.SILVER, AchievementTier.GOLD] } },
        orderBy: { unlockedAt: 'asc' },
      });
      // ON CONFLICT DO NOTHING keeps concurrent claims successful without changing the first claim.
      await tx.achievementCharacter.createMany({
        data: [{ userId, key, sourceAchievementId: award.id }],
        skipDuplicates: true,
      });
      const owned = await tx.achievementCharacter.findUniqueOrThrow({ where: { userId_key: { userId, key } } });
      return { ...item, isOwned: true, canClaim: false, claimedAt: owned.claimedAt };
    });
  }

  private async items(tx: Prisma.TransactionClient, userId: string) {
    const [user, premiumMembership, awards, owned] = await Promise.all([
      tx.user.findUniqueOrThrow({ where: { id: userId }, select: { plan: true } }),
      tx.familyMember.findFirst({ where: {
        userId, status: MemberStatus.ACTIVE,
        family: { archivedAt: null, members: { some: { status: MemberStatus.ACTIVE, user: { plan: 'premium' } } } },
      }, select: { id: true } }),
      tx.memberAchievement.findMany({ where: {
        userId, achievementKey: { in: ACHIEVEMENT_CHARACTERS.map((item) => item.achievementKey) },
        tier: { in: [AchievementTier.SILVER, AchievementTier.GOLD] },
      }, select: { achievementKey: true } }),
      tx.achievementCharacter.findMany({ where: { userId } }),
    ]);
    const hasPremium = user.plan === 'premium' || premiumMembership !== null;
    return ACHIEVEMENT_CHARACTERS.map((character) => {
      const ownership = owned.find((item) => item.key === character.key);
      const achievementUnlocked = awards.some((award) => award.achievementKey === character.achievementKey);
      return { ...character, requiredTier: 'SILVER' as const, achievementUnlocked, hasPremium,
        isOwned: Boolean(ownership), canClaim: !ownership && achievementUnlocked && hasPremium,
        claimedAt: ownership?.claimedAt ?? null };
    });
  }
}
