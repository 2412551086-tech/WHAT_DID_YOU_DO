import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from './auth-user';
import { MockLoginDto } from './dto/mock-login.dto';

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
