import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { MemberRole, MemberStatus, Prisma } from '@prisma/client';
import { AuthUser } from '../auth/auth-user';
import { AchievementRewardsService } from '../achievements/achievement-rewards.service';
import { FamiliesService } from '../families/families.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCustomChoreDto } from './dto/create-custom-chore.dto';
import { UpdateChoreLayoutDto } from './dto/update-chore-layout.dto';
import { UpdateCustomChoreDto } from './dto/update-custom-chore.dto';

@Injectable()
export class ChoresService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly familiesService: FamiliesService,
    private readonly achievementRewards: AchievementRewardsService,
  ) {}

  async listChores() {
    const systemChores = await this.prisma.chore.findMany({
      where: {
        familyId: null,
        isCustom: false,
        isFreeCore: true,
        archivedAt: null,
      },
      orderBy: {
        sortOrder: 'asc',
      },
    });

    return systemChores.map((chore) => ({
      id: chore.id,
      catalogKey: chore.catalogKey,
      name: chore.name,
      themeKey: chore.themeKey,
      category: chore.category,
      minutes: chore.standardMinutes,
      points: chore.defaultPoints,
      difficultyMultiplier: chore.difficultyMultiplier,
      icon: chore.icon,
      isCoreFree: true,
      isCustom: false,
      requiredPlan: 'free',
      isLocked: false,
    }));
  }

  async listCustomChores(user: AuthUser, familyId: string) {
    await this.assertActiveMember(user.id, familyId);

    const chores = await this.prisma.chore.findMany({
      where: {
        familyId,
        isCustom: true,
        archivedAt: null,
      },
      orderBy: { customSlot: 'asc' },
    });

    return chores.map((chore) => this.formatCustomChore(chore));
  }

  async createCustomChore(user: AuthUser, familyId: string, dto: CreateCustomChoreDto) {
    await this.assertCanManageCustomChores(user.id, familyId);
    const name = dto.name.trim();

    const [existingChores, duplicate, customLimit] = await Promise.all([
      this.prisma.chore.findMany({
        where: { familyId, isCustom: true, archivedAt: null },
        select: { customSlot: true },
      }),
      this.prisma.chore.findFirst({
        where: { familyId, isCustom: true, archivedAt: null, name },
        select: { id: true },
      }),
      this.getCustomChoreLimit(familyId),
    ]);

    if (duplicate) {
      throw new ConflictException('Custom chore name already exists in this family');
    }

    const usedSlots = new Set(existingChores.map((chore) => chore.customSlot));
    const customSlot = Array.from({ length: customLimit }, (_, index) => index + 1)
      .find((slot) => !usedSlots.has(slot));
    if (!customSlot) {
      throw new ConflictException(`Current plan supports up to ${customLimit} custom chores per family`);
    }

    const multiplier = this.normalizeMultiplier(dto.difficultyMultiplier);
    let chore;
    try {
      chore = await this.prisma.chore.create({
        data: {
          familyId,
          createdById: user.id,
          name,
          themeKey: 'custom',
          category: dto.category,
          standardMinutes: dto.standardMinutes,
          difficultyMultiplier: multiplier,
          defaultPoints: this.calculateDefaultPoints(dto.standardMinutes, multiplier),
          icon: dto.iconKey,
          isFreeCore: false,
          isCustom: true,
          customSlot,
          sortOrder: customSlot,
        },
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('Custom chore slot changed; please refresh and try again');
      }
      throw error;
    }

    return this.formatCustomChore(chore);
  }

  async updateCustomChore(
    user: AuthUser,
    familyId: string,
    choreId: string,
    dto: UpdateCustomChoreDto,
  ) {
    await this.assertCanManageCustomChores(user.id, familyId);
    const existing = await this.findActiveCustomChore(familyId, choreId);
    const name = dto.name?.trim() ?? existing.name;

    const duplicate = await this.prisma.chore.findFirst({
      where: {
        familyId,
        isCustom: true,
        archivedAt: null,
        name,
        id: { not: choreId },
      },
      select: { id: true },
    });
    if (duplicate) {
      throw new ConflictException('Custom chore name already exists in this family');
    }

    const icon = dto.iconKey ?? existing.icon;

    const standardMinutes = dto.standardMinutes ?? existing.standardMinutes;
    const multiplier = this.normalizeMultiplier(
      dto.difficultyMultiplier ?? existing.difficultyMultiplier,
    );
    const updated = await this.prisma.chore.update({
      where: { id: choreId },
      data: {
        name,
        icon,
        category: dto.category ?? existing.category,
        standardMinutes,
        difficultyMultiplier: multiplier,
        defaultPoints: this.calculateDefaultPoints(standardMinutes, multiplier),
      },
    });

    return this.formatCustomChore(updated);
  }

  async archiveCustomChore(user: AuthUser, familyId: string, choreId: string) {
    await this.assertCanManageCustomChores(user.id, familyId);
    await this.findActiveCustomChore(familyId, choreId);

    const archived = await this.prisma.chore.update({
      where: { id: choreId },
      data: {
        archivedAt: new Date(),
        customSlot: null,
      },
    });

    return {
      id: archived.id,
      archivedAt: archived.archivedAt,
    };
  }

  async getChoreLayout(user: AuthUser, familyId: string) {
    const membership = await this.familiesService.assertActiveMember(familyId, user.id);
    const [family, hasPremiumAccess] = await Promise.all([
      this.prisma.family.findUnique({
        where: { id: familyId },
        select: { choreOrder: true, pinnedChoreIds: true, choreSetupCompleted: true },
      }),
      this.familiesService.hasPremiumAccess(familyId),
    ]);
    if (!family) {
      throw new NotFoundException('Family not found');
    }
    const capacity = await this.achievementRewards.getFamilyCapacity(familyId, hasPremiumAccess);

    const followsFamilyLayout = membership.memberRole === MemberRole.OWNER
      ? true
      : membership.followFamilyLayout;
    const usesPersonalLayout = hasPremiumAccess
      && membership.memberRole !== MemberRole.OWNER
      && !followsFamilyLayout
      && membership.choreSetupCompleted;
    const source = usesPersonalLayout ? membership : family;

    const availableIds = await this.getAvailableChoreIds(familyId);
    const availableSet = new Set(availableIds);
    const saved = source.choreOrder.filter((id) => availableSet.has(id));
    const pinnedSet = new Set(source.pinnedChoreIds);

    return {
      choreIds: source.choreSetupCompleted ? saved : [],
      pinnedChoreIds: source.choreSetupCompleted
        ? saved.filter((id) => pinnedSet.has(id))
        : [],
      isConfigured: source.choreSetupCompleted && saved.length > 0,
      scope: usesPersonalLayout ? 'member' : 'family',
      canEdit: hasPremiumAccess || membership.memberRole === MemberRole.OWNER,
      selectionLimit: capacity.common.limit,
      customChoreLimit: capacity.custom.limit,
      capacity,
      isPersonalized: usesPersonalLayout,
      followFamilyLayout: followsFamilyLayout,
    };
  }

  async updateChoreLayout(user: AuthUser, familyId: string, dto: UpdateChoreLayoutDto) {
    const membership = await this.familiesService.assertActiveMember(familyId, user.id);
    const hasPremiumAccess = await this.familiesService.hasPremiumAccess(familyId);
    const capacity = await this.achievementRewards.getFamilyCapacity(familyId, hasPremiumAccess);

    if (!hasPremiumAccess && membership.memberRole !== MemberRole.OWNER) {
      throw new ForbiddenException('Premium membership is required for a personal chore layout');
    }

    const availableIds = new Set(await this.getAvailableChoreIds(familyId));
    const selectionLimit = capacity.common.limit;

    if (selectionLimit && dto.choreIds.length > selectionLimit) {
      throw new BadRequestException(`Free plan supports up to ${selectionLimit} common chores`);
    }

    if (dto.choreIds.some((id) => !availableIds.has(id))) {
      throw new BadRequestException('Chore layout contains an unavailable chore');
    }

    const chosenIds = new Set(dto.choreIds);
    if (dto.pinnedChoreIds.some((id) => !chosenIds.has(id))) {
      throw new BadRequestException('Pinned chores must be part of the selected chores');
    }

    const followFamilyLayout = membership.memberRole === MemberRole.OWNER
      ? true
      : hasPremiumAccess
        ? (dto.followFamilyLayout ?? false)
        : true;

    if (hasPremiumAccess && membership.memberRole !== MemberRole.OWNER && followFamilyLayout) {
      await this.prisma.familyMember.update({
        where: { id: membership.id },
        data: { followFamilyLayout: true },
      });

      const family = await this.prisma.family.findUnique({
        where: { id: familyId },
        select: { choreOrder: true, pinnedChoreIds: true, choreSetupCompleted: true },
      });
      if (!family) {
        throw new NotFoundException('Family not found');
      }

      return {
        choreIds: family.choreSetupCompleted ? family.choreOrder : [],
        pinnedChoreIds: family.choreSetupCompleted ? family.pinnedChoreIds.filter((id) => family.choreOrder.includes(id)) : [],
        isConfigured: family.choreSetupCompleted && family.choreOrder.length > 0,
        scope: 'family',
        canEdit: true,
        selectionLimit,
        customChoreLimit: capacity.custom.limit,
        capacity,
        isPersonalized: false,
        followFamilyLayout: true,
      };
    }

    const layoutData = {
      choreOrder: dto.choreIds,
      pinnedChoreIds: dto.pinnedChoreIds,
      choreSetupCompleted: true,
      ...(hasPremiumAccess && membership.memberRole !== MemberRole.OWNER
        ? { followFamilyLayout: false }
        : {}),
    };

    const updated = hasPremiumAccess && membership.memberRole !== MemberRole.OWNER
      ? await this.prisma.familyMember.update({
          where: { id: membership.id },
          data: layoutData,
          select: { choreOrder: true, pinnedChoreIds: true, choreSetupCompleted: true },
        })
      : await this.prisma.family.update({
          where: { id: familyId },
          data: layoutData,
          select: { choreOrder: true, pinnedChoreIds: true, choreSetupCompleted: true },
        });

    if (hasPremiumAccess && membership.memberRole === MemberRole.OWNER) {
      await this.prisma.family.updateMany({
        where: { id: familyId, choreSetupCompleted: false },
        data: layoutData,
      });
    }

    return {
      choreIds: updated.choreOrder,
      pinnedChoreIds: updated.pinnedChoreIds,
      isConfigured: updated.choreSetupCompleted,
      scope: hasPremiumAccess ? 'member' : 'family',
      canEdit: true,
      selectionLimit,
      customChoreLimit: capacity.custom.limit,
      capacity,
      isPersonalized: hasPremiumAccess && membership.memberRole !== MemberRole.OWNER,
      followFamilyLayout: membership.memberRole === MemberRole.OWNER
        ? true
        : hasPremiumAccess
          ? false
          : true,
    };
  }

  private async assertActiveMember(userId: string, familyId: string) {
    const membership = await this.prisma.familyMember.findUnique({
      where: { userId_familyId: { userId, familyId } },
      select: { status: true },
    });

    if (!membership || membership.status !== MemberStatus.ACTIVE) {
      throw new ForbiddenException('Only active family members can manage custom chores');
    }
  }

  private async assertCanManageCustomChores(userId: string, familyId: string) {
    const [membership, hasPremiumAccess] = await Promise.all([
      this.familiesService.assertActiveMember(familyId, userId),
      this.familiesService.hasPremiumAccess(familyId),
    ]);

    if (!hasPremiumAccess && membership.memberRole !== MemberRole.OWNER) {
      throw new ForbiddenException(
        'Free plan custom chores can only be managed by the family owner',
      );
    }
  }

  private async findActiveCustomChore(familyId: string, choreId: string) {
    const chore = await this.prisma.chore.findFirst({
      where: { id: choreId, familyId, isCustom: true, archivedAt: null },
    });
    if (!chore) {
      throw new NotFoundException('Custom chore not found');
    }
    return chore;
  }

  private async getCustomChoreLimit(familyId: string) {
    const hasPremiumAccess = await this.familiesService.hasPremiumAccess(familyId);
    const capacity = await this.achievementRewards.getFamilyCapacity(familyId, hasPremiumAccess);
    return capacity.custom.limit;
  }

  private async getAvailableChoreIds(familyId: string) {
    const chores = await this.prisma.chore.findMany({
      where: {
        archivedAt: null,
        familyId: null,
        isCustom: false,
        isFreeCore: true,
      },
      orderBy: { sortOrder: 'asc' },
      select: { id: true },
    });
    return chores.map((chore) => chore.id);
  }

  private formatCustomChore(chore: {
    id: string;
    name: string;
    category: string;
    standardMinutes: number;
    difficultyMultiplier: number;
    defaultPoints: number;
    icon: string;
    customSlot: number | null;
  }) {
    return {
      id: chore.id,
      name: chore.name,
      themeKey: 'custom',
      category: chore.category,
      minutes: chore.standardMinutes,
      points: chore.defaultPoints,
      difficultyMultiplier: chore.difficultyMultiplier,
      icon: chore.icon,
      customSlot: chore.customSlot,
      suggestedFrequency: null,
      isCoreFree: false,
      isCustom: true,
      requiredPlan: 'free',
      isLocked: false,
    };
  }

  private normalizeMultiplier(value: number) {
    return Math.round(value * 10) / 10;
  }

  private calculateDefaultPoints(minutes: number, multiplier: number) {
    return Math.max(1, Math.round(minutes * multiplier));
  }
}
