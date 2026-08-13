import { BadRequestException, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { AchievementEventSourceType, MemberRole, MemberStatus } from '@prisma/client';
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

  async anonymizeCurrentUser(user: AuthUser) {
    const anonymizedAt = new Date();
    const anonymousName = '匿名成员';
    await this.prisma.$transaction(async (transaction) => {
      const memberships = await transaction.familyMember.findMany({
        where: { userId: user.id, status: MemberStatus.ACTIVE },
        include: { family: { select: { timezone: true } } },
      });
      await transaction.choreRecord.updateMany({
        where: { userId: user.id },
        data: {
          creatorDisplayNameSnapshot: anonymousName,
          creatorIdentityLabelSnapshot: anonymousName,
          creatorCustomIdentitySnapshot: null,
          creatorAvatarKeySnapshot: null,
        },
      });
      await transaction.familyAchievementParticipant.updateMany({
        where: { userId: user.id },
        data: { displayRole: 'ANONYMIZED' },
      });
      await transaction.pairAchievement.updateMany({
        where: { OR: [{ memberAId: user.id }, { memberBId: user.id }] },
        data: { archiveStatus: 'HISTORICAL' },
      });
      for (const membership of memberships) {
        if (membership.memberRole === MemberRole.OWNER) {
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
            await transaction.family.update({
              where: { id: membership.familyId },
              data: { archivedAt: anonymizedAt },
            });
          }
        }
        await transaction.familyMember.update({
          where: { id: membership.id },
          data: { status: MemberStatus.LEFT, memberRole: MemberRole.MEMBER, leftAt: anonymizedAt },
        });
        await this.achievementOutbox.enqueueNextVersion(transaction, {
          familyId: membership.familyId,
          actorUserId: user.id,
          eventType: 'MEMBER_LEFT',
          sourceType: AchievementEventSourceType.MEMBERSHIP,
          sourceId: membership.id,
          occurredAt: anonymizedAt,
          familyTimezone: membership.family.timezone,
          payload: { membershipId: membership.id, userId: user.id, accountAnonymized: true },
        });
      }
      await transaction.user.update({
        where: { id: user.id },
        data: {
          phoneNumber: null,
          displayName: anonymousName,
          plan: 'free',
          premiumRedeemedAt: null,
          anonymizedAt,
        },
      });
      await transaction.achievementAuditLog.create({
        data: {
          actorUserId: user.id,
          actionType: 'ACCOUNT_ACHIEVEMENTS_ANONYMIZED',
          entityType: 'User',
          entityId: user.id,
          afterJson: { anonymizedAt, familyCount: memberships.length },
        },
      });
    });
    return { deleted: true, anonymizedAt };
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
