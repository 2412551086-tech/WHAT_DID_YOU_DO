import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AchievementEventSourceType, MemberRole, MemberStatus, Prisma } from '@prisma/client';
import { createHash, randomBytes } from 'node:crypto';
import { AchievementOutboxService } from '../achievements/achievement-outbox.service';
import { AuthUser } from '../auth/auth-user';
import { DEFAULT_FAMILY_TIMEZONE, isValidTimeZone, normalizeTimeZone } from '../common/timezone-ranges';
import { PrismaService } from '../prisma/prisma.service';
import { CreateFamilyDto } from './dto/create-family.dto';
import { ClaimLocalDraftDto } from './dto/claim-local-draft.dto';
import { CreateJoinRequestByInviteCodeDto } from './dto/create-join-request-by-invite-code.dto';
import { CreateJoinRequestDto } from './dto/create-join-request.dto';
import { ReviewJoinRequestDto } from './dto/review-join-request.dto';

@Injectable()
export class FamiliesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly achievementOutbox: AchievementOutboxService,
  ) {}

  async createFamily(user: AuthUser, dto: CreateFamilyDto) {
    const identity = this.normalizeIdentityInput(dto.identityLabel, dto.customIdentity);
    const timezone = this.normalizeTimezoneInput(dto.timezone);
    const created = await this.prisma.$transaction(async (transaction) => {
      const family = await transaction.family.create({
        data: {
          name: dto.name.trim(),
          requirePhotoProof: dto.requirePhotoProof ?? false,
          timezone,
          inviteCode: this.createInviteCode(),
          members: {
            create: {
              userId: user.id,
              identityLabel: identity.identityLabel,
              customIdentity: identity.customIdentity,
              avatarKey: this.normalizeOptional(dto.avatarKey),
              memberRole: MemberRole.OWNER,
              status: MemberStatus.ACTIVE,
              approvedAt: new Date(),
              approvedById: user.id,
            },
          },
        },
        include: {
          members: {
            include: {
              user: true,
            },
          },
        },
      });
      const ownerMembership = family.members[0];
      const event = ownerMembership
        ? await this.achievementOutbox.enqueue(transaction, {
            familyId: family.id,
            actorUserId: user.id,
            eventType: 'MEMBER_JOINED',
            sourceType: AchievementEventSourceType.MEMBERSHIP,
            sourceId: ownerMembership.id,
            sourceVersion: 1,
            occurredAt: ownerMembership.approvedAt ?? family.createdAt,
            familyTimezone: family.timezone,
            payload: {
              membershipId: ownerMembership.id,
              userId: user.id,
              memberRole: ownerMembership.memberRole,
              isFamilyCreator: true,
            },
          })
        : null;
      return { family, event };
    });
    const family = created.family;

    const ownerMembership = family.members[0];

    return {
      ...family,
      members: family.members.map((membership) => this.formatMembership(membership)),
      hasPremiumAccess: family.members.some(
        (membership) => membership.status === MemberStatus.ACTIVE && membership.user.plan === 'premium',
      ),
      myRole: 'owner',
      myMembership: ownerMembership ? this.formatMembership(ownerMembership) : null,
      ...(created.event
        ? { achievementEvaluation: this.achievementOutbox.evaluation(created.event) }
        : {}),
    };
  }

  async claimLocalDraft(user: AuthUser, dto: ClaimLocalDraftDto) {
    const payloadDigest = this.payloadDigest(dto);
    const existing = await this.prisma.localDraftClaim.findUnique({
      where: { draftId: dto.draftId },
    });
    if (existing) {
      if (existing.userId !== user.id || existing.payloadDigest !== payloadDigest) {
        throw new ConflictException('Local draft has already been claimed with different data');
      }
      return {
        familyId: existing.familyId,
        createdRecordCount: await this.prisma.choreRecord.count({
          where: { familyId: existing.familyId, userId: user.id },
        }),
        alreadyClaimed: true,
      };
    }

    if (dto.chores.length < 1 || dto.chores.length > 6) {
      throw new BadRequestException('Local draft must contain 1 to 6 chores');
    }
    const localIds = new Set(dto.chores.map((chore) => chore.localId));
    if (localIds.size !== dto.chores.length) {
      throw new BadRequestException('Local chore identifiers must be unique');
    }
    const customChores = dto.chores.filter((chore) => chore.source === 'CUSTOM');
    if (customChores.length > 2) {
      throw new BadRequestException('Free local drafts support up to 2 custom chores');
    }

    const catalogKeys = dto.chores
      .filter((chore) => chore.source === 'CATALOG')
      .map((chore) => chore.catalogKey)
      .filter((key): key is string => Boolean(key));
    if (catalogKeys.length !== dto.chores.length - customChores.length) {
      throw new BadRequestException('Catalog chores require stable catalog keys');
    }
    const catalogChores = await this.prisma.chore.findMany({
      where: {
        catalogKey: { in: catalogKeys },
        familyId: null,
        isCustom: false,
        archivedAt: null,
      },
    });
    if (catalogChores.length !== new Set(catalogKeys).size) {
      throw new BadRequestException('Local draft contains an unavailable catalog chore');
    }

    const draftCreatedAt = new Date(dto.draftCreatedAt);
    const claimStartedAt = new Date();
    for (const record of dto.records) {
      if (!localIds.has(record.choreLocalId)) {
        throw new BadRequestException('Local record references an unknown chore');
      }
      const occurredAt = new Date(record.occurredAt);
      if (
        occurredAt.getTime() < draftCreatedAt.getTime() - 5 * 60 * 1000
        || occurredAt.getTime() > claimStartedAt.getTime() + 5 * 60 * 1000
      ) {
        throw new BadRequestException('Local record time is outside the draft experience window');
      }
    }

    const identity = this.normalizeIdentityInput(dto.identityLabel, undefined);
    const timezone = this.normalizeTimezoneInput(dto.timezone);
    try {
      return await this.prisma.$transaction(async (transaction) => {
        const family = await transaction.family.create({
          data: {
            name: dto.familyName.trim(),
            requirePhotoProof: false,
            timezone,
            inviteCode: this.createInviteCode(),
          },
        });
        const membership = await transaction.familyMember.create({
          data: {
            userId: user.id,
            familyId: family.id,
            identityLabel: identity.identityLabel,
            customIdentity: identity.customIdentity,
            avatarKey: this.normalizeOptional(dto.avatarKey),
            memberRole: MemberRole.OWNER,
            status: MemberStatus.ACTIVE,
            approvedAt: claimStartedAt,
            approvedById: user.id,
            choreSetupCompleted: true,
            followFamilyLayout: true,
          },
        });
        await this.achievementOutbox.enqueue(transaction, {
          familyId: family.id,
          actorUserId: user.id,
          eventType: 'MEMBER_JOINED',
          sourceType: AchievementEventSourceType.MEMBERSHIP,
          sourceId: membership.id,
          sourceVersion: 1,
          occurredAt: claimStartedAt,
          familyTimezone: family.timezone,
          payload: {
            membershipId: membership.id,
            userId: user.id,
            memberRole: membership.memberRole,
            isFamilyCreator: true,
            claimedLocalDraft: true,
          },
        });

        const choreIdByLocalId = new Map<string, string>();
        for (const chore of dto.chores) {
          if (chore.source === 'CATALOG') {
            const catalog = catalogChores.find((item) => item.catalogKey === chore.catalogKey);
            if (!catalog) {
              throw new BadRequestException('Catalog chore is no longer available');
            }
            choreIdByLocalId.set(chore.localId, catalog.id);
            continue;
          }

          const customSlot = customChores.findIndex((item) => item.localId === chore.localId) + 1;
          const multiplier = Math.round(chore.difficultyMultiplier * 10) / 10;
          const created = await transaction.chore.create({
            data: {
              familyId: family.id,
              createdById: user.id,
              name: chore.name.trim(),
              themeKey: 'custom',
              category: chore.category,
              standardMinutes: chore.standardMinutes,
              difficultyMultiplier: multiplier,
              defaultPoints: Math.max(1, Math.round(chore.standardMinutes * multiplier)),
              icon: chore.icon,
              isFreeCore: false,
              isCustom: true,
              customSlot,
              sortOrder: customSlot,
            },
          });
          choreIdByLocalId.set(chore.localId, created.id);
        }

        const choreOrder = dto.chores.map((chore) => choreIdByLocalId.get(chore.localId)!);
        await transaction.family.update({
          where: { id: family.id },
          data: { choreOrder, choreSetupCompleted: true },
        });

        for (const record of dto.records) {
          const choreId = choreIdByLocalId.get(record.choreLocalId)!;
          const chore = dto.chores.find((item) => item.localId === record.choreLocalId)!;
          const catalog = catalogChores.find((item) => item.id === choreId);
          const standardMinutes = catalog?.standardMinutes ?? chore.standardMinutes;
          const defaultPoints = catalog?.defaultPoints
            ?? Math.max(1, Math.round(chore.standardMinutes * chore.difficultyMultiplier));
          const points = Math.max(
            1,
            Math.round(defaultPoints * record.actualMinutes / standardMinutes),
          );
          const occurredAt = new Date(record.occurredAt);
          const createdRecord = await transaction.choreRecord.create({
            data: {
              familyId: family.id,
              userId: user.id,
              choreId,
              note: record.note?.trim() || null,
              imageUrls: [],
              minutes: standardMinutes,
              actualMinutes: record.actualMinutes,
              points,
              pointsMultiplier: null,
              creatorDisplayNameSnapshot: user.displayName,
              creatorIdentityLabelSnapshot: membership.identityLabel,
              creatorCustomIdentitySnapshot: membership.customIdentity,
              creatorAvatarKeySnapshot: membership.avatarKey,
              clientRequestId: `draft:${dto.draftId}:${record.id}`,
              occurredAt,
              createdAt: occurredAt,
            },
          });
          await this.achievementOutbox.enqueue(transaction, {
            familyId: family.id,
            actorUserId: user.id,
            eventType: 'CHORE_CREATED',
            sourceType: AchievementEventSourceType.CHORE,
            sourceId: createdRecord.id,
            sourceVersion: 1,
            occurredAt,
            familyTimezone: family.timezone,
            payload: {
              recordId: createdRecord.id,
              choreId,
              userId: user.id,
              actualMinutes: record.actualMinutes,
              points,
              themeKey: catalog?.themeKey ?? 'custom',
              category: catalog?.category ?? chore.category,
              claimedLocalDraft: true,
            },
          });
        }

        await transaction.localDraftClaim.create({
          data: {
            draftId: dto.draftId,
            payloadDigest,
            userId: user.id,
            familyId: family.id,
          },
        });

        return {
          familyId: family.id,
          createdRecordCount: dto.records.length,
          alreadyClaimed: false,
        };
      });
    } catch (error) {
      if (!(error instanceof Prisma.PrismaClientKnownRequestError) || error.code !== 'P2002') {
        throw error;
      }
      const raced = await this.prisma.localDraftClaim.findUnique({
        where: { draftId: dto.draftId },
      });
      if (!raced || raced.userId !== user.id || raced.payloadDigest !== payloadDigest) {
        throw new ConflictException('Local draft claim conflicted with another request');
      }
      return {
        familyId: raced.familyId,
        createdRecordCount: dto.records.length,
        alreadyClaimed: true,
      };
    }
  }

  async updateFamilyName(user: AuthUser, familyId: string, rawName: string) {
    await this.assertOwner(familyId, user.id);
    const name = rawName.trim();

    if (!name) {
      throw new BadRequestException('Family name is required');
    }

    return this.prisma.family.update({
      where: { id: familyId },
      data: { name },
    });
  }

  async createJoinRequest(user: AuthUser, familyId: string, dto: CreateJoinRequestDto) {
    const identity = this.normalizeIdentityInput(dto.identityLabel, dto.customIdentity);
    const family = await this.prisma.family.findUnique({
      where: { id: familyId },
      select: { id: true, archivedAt: true },
    });

    if (!family || family.archivedAt) {
      throw new NotFoundException('Family not found');
    }

    const existingMembership = await this.prisma.familyMember.findUnique({
      where: {
        userId_familyId: {
          userId: user.id,
          familyId,
        },
      },
      include: {
        user: true,
      },
    });

    if (
      existingMembership?.status === MemberStatus.REJECTED ||
      existingMembership?.status === MemberStatus.LEFT
    ) {
      const resubmittedMembership = await this.prisma.familyMember.update({
        where: { id: existingMembership.id },
        data: {
          identityLabel: identity.identityLabel,
          customIdentity: identity.customIdentity,
          avatarKey: this.normalizeOptional(dto.avatarKey),
          memberRole: MemberRole.MEMBER,
          status: MemberStatus.PENDING,
          approvedAt: null,
          approvedById: null,
          leftAt: null,
          createdAt: new Date(),
        },
        include: {
          user: true,
        },
      });

      return this.formatMembership(resubmittedMembership);
    }

    if (existingMembership) {
      return this.formatMembership(existingMembership);
    }

    const membership = await this.prisma.familyMember.create({
      data: {
        userId: user.id,
        familyId,
        identityLabel: identity.identityLabel,
        customIdentity: identity.customIdentity,
        avatarKey: this.normalizeOptional(dto.avatarKey),
        memberRole: MemberRole.MEMBER,
        status: MemberStatus.PENDING,
      },
      include: {
        user: true,
      },
    });

    return this.formatMembership(membership);
  }

  async createJoinRequestByInviteCode(user: AuthUser, dto: CreateJoinRequestByInviteCodeDto) {
    const inviteCode = dto.inviteCode.trim().toUpperCase();
    const family = await this.prisma.family.findUnique({
      where: { inviteCode },
      select: { id: true, archivedAt: true },
    });

    if (!family || family.archivedAt) {
      throw new NotFoundException('Invite code not found');
    }

    return this.createJoinRequest(user, family.id, dto);
  }

  async getInvitePreview(user: AuthUser, rawInviteCode: string) {
    const inviteCode = rawInviteCode.trim().toUpperCase();
    const family = await this.prisma.family.findUnique({
      where: { inviteCode },
      include: {
        members: {
          where: { status: MemberStatus.ACTIVE },
          include: { user: true },
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    if (!family || family.archivedAt) {
      throw new NotFoundException('Invite code not found');
    }

    const existingMembership = await this.prisma.familyMember.findUnique({
      where: {
        userId_familyId: {
          userId: user.id,
          familyId: family.id,
        },
      },
    });

    return {
      ...this.formatFamilyPreview(family),
      currentStatus:
        existingMembership?.status === MemberStatus.LEFT
          ? null
          : (existingMembership?.status ?? null),
    };
  }

  async getPublicInvitePreview(rawInviteCode: string) {
    const inviteCode = rawInviteCode.trim().toUpperCase();
    const family = await this.prisma.family.findUnique({
      where: { inviteCode },
      include: {
        members: {
          where: { status: MemberStatus.ACTIVE },
          include: { user: true },
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    if (!family || family.archivedAt) {
      throw new NotFoundException('Invite code not found');
    }

    return this.formatFamilyPreview(family);
  }

  async getMyJoinRequest(user: AuthUser) {
    const membership = await this.prisma.familyMember.findFirst({
      where: {
        userId: user.id,
        memberRole: MemberRole.MEMBER,
        status: {
          in: [MemberStatus.PENDING, MemberStatus.ACTIVE, MemberStatus.REJECTED],
        },
      },
      include: {
        user: true,
        family: {
          include: {
            members: {
              where: { status: MemberStatus.ACTIVE },
              include: { user: true },
              orderBy: { createdAt: 'asc' },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!membership) {
      return null;
    }

    return {
      ...this.formatMembership(membership),
      family: this.formatFamilyPreview(membership.family),
    };
  }

  async getJoinRequests(user: AuthUser, familyId: string) {
    await this.assertOwner(familyId, user.id);

    const memberships = await this.prisma.familyMember.findMany({
      where: {
        familyId,
        status: MemberStatus.PENDING,
      },
      include: {
        user: true,
      },
      orderBy: {
        createdAt: 'asc',
      },
    });

    return memberships.map((membership) => this.formatMembership(membership));
  }

  async reviewJoinRequest(user: AuthUser, familyId: string, memberId: string, dto: ReviewJoinRequestDto) {
    await this.assertOwner(familyId, user.id);

    const membership = await this.prisma.familyMember.findFirst({
      where: {
        id: memberId,
        familyId,
      },
    });

    if (!membership) {
      throw new NotFoundException('Join request not found');
    }

    if (membership.status !== MemberStatus.PENDING) {
      throw new ConflictException('Join request has already been reviewed');
    }

    const approved = dto.action === 'approve';
    const reviewed = await this.prisma.$transaction(async (transaction) => {
      const updatedMembership = await transaction.familyMember.update({
        where: { id: membership.id },
        data: {
          status: approved ? MemberStatus.ACTIVE : MemberStatus.REJECTED,
          approvedAt: approved ? new Date() : null,
          approvedById: user.id,
        },
        include: {
          user: true,
          family: { select: { timezone: true } },
        },
      });
      const event = approved
        ? await this.achievementOutbox.enqueueNextVersion(transaction, {
            familyId,
            actorUserId: updatedMembership.userId,
            eventType: 'MEMBER_JOINED',
            sourceType: AchievementEventSourceType.MEMBERSHIP,
            sourceId: updatedMembership.id,
            occurredAt: updatedMembership.approvedAt ?? new Date(),
            familyTimezone: updatedMembership.family.timezone,
            payload: {
              membershipId: updatedMembership.id,
              userId: updatedMembership.userId,
              memberRole: updatedMembership.memberRole,
              approvedById: user.id,
              isFamilyCreator: false,
            },
          })
        : null;
      return { updatedMembership, event };
    });

    return {
      ...this.formatMembership(reviewed.updatedMembership),
      ...(reviewed.event
        ? { achievementEvaluation: this.achievementOutbox.evaluation(reviewed.event) }
        : {}),
    };
  }

  async transferOwnership(user: AuthUser, familyId: string, targetMemberId: string) {
    const ownerMembership = await this.assertOwner(familyId, user.id);

    const targetMembership = await this.prisma.familyMember.findFirst({
      where: {
        id: targetMemberId,
        familyId,
        status: MemberStatus.ACTIVE,
      },
      include: { user: true },
    });

    if (!targetMembership) {
      throw new NotFoundException('Active family member not found');
    }

    if (targetMembership.userId === user.id || targetMembership.memberRole === MemberRole.OWNER) {
      throw new BadRequestException('Select another active family member');
    }

    return this.prisma.$transaction(async (transaction) => {
      const currentOwner = await transaction.familyMember.findUnique({
        where: { id: ownerMembership.id },
      });

      if (currentOwner?.memberRole !== MemberRole.OWNER || currentOwner.status !== MemberStatus.ACTIVE) {
        throw new ForbiddenException('Family owner permission required');
      }

      await transaction.familyMember.updateMany({
        where: {
          familyId,
          status: MemberStatus.ACTIVE,
          memberRole: MemberRole.OWNER,
        },
        data: { memberRole: MemberRole.MEMBER },
      });

      const newOwner = await transaction.familyMember.update({
        where: { id: targetMembership.id },
        data: { memberRole: MemberRole.OWNER },
        include: { user: true },
      });
      const previousOwner = await transaction.familyMember.findUniqueOrThrow({
        where: { id: ownerMembership.id },
        include: { user: true },
      });

      return {
        familyId,
        previousOwner: this.formatMembership(previousOwner),
        newOwner: this.formatMembership(newOwner),
      };
    });
  }

  async leaveFamily(user: AuthUser, familyId: string) {
    const membership = await this.assertActiveMember(familyId, user.id);

    if (membership.memberRole === MemberRole.OWNER) {
      throw new BadRequestException('Transfer ownership before leaving family');
    }

    const leftAt = new Date();
    const left = await this.prisma.$transaction(async (transaction) => {
      await transaction.familyMember.update({
        where: { id: membership.id },
        data: {
          memberRole: MemberRole.MEMBER,
          status: MemberStatus.LEFT,
          leftAt,
        },
      });
      const family = await transaction.family.findUniqueOrThrow({
        where: { id: familyId },
        select: { timezone: true },
      });
      const event = await this.achievementOutbox.enqueueNextVersion(transaction, {
        familyId,
        actorUserId: user.id,
        eventType: 'MEMBER_LEFT',
        sourceType: AchievementEventSourceType.MEMBERSHIP,
        sourceId: membership.id,
        occurredAt: leftAt,
        familyTimezone: family.timezone,
        payload: {
          membershipId: membership.id,
          userId: user.id,
        },
      });
      return { event };
    });

    return {
      familyId,
      left: true,
      ...(left.event ? { achievementEvaluation: this.achievementOutbox.evaluation(left.event) } : {}),
    };
  }

  async dissolveFamily(user: AuthUser, familyId: string) {
    await this.assertOwner(familyId, user.id);
    const archivedAt = new Date();
    return this.prisma.$transaction(async (transaction) => {
      const family = await transaction.family.findUniqueOrThrow({
        where: { id: familyId },
        include: {
          members: { where: { status: MemberStatus.ACTIVE } },
          _count: { select: { memberAchievements: true, familyAchievements: true, pairAchievements: true } },
        },
      });
      for (const membership of family.members) {
        await transaction.familyMember.update({
          where: { id: membership.id },
          data: { status: MemberStatus.LEFT, leftAt: archivedAt, memberRole: MemberRole.MEMBER },
        });
        await this.achievementOutbox.enqueueNextVersion(transaction, {
          familyId,
          actorUserId: membership.userId,
          eventType: 'MEMBER_LEFT',
          sourceType: AchievementEventSourceType.MEMBERSHIP,
          sourceId: membership.id,
          occurredAt: archivedAt,
          familyTimezone: family.timezone,
          payload: { membershipId: membership.id, userId: membership.userId, familyDissolved: true },
        });
      }
      await transaction.family.update({ where: { id: familyId }, data: { archivedAt } });
      await transaction.achievementAuditLog.create({
        data: {
          familyId,
          actorUserId: user.id,
          actionType: 'FAMILY_ACHIEVEMENTS_ARCHIVED',
          entityType: 'Family',
          entityId: familyId,
          afterJson: { archivedAt, ...family._count },
        },
      });
      return {
        familyId,
        archivedAt,
        achievementArchive: family._count,
      };
    });
  }

  async updateMyAppearance(user: AuthUser, familyId: string, avatarKey: string) {
    const membership = await this.assertActiveMember(familyId, user.id);

    const updatedMembership = await this.prisma.$transaction(async (transaction) => {
      const updated = await transaction.familyMember.update({
        where: { id: membership.id },
        data: { avatarKey },
        include: { user: true },
      });

      await transaction.choreRecord.updateMany({
        where: {
          familyId,
          userId: user.id,
        },
        data: {
          creatorAvatarKeySnapshot: avatarKey,
        },
      });

      return updated;
    });

    return this.formatMembership(updatedMembership);
  }

  async getMyFamilies(user: AuthUser) {
    const memberships = await this.prisma.familyMember.findMany({
      where: {
        userId: user.id,
        status: MemberStatus.ACTIVE,
        family: { archivedAt: null },
      },
      include: {
        family: {
          include: {
            members: {
              where: {
                status: MemberStatus.ACTIVE,
              },
              include: {
                user: true,
              },
            },
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return memberships.map((membership) => ({
      ...membership.family,
      members: membership.family.members.map((member) => this.formatMembership(member)),
      hasPremiumAccess: membership.family.members.some(
        (member) => member.user.plan === 'premium',
      ),
      myRole: membership.memberRole.toLowerCase(),
      identityLabel: membership.identityLabel,
      customIdentity: membership.customIdentity,
      avatarKey: membership.avatarKey,
      memberRole: membership.memberRole,
      status: membership.status,
      myMembership: this.formatMembership(membership),
    }));
  }

  async hasPremiumAccess(familyId: string) {
    const premiumMember = await this.prisma.familyMember.findFirst({
      where: {
        familyId,
        status: MemberStatus.ACTIVE,
        user: {
          plan: 'premium',
        },
      },
      select: { id: true },
    });

    return premiumMember !== null;
  }

  async assertMember(familyId: string, userId: string) {
    return this.assertActiveMember(familyId, userId);
  }

  async assertActiveMember(familyId: string, userId: string) {
    const membership = await this.prisma.familyMember.findUnique({
      where: {
        userId_familyId: {
          userId,
          familyId,
        },
      },
    });

    if (!membership) {
      throw new NotFoundException('Family not found');
    }

    if (membership.status !== MemberStatus.ACTIVE) {
      throw new ForbiddenException('Active family membership required');
    }

    return membership;
  }

  async assertOwner(familyId: string, userId: string) {
    const membership = await this.assertActiveMember(familyId, userId);

    if (membership.memberRole !== MemberRole.OWNER) {
      throw new ForbiddenException('Family owner permission required');
    }

    return membership;
  }

  async getFamilyTimeZone(familyId: string) {
    const family = await this.prisma.family.findUnique({
      where: { id: familyId },
      select: { timezone: true },
    });

    if (!family) {
      throw new NotFoundException('Family not found');
    }

    return normalizeTimeZone(family.timezone);
  }

  private formatMembership(membership: {
    id: string;
    userId: string;
    familyId: string;
    identityLabel: string;
    customIdentity: string | null;
    avatarKey: string | null;
    memberRole: MemberRole;
    status: MemberStatus;
    approvedAt: Date | null;
    approvedById: string | null;
    leftAt: Date | null;
    createdAt: Date;
    user?: {
      id: string;
      displayName: string;
      createdAt: Date;
      updatedAt: Date;
    };
  }) {
    return {
      ...membership,
      role: membership.memberRole.toLowerCase(),
    };
  }

  private formatFamilyPreview(family: {
    id: string;
    name: string;
    inviteCode: string;
    members: Array<{
      identityLabel: string;
      customIdentity: string | null;
      avatarKey: string | null;
      memberRole: MemberRole;
      user: {
        id: string;
        displayName: string;
      };
    }>;
  }) {
    const owner = family.members.find((membership) => membership.memberRole === MemberRole.OWNER);

    return {
      id: family.id,
      name: family.name,
      inviteCode: family.inviteCode,
      memberCount: family.members.length,
      owner: owner
        ? {
            id: owner.user.id,
            displayName: owner.user.displayName,
            identityLabel: owner.identityLabel,
            customIdentity: owner.customIdentity,
            avatarKey: owner.avatarKey,
          }
        : null,
    };
  }

  private normalizeIdentityInput(identityLabel?: string, customIdentity?: string) {
    const normalizedIdentity = identityLabel?.trim() || '家庭成员';
    const normalizedCustomIdentity = this.normalizeOptional(customIdentity);

    if (normalizedIdentity === '自定义' && !normalizedCustomIdentity) {
      throw new BadRequestException('Custom identity is required');
    }

    return {
      identityLabel: normalizedIdentity,
      customIdentity: normalizedIdentity === '自定义' ? normalizedCustomIdentity : null,
    };
  }

  private normalizeOptional(value?: string): string | null {
    const normalized = value?.trim();
    return normalized ? normalized : null;
  }

  private normalizeTimezoneInput(timezone?: string) {
    const normalized = timezone?.trim() || DEFAULT_FAMILY_TIMEZONE;

    if (!isValidTimeZone(normalized)) {
      throw new BadRequestException('Invalid family timezone');
    }

    return normalized;
  }

  private payloadDigest(value: unknown) {
    const canonicalize = (input: unknown): unknown => {
      if (Array.isArray(input)) {
        return input.map(canonicalize);
      }
      if (input && typeof input === 'object') {
        return Object.fromEntries(
          Object.entries(input as Record<string, unknown>)
            .sort(([left], [right]) => left.localeCompare(right))
            .map(([key, nested]) => [key, canonicalize(nested)]),
        );
      }
      return input;
    };
    return createHash('sha256')
      .update(JSON.stringify(canonicalize(value)))
      .digest('hex');
  }

  private createInviteCode(): string {
    return randomBytes(4).toString('hex').toUpperCase();
  }
}
