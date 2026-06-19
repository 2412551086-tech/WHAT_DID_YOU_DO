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
import { PrismaService } from '../prisma/prisma.service';
import { CreateFamilyDto } from './dto/create-family.dto';
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
      myRole: 'owner',
      myMembership: ownerMembership ? this.formatMembership(ownerMembership) : null,
    };
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
    });

    if (existingMembership) {
      throw new ConflictException('Family membership or join request already exists');
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
      myRole: membership.memberRole.toLowerCase(),
      identityLabel: membership.identityLabel,
      customIdentity: membership.customIdentity,
      avatarKey: membership.avatarKey,
      memberRole: membership.memberRole,
      status: membership.status,
      myMembership: this.formatMembership(membership),
    }));
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

  private createInviteCode(): string {
    return randomBytes(4).toString('hex').toUpperCase();
  }
}
