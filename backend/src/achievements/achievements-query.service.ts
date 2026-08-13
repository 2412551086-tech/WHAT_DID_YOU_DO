import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import {
  AchievementOwnerType,
  AchievementVisibility,
  MemberStatus,
  Prisma,
} from '@prisma/client';
import { AuthUser } from '../auth/auth-user';
import { PrismaService } from '../prisma/prisma.service';
import { STAGE_THREE_JOURNEY_KEYS } from './achievement-journey.service';
import { isMasteryRuleEnabled, MASTERY_KEYS } from './achievement-mastery-taxonomy';
import { AchievementRewardsService } from './achievement-rewards.service';
import { STAGE_SIX_BOND_KEYS } from './achievement-bond.constants';
import {
  HIDDEN_ACHIEVEMENT_KEYS,
  STAGE_SEVEN_VISIBLE_KEYS,
} from './achievement-long-term.constants';

@Injectable()
export class AchievementsQueryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly rewardsService: AchievementRewardsService,
  ) {}

  async getSummary(user: AuthUser, familyId: string) {
    const membership = await this.assertActiveMember(familyId, user.id);
    const [items, capacity] = await Promise.all([
      this.getItems(user.id, familyId),
      this.getCapacity(familyId),
    ]);
    const unlocked = items.filter((item) => item.isUnlocked);

    return {
      familyId,
      userId: user.id,
      showAchievementsToFamily: membership.showAchievementsToFamily,
      unlockedCount: unlocked.length,
      totalCount: items.length,
      nextAchievement: items.find((item) => !item.isUnlocked) ?? null,
      recentUnlocks: unlocked
        .sort((left, right) =>
          String(right.unlockedAt ?? '').localeCompare(String(left.unlockedAt ?? '')),
        )
        .slice(0, 3),
      capacity,
    };
  }

  async getMine(user: AuthUser, familyId: string) {
    const membership = await this.assertActiveMember(familyId, user.id);
    const [achievements, capacity] = await Promise.all([
      this.getItems(user.id, familyId),
      this.getCapacity(familyId),
    ]);

    return {
      familyId,
      userId: user.id,
      showAchievementsToFamily: membership.showAchievementsToFamily,
      achievements,
      capacity,
      updatedAt: new Date(),
    };
  }

  async getDetail(user: AuthUser, familyId: string, definitionIdOrKey: string) {
    await this.assertActiveMember(familyId, user.id);
    const items = await this.getItems(user.id, familyId);
    const item = items.find(
      (achievement) =>
        achievement.definitionId === definitionIdOrKey || achievement.key === definitionIdOrKey,
    );
    if (!item) {
      throw new NotFoundException('Achievement not found');
    }
    return item;
  }

  async updateVisibility(
    user: AuthUser,
    familyId: string,
    memberAchievementId: string,
    visibility: AchievementVisibility,
  ) {
    await this.assertActiveMember(familyId, user.id);
    const achievement = await this.prisma.memberAchievement.findFirst({
      where: { id: memberAchievementId, familyId, userId: user.id },
    });
    if (!achievement) {
      throw new NotFoundException('Unlocked achievement not found');
    }

    return this.prisma.memberAchievement.update({
      where: { id: achievement.id },
      data: { visibility },
      select: {
        id: true,
        achievementKey: true,
        visibility: true,
        unlockedAt: true,
      },
    });
  }

  async updateSharingPreference(user: AuthUser, familyId: string, showToFamily: boolean) {
    const membership = await this.assertActiveMember(familyId, user.id);
    const visibility = showToFamily
      ? AchievementVisibility.FAMILY
      : AchievementVisibility.PRIVATE;

    await this.prisma.$transaction([
      this.prisma.familyMember.update({
        where: { id: membership.id },
        data: { showAchievementsToFamily: showToFamily },
      }),
      this.prisma.memberAchievement.updateMany({
        where: { familyId, userId: user.id },
        data: { visibility },
      }),
    ]);

    return { familyId, userId: user.id, showToFamily };
  }

  async getArchive(user: AuthUser) {
    const [personal, familyParticipation, pairs] = await Promise.all([
      this.prisma.memberAchievement.findMany({
        where: { userId: user.id },
        include: {
          definition: { select: { nameKey: true, descriptionKey: true, track: true } },
          family: { select: { id: true, name: true, archivedAt: true } },
        },
        orderBy: { unlockedAt: 'desc' },
      }),
      this.prisma.familyAchievementParticipant.findMany({
        where: { userId: user.id },
        include: {
          familyAchievement: {
            include: { family: { select: { id: true, name: true, archivedAt: true } } },
          },
        },
        orderBy: { familyAchievement: { unlockedAt: 'desc' } },
      }),
      this.prisma.pairAchievement.findMany({
        where: { OR: [{ memberAId: user.id }, { memberBId: user.id }] },
        include: {
          family: { select: { id: true, name: true, archivedAt: true } },
          memberA: { select: { id: true, displayName: true, anonymizedAt: true } },
          memberB: { select: { id: true, displayName: true, anonymizedAt: true } },
        },
        orderBy: { unlockedAt: 'desc' },
      }),
    ]);
    return {
      userId: user.id,
      personal: personal.map((item) => ({
        id: item.id,
        family: item.family,
        achievementKey: item.achievementKey,
        tier: item.tier,
        track: item.definition.track,
        unlockedAt: item.unlockedAt,
        visibility: item.visibility,
      })),
      familyHonors: familyParticipation.map((item) => ({
        id: item.familyAchievement.id,
        family: item.familyAchievement.family,
        achievementKey: item.familyAchievement.achievementKey,
        tier: item.familyAchievement.tier,
        unlockedAt: item.familyAchievement.unlockedAt,
        participantDisplayRole: item.displayRole,
      })),
      pairHonors: pairs.map((item) => ({
        id: item.id,
        family: item.family,
        achievementKey: item.achievementKey,
        tier: item.tier,
        unlockedAt: item.unlockedAt,
        archiveStatus: item.archiveStatus,
        members: [item.memberA, item.memberB].map((member) => ({
          id: member.id,
          displayName: member.anonymizedAt ? '匿名成员' : member.displayName,
        })),
      })),
      generatedAt: new Date(),
    };
  }

  private async getItems(userId: string, familyId: string) {
    const ownerKey = `${familyId}:${userId}`;
    const family = await this.prisma.family.findUnique({
      where: { id: familyId },
      select: {
        choreOrder: true,
        members: {
          where: { status: MemberStatus.ACTIVE },
          select: { userId: true },
        },
      },
    });
    if (!family) {
      throw new NotFoundException('Family not found');
    }
    const selectedChores = family.choreOrder.length > 0
      ? await this.prisma.chore.findMany({
          where: { id: { in: family.choreOrder }, archivedAt: null },
          select: { themeKey: true },
        })
      : [];
    const enabledThemes = new Set(['daily', ...selectedChores.map((chore) => chore.themeKey)]);
    const unlockedHidden = await this.prisma.memberAchievement.findMany({
      where: {
        familyId,
        userId,
        achievementKey: { in: [...HIDDEN_ACHIEVEMENT_KEYS] },
      },
      select: { achievementKey: true },
    });
    const visibleKeys = [
      ...STAGE_THREE_JOURNEY_KEYS,
      ...MASTERY_KEYS,
      ...STAGE_SEVEN_VISIBLE_KEYS,
      ...(family.members.length >= 2 ? STAGE_SIX_BOND_KEYS : []),
      ...unlockedHidden.map((unlock) => unlock.achievementKey),
    ];
    const definitions = (await this.prisma.achievementDefinition.findMany({
      where: { key: { in: visibleKeys }, isActive: true },
    }))
      .filter((definition) =>
        !MASTERY_KEYS.includes(definition.key as (typeof MASTERY_KEYS)[number])
        || isMasteryRuleEnabled(definition.ruleConfigJson, enabledThemes),
      )
      .sort((left, right) => this.definitionOrder(left.key, left.tier) - this.definitionOrder(right.key, right.tier));
    const definitionIds = definitions.map((definition) => definition.id);
    const [progressRecords, memberUnlocks, familyUnlocks, pairUnlocks] = await Promise.all([
      this.prisma.achievementProgress.findMany({
        where: { familyId, definitionId: { in: definitionIds } },
      }),
      this.prisma.memberAchievement.findMany({
        where: { familyId, userId, definitionId: { in: definitionIds } },
      }),
      this.prisma.familyAchievement.findMany({
        where: { familyId, definitionId: { in: definitionIds } },
        include: {
          participants: {
            where: { userId: { not: null } },
            include: { user: { select: { displayName: true } } },
          },
        },
      }),
      this.prisma.pairAchievement.findMany({
        where: {
          familyId,
          definitionId: { in: definitionIds },
          OR: [{ memberAId: userId }, { memberBId: userId }],
        },
        include: {
          memberA: { select: { displayName: true } },
          memberB: { select: { displayName: true } },
        },
      }),
    ]);
    const memberUnlockByDefinition = new Map(
      memberUnlocks.map((unlock) => [unlock.definitionId, unlock]),
    );
    const familyUnlockByDefinition = new Map(
      familyUnlocks.map((unlock) => [unlock.definitionId, unlock]),
    );
    const pairUnlockByDefinition = new Map(
      pairUnlocks.map((unlock) => [unlock.definitionId, unlock]),
    );
    return definitions.map((definition) => {
      const progress = this.progressForDefinition(
        progressRecords,
        definition.id,
        definition.ownerType,
        ownerKey,
        familyId,
        userId,
      );
      const memberUnlock = memberUnlockByDefinition.get(definition.id);
      const familyUnlock = familyUnlockByDefinition.get(definition.id);
      const pairUnlock = pairUnlockByDefinition.get(definition.id);
      const unlock = memberUnlock ?? familyUnlock ?? pairUnlock;
      const participantUserIds = familyUnlock
        ? familyUnlock.participants.flatMap((participant) => participant.userId ? [participant.userId] : [])
        : pairUnlock
          ? [pairUnlock.memberAId, pairUnlock.memberBId]
          : [];
      const participantNames = familyUnlock
        ? familyUnlock.participants.map((participant) => participant.user?.displayName).filter(Boolean)
        : pairUnlock
          ? [pairUnlock.memberA.displayName, pairUnlock.memberB.displayName]
          : [];
      const participantRoles = familyUnlock
        ? familyUnlock.participants.map((participant) => participant.displayRole)
        : [];
      return {
        definitionId: definition.id,
        key: definition.key,
        nameKey: definition.nameKey,
        descriptionKey: definition.descriptionKey,
        unlockCopyKey: definition.unlockCopyKey,
        track: definition.track,
        tier: definition.tier,
        targetValue: definition.targetValue,
        currentValue: progress?.displayCurrentValue ?? 0,
        rawCurrentValue: progress?.rawCurrentValue ?? 0,
        progressStatus: progress?.progressStatus ?? 'ACTIVE',
        isUnlocked: Boolean(unlock),
        ownerType: definition.ownerType,
        memberAchievementId: memberUnlock?.id ?? null,
        familyAchievementId: familyUnlock?.id ?? null,
        pairAchievementId: pairUnlock?.id ?? null,
        unlockedAt: unlock?.unlockedAt ?? null,
        visibility: memberUnlock?.visibility ?? definition.defaultVisibility,
        participantUserIds,
        participantNames,
        participantRoles,
        archiveStatus: pairUnlock?.archiveStatus ?? null,
        reward: this.formatReward(definition.rewardConfigJson),
      };
    });
  }

  private definitionOrder(key: string, tier: string) {
    const journeyIndex = STAGE_THREE_JOURNEY_KEYS.indexOf(key as (typeof STAGE_THREE_JOURNEY_KEYS)[number]);
    if (journeyIndex >= 0) {
      return journeyIndex;
    }
    const masteryIndex = MASTERY_KEYS.indexOf(key as (typeof MASTERY_KEYS)[number]);
    const tierIndex = ['BRONZE', 'SILVER', 'GOLD'].indexOf(tier);
    if (masteryIndex >= 0) {
      return STAGE_THREE_JOURNEY_KEYS.length + masteryIndex * 3 + Math.max(0, tierIndex);
    }
    const bondIndex = STAGE_SIX_BOND_KEYS.indexOf(key as (typeof STAGE_SIX_BOND_KEYS)[number]);
    if (bondIndex >= 0) {
      return STAGE_THREE_JOURNEY_KEYS.length + MASTERY_KEYS.length * 3 + bondIndex;
    }
    const longTermIndex = STAGE_SEVEN_VISIBLE_KEYS.indexOf(key as (typeof STAGE_SEVEN_VISIBLE_KEYS)[number]);
    if (longTermIndex >= 0) {
      return STAGE_THREE_JOURNEY_KEYS.length + MASTERY_KEYS.length * 3 + STAGE_SIX_BOND_KEYS.length + longTermIndex * 3 + Math.max(0, tierIndex);
    }
    const hiddenIndex = HIDDEN_ACHIEVEMENT_KEYS.indexOf(key as (typeof HIDDEN_ACHIEVEMENT_KEYS)[number]);
    return 10_000 + Math.max(0, hiddenIndex);
  }

  private progressForDefinition(
    progressRecords: Array<{
      definitionId: string;
      ownerType: AchievementOwnerType;
      ownerKey: string;
      displayCurrentValue: number;
      rawCurrentValue: number;
      progressStatus: string;
    }>,
    definitionId: string,
    ownerType: AchievementOwnerType,
    memberOwnerKey: string,
    familyId: string,
    userId: string,
  ) {
    const candidates = progressRecords.filter((progress) => {
      if (progress.definitionId !== definitionId || progress.ownerType !== ownerType) return false;
      if (ownerType === AchievementOwnerType.MEMBER) return progress.ownerKey === memberOwnerKey;
      if (ownerType === AchievementOwnerType.FAMILY) return progress.ownerKey === familyId;
      const pairMembers = progress.ownerKey.split(':').slice(1);
      return pairMembers.includes(userId);
    });
    return candidates.sort(
      (left, right) => right.displayCurrentValue - left.displayCurrentValue,
    )[0];
  }

  private async getCapacity(familyId: string) {
    const premiumMemberCount = await this.prisma.familyMember.count({
      where: {
        familyId,
        status: MemberStatus.ACTIVE,
        user: { plan: 'premium' },
      },
    });
    return this.rewardsService.getFamilyCapacity(familyId, premiumMemberCount > 0);
  }

  private async assertActiveMember(familyId: string, userId: string) {
    const membership = await this.prisma.familyMember.findUnique({
      where: { userId_familyId: { userId, familyId } },
      select: { id: true, status: true, showAchievementsToFamily: true },
    });
    if (membership?.status !== MemberStatus.ACTIVE) {
      throw new ForbiddenException('Active family membership required');
    }
    return membership;
  }

  private formatReward(value: Prisma.JsonValue) {
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      return null;
    }
    const object = value as Prisma.JsonObject;
    return typeof object.type === 'string' && typeof object.value === 'number'
      ? { type: object.type, value: object.value }
      : null;
  }
}
