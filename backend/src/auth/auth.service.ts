import { BadRequestException, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import {
  AchievementEventSourceType,
  AchievementOwnerType,
  AchievementParticipantDisplayRole,
  MemberRole,
  MemberStatus,
  Prisma,
} from '@prisma/client';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { AchievementOutboxService } from '../achievements/achievement-outbox.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from './auth-user';
import { MockLoginDto } from './dto/mock-login.dto';
import { RedeemPremiumDto } from './dto/redeem-premium.dto';
import { UpdateCurrentUserDto } from './dto/update-current-user.dto';

interface TokenPayload {
  sub: string;
  displayName: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly achievementOutbox: AchievementOutboxService,
  ) {}

  async mockLogin(dto: MockLoginDto) {
    const phoneNumber = dto.phoneNumber?.trim();
    const requestedDisplayName = dto.displayName?.trim();

    if (!phoneNumber && !requestedDisplayName) {
      throw new BadRequestException('phoneNumber or displayName is required');
    }

    const displayName = requestedDisplayName || `用户${phoneNumber}`;
    const user = phoneNumber
      ? await this.prisma.user.upsert({
          where: { phoneNumber },
          update: requestedDisplayName ? { displayName } : {},
          create: { phoneNumber, displayName },
        })
      : await this.prisma.user.create({
          data: { displayName },
        });

    return {
      user,
      accessToken: this.signToken({
        sub: user.id,
        displayName: user.displayName,
      }),
    };
  }

  async verifyBearerToken(token: string): Promise<AuthUser> {
    const payload = this.verifyToken(token);
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
    });

    if (!user) {
      throw new UnauthorizedException('User not found');
    }
    if (user.anonymizedAt) {
      throw new UnauthorizedException('Account has been deleted');
    }

    return {
      id: user.id,
      displayName: user.displayName,
    };
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

  private signToken(payload: TokenPayload): string {
    const encodedPayload = Buffer.from(JSON.stringify(payload)).toString('base64url');
    const signature = this.sign(encodedPayload);

    return `${encodedPayload}.${signature}`;
  }

  private verifyToken(token: string): TokenPayload {
    const [encodedPayload, signature] = token.split('.');

    if (!encodedPayload || !signature) {
      throw new UnauthorizedException('Invalid token');
    }

    const expected = this.sign(encodedPayload);
    const signatureBuffer = Buffer.from(signature);
    const expectedBuffer = Buffer.from(expected);

    if (
      signatureBuffer.length !== expectedBuffer.length ||
      !timingSafeEqual(signatureBuffer, expectedBuffer)
    ) {
      throw new UnauthorizedException('Invalid token signature');
    }

    try {
      return JSON.parse(Buffer.from(encodedPayload, 'base64url').toString('utf8')) as TokenPayload;
    } catch {
      throw new UnauthorizedException('Invalid token payload');
    }
  }

  private sign(value: string): string {
    const secret = process.env.JWT_SECRET || 'dev-only-secret';

    return createHmac('sha256', secret).update(value).digest('base64url');
  }
}
