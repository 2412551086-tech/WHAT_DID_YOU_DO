import { BadRequestException, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'node:crypto';
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
  constructor(private readonly prisma: PrismaService) {}

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
    const updatedUser = await this.prisma.user.update({
      where: { id: user.id },
      data: {
        plan: 'premium',
        premiumRedeemedAt: redeemedAt,
      },
    });

    return {
      plan: updatedUser.plan,
      premiumRedeemedAt: updatedUser.premiumRedeemedAt,
    };
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
