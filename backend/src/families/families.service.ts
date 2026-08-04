import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { MemberRole, MemberStatus } from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { AuthUser } from '../auth/auth-user';
import { DEFAULT_FAMILY_TIMEZONE, isValidTimeZone, normalizeTimeZone } from '../common/timezone-ranges';
import { PrismaService } from '../prisma/prisma.service';
import { CreateFamilyDto } from './dto/create-family.dto';
import { CreateJoinRequestByInviteCodeDto } from './dto/create-join-request-by-invite-code.dto';
import { CreateJoinRequestDto } from './dto/create-join-request.dto';
import { ReviewJoinRequestDto } from './dto/review-join-request.dto';

@Injectable()
export class FamiliesService {
  constructor(private readonly prisma: PrismaService) {}

  async createFamily(user: AuthUser, dto: CreateFamilyDto) {
    const identity = this.normalizeIdentityInput(dto.identityLabel, dto.customIdentity);
    const family = await this.prisma.family.create({
      data: {
        name: dto.name.trim(),
        requirePhotoProof: dto.requirePhotoProof ?? false,
        timezone: this.normalizeTimezoneInput(dto.timezone),
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

    return {
      ...family,
      members: family.members.map((membership) => this.formatMembership(membership)),
      hasPremiumAccess: family.members.some(
        (membership) => membership.status === MemberStatus.ACTIVE && membership.user.plan === 'premium',
      ),
      myRole: 'owner',
      myMembership: ownerMembership ? this.formatMembership(ownerMembership) : null,
    };
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
      select: { id: true },
    });

    if (!family) {
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

    if (existingMembership?.status === MemberStatus.REJECTED) {
      const resubmittedMembership = await this.prisma.familyMember.update({
        where: { id: existingMembership.id },
        data: {
          identityLabel: identity.identityLabel,
          customIdentity: identity.customIdentity,
          avatarKey: this.normalizeOptional(dto.avatarKey),
          status: MemberStatus.PENDING,
          approvedAt: null,
          approvedById: null,
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
      select: { id: true },
    });

    if (!family) {
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

    if (!family) {
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
      currentStatus: existingMembership?.status ?? null,
    };
  }

  async getMyJoinRequest(user: AuthUser) {
    const membership = await this.prisma.familyMember.findFirst({
      where: {
        userId: user.id,
        memberRole: MemberRole.MEMBER,
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
    const updatedMembership = await this.prisma.familyMember.update({
      where: { id: membership.id },
      data: {
        status: approved ? MemberStatus.ACTIVE : MemberStatus.REJECTED,
        approvedAt: approved ? new Date() : null,
        approvedById: user.id,
      },
      include: {
        user: true,
      },
    });

    return this.formatMembership(updatedMembership);
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

    await this.prisma.familyMember.delete({
      where: { id: membership.id },
    });

    return {
      familyId,
      left: true,
    };
  }

  async updateMyAppearance(user: AuthUser, familyId: string, avatarKey: string) {
    const membership = await this.assertActiveMember(familyId, user.id);

    const updatedMembership = await this.prisma.familyMember.update({
      where: { id: membership.id },
      data: { avatarKey },
      include: { user: true },
    });

    return this.formatMembership(updatedMembership);
  }

  async getMyFamilies(user: AuthUser) {
    const memberships = await this.prisma.familyMember.findMany({
      where: {
        userId: user.id,
        status: MemberStatus.ACTIVE,
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

  private createInviteCode(): string {
    return randomBytes(4).toString('hex').toUpperCase();
  }
}
