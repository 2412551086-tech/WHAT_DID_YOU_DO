import { BadRequestException, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import {
  AchievementEventSourceType,
  AchievementOwnerType,
  AchievementParticipantDisplayRole,
  MemberRole,
  MemberStatus,
  Prisma,
} from '@prisma/client';
import { AchievementOutboxService } from '../achievements/achievement-outbox.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuthIdentityService } from './auth-identity.service';
import { AuthSessionService } from './auth-session.service';
import { AuthUser } from './auth-user';
import { MockLoginDto } from './dto/mock-login.dto';
import { RedeemPremiumDto } from './dto/redeem-premium.dto';
import { UpdateCurrentUserDto } from './dto/update-current-user.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly achievementOutbox: AchievementOutboxService,
    private readonly authIdentities: AuthIdentityService,
    private readonly authSessions: AuthSessionService,
  ) {}

  getPublicConfiguration() {
    const region = process.env.AUTH_DISTRIBUTION_REGION?.toUpperCase() === 'GLOBAL'
      ? 'GLOBAL'
      : 'CN';
    return {
      distributionRegion: region,
      providers: region === 'GLOBAL'
        ? ['APPLE', 'GOOGLE', 'EMAIL']
        : ['APPLE', 'WECHAT', 'EMAIL'],
    };
  }

  async mockLogin(dto: MockLoginDto) {
    if (process.env.NODE_ENV === 'production') {
      throw new ForbiddenException('Development login is disabled in production');
    }

    const devIdentifier = dto.devIdentifier?.trim();
    const requestedDisplayName = dto.displayName?.trim();

    if (!devIdentifier && !requestedDisplayName) {
      throw new BadRequestException('devIdentifier or displayName is required');
    }

    const displayName = requestedDisplayName || '开发用户';
    const user = devIdentifier
      ? await this.authIdentities.loginOrCreateIdentity({
          ...this.authIdentities.resolveDevelopmentIdentifier(devIdentifier),
          displayName,
          updateDisplayName: Boolean(requestedDisplayName),
        })
      : await this.prisma.user.create({
          data: { displayName },
        });

    const tokens = await this.authSessions.createSession(user.id, dto);
    return { user, ...tokens };
  }

  async verifyBearerToken(token: string): Promise<AuthUser> {
    return this.authSessions.verifyAccessToken(token);
  }

  refresh(refreshToken: string) {
    return this.authSessions.refresh(refreshToken);
  }

  logout(user: AuthUser) {
    return this.authSessions.revokeSession(user.sessionId, user.id);
  }

  logoutAll(user: AuthUser) {
    return this.authSessions.revokeAllSessions(user.id);
  }

  listSessions(user: AuthUser) {
    return this.authSessions.listSessions(user);
  }

  async getCurrentUser(user: AuthUser) {
    const currentUser = await this.prisma.user.findUnique({ where: { id: user.id } });

    if (!currentUser) {
      throw new UnauthorizedException('User not found');
    }

    return currentUser;
  }

  async updateCurrentUser(user: AuthUser, dto: UpdateCurrentUserDto) {
    const displayName = dto.displayName.trim();

    if (!displayName) {
      throw new BadRequestException('displayName is required');
    }

    return this.prisma.user.update({
      where: { id: user.id },
      data: { displayName },
    });
  }

  async redeemPremium(user: AuthUser, dto: RedeemPremiumDto) {
    if (process.env.NODE_ENV === 'production') {
      throw new ForbiddenException('Test premium redemption is disabled in production');
    }

    const expectedCode = process.env.TEST_PREMIUM_REDEMPTION_CODE || '241255';
    if (dto.code.trim() !== expectedCode) {
      throw new BadRequestException('Invalid premium redemption code');
    }

    const redeemedAt = new Date();
    const result = await this.prisma.$transaction(async (transaction) => {
      const previousUser = await transaction.user.findUniqueOrThrow({ where: { id: user.id } });
      const updatedUser = await transaction.user.update({
        where: { id: user.id },
        data: {
          plan: 'premium',
          premiumRedeemedAt: redeemedAt,
        },
      });
      const memberships = await transaction.familyMember.findMany({
        where: { userId: user.id, status: MemberStatus.ACTIVE },
        include: { family: { select: { id: true, timezone: true } } },
      });
      const events = [];
      if (previousUser.plan !== updatedUser.plan) {
        for (const membership of memberships) {
          const event = await this.achievementOutbox.enqueueNextVersion(transaction, {
            familyId: membership.familyId,
            actorUserId: user.id,
            eventType: 'PLAN_CHANGED',
            sourceType: AchievementEventSourceType.PLAN,
            sourceId: membership.familyId,
            occurredAt: redeemedAt,
            familyTimezone: membership.family.timezone,
            payload: {
              userId: user.id,
              previousPlan: previousUser.plan,
              plan: updatedUser.plan,
            },
          });
          if (event) {
            events.push(event);
          }
        }
      }
      return { updatedUser, events };
    });

    return {
      plan: result.updatedUser.plan,
      premiumRedeemedAt: result.updatedUser.premiumRedeemedAt,
      ...(result.events.length
        ? {
            achievementEvaluations: result.events.map((event) =>
              this.achievementOutbox.evaluation(event),
            ),
          }
        : {}),
    };
  }

  async deleteCurrentUser(user: AuthUser) {
    const deletedAt = new Date();
    await this.prisma.$transaction(async (transaction) => {
      const memberships = await transaction.familyMember.findMany({
        where: { userId: user.id },
      });

      const familyIdsToDelete: string[] = [];
      for (const membership of memberships) {
        if (membership.status !== MemberStatus.ACTIVE || membership.memberRole !== MemberRole.OWNER) {
          continue;
        }

        const successor = await transaction.familyMember.findFirst({
          where: {
            familyId: membership.familyId,
            userId: { not: user.id },
            status: MemberStatus.ACTIVE,
          },
          orderBy: [{ approvedAt: 'asc' }, { createdAt: 'asc' }],
        });

        if (successor) {
          await transaction.familyMember.update({
            where: { id: successor.id },
            data: { memberRole: MemberRole.OWNER },
          });
        } else {
          familyIdsToDelete.push(membership.familyId);
        }
      }

      const retainedFamilyIds = memberships
        .map((membership) => membership.familyId)
        .filter((familyId) => !familyIdsToDelete.includes(familyId));

      await transaction.chore.updateMany({
        where: { createdById: user.id, isCustom: true },
        data: {
          createdById: null,
          name: '已删除的自定义家务',
          icon: 'chore_custom_generic_01',
          archivedAt: deletedAt,
        },
      });

      await transaction.familyAchievementParticipant.updateMany({
        where: { userId: user.id },
        data: {
          userId: null,
          displayRole: AchievementParticipantDisplayRole.ANONYMIZED,
          contributionSummaryJson: Prisma.JsonNull,
        },
      });

      await transaction.achievementEvent.updateMany({
        where: { actorUserId: user.id },
        data: {
          actorUserId: null,
          payloadJson: { accountDeleted: true },
        },
      });

      if (retainedFamilyIds.length > 0) {
        const eligibilitySnapshots = await transaction.achievementEligibilitySnapshot.findMany({
          where: { familyId: { in: retainedFamilyIds } },
          select: { id: true, eligibleMemberIdsJson: true },
        });
        for (const snapshot of eligibilitySnapshots) {
          const eligibleMemberIds = Array.isArray(snapshot.eligibleMemberIdsJson)
            ? snapshot.eligibleMemberIdsJson.filter(
                (memberId): memberId is string => typeof memberId === 'string' && memberId !== user.id,
              )
            : [];
          await transaction.achievementEligibilitySnapshot.update({
            where: { id: snapshot.id },
            data: { eligibleMemberIdsJson: eligibleMemberIds },
          });
        }
      }

      await transaction.achievementProgress.deleteMany({
        where: {
          OR: [
            { ownerType: AchievementOwnerType.MEMBER, ownerKey: { endsWith: `:${user.id}` } },
            { ownerType: AchievementOwnerType.PAIR, ownerKey: { contains: user.id } },
          ],
        },
      });
      await transaction.achievementAuditLog.deleteMany({ where: { actorUserId: user.id } });

      await transaction.user.delete({
        where: { id: user.id },
      });

      for (const familyId of familyIdsToDelete) {
        await this.deleteFamilyPermanently(transaction, familyId);
      }
    });
    return { deleted: true, deletedAt };
  }

  private async deleteFamilyPermanently(
    transaction: Prisma.TransactionClient,
    familyId: string,
  ) {
    await transaction.familyAchievementParticipant.deleteMany({
      where: { familyAchievement: { familyId } },
    });
    await transaction.memberAchievement.deleteMany({ where: { familyId } });
    await transaction.familyAchievement.deleteMany({ where: { familyId } });
    await transaction.pairAchievement.deleteMany({ where: { familyId } });
    await transaction.familyRewardGrant.deleteMany({ where: { familyId } });
    await transaction.achievementProgress.deleteMany({ where: { familyId } });
    await transaction.achievementUnlockBatch.deleteMany({ where: { familyId } });
    await transaction.achievementEvent.deleteMany({ where: { familyId } });
    await transaction.achievementEligibilitySnapshot.deleteMany({ where: { familyId } });
    await transaction.achievementAuditLog.deleteMany({ where: { familyId } });
    await transaction.choreRecord.deleteMany({ where: { familyId } });
    await transaction.familyMember.deleteMany({ where: { familyId } });
    await transaction.chore.deleteMany({ where: { familyId } });
    await transaction.family.delete({ where: { id: familyId } });
  }

}
