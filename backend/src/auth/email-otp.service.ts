import {
  BadRequestException,
  HttpException,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { AuthProvider } from '@prisma/client';
import { createHmac, randomInt, randomUUID, timingSafeEqual } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { AuthIdentityService } from './auth-identity.service';
import { AuthSessionService } from './auth-session.service';
import { SendEmailCodeDto } from './dto/send-email-code.dto';
import { VerifyEmailCodeDto } from './dto/verify-email-code.dto';
import { EmailDeliveryService } from './email-delivery.service';

const OTP_TTL_MILLISECONDS = 10 * 60 * 1000;
const RESEND_COOLDOWN_MILLISECONDS = 60 * 1000;
const MAX_ATTEMPTS = 5;
const MAX_REQUESTS_PER_HOUR = 5;
const MAX_REQUESTS_PER_DAY = 10;

@Injectable()
export class EmailOtpService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly delivery: EmailDeliveryService,
    private readonly identities: AuthIdentityService,
    private readonly sessions: AuthSessionService,
  ) {
    this.assertProductionSecret();
  }

  async sendCode(dto: SendEmailCodeDto) {
    const email = this.normalizeEmail(dto.email);
    const now = new Date();
    const lastChallenge = await this.prisma.emailOtpChallenge.findFirst({
      where: { email },
      orderBy: { createdAt: 'desc' },
    });
    if (lastChallenge) {
      const retryAfter = RESEND_COOLDOWN_MILLISECONDS - (now.getTime() - lastChallenge.createdAt.getTime());
      if (retryAfter > 0) {
        throw new HttpException({
          message: '请稍后再发送验证码',
          retryAfterSeconds: Math.ceil(retryAfter / 1000),
        }, HttpStatus.TOO_MANY_REQUESTS);
      }
    }

    await this.assertRequestLimit(email, now, 60 * 60 * 1000, MAX_REQUESTS_PER_HOUR);
    await this.assertRequestLimit(email, now, 24 * 60 * 60 * 1000, MAX_REQUESTS_PER_DAY);

    const challengeId = randomUUID();
    const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
    const expiresAt = new Date(now.getTime() + OTP_TTL_MILLISECONDS);
    await this.prisma.emailOtpChallenge.create({
      data: {
        id: challengeId,
        email,
        codeDigest: this.digest(challengeId, email, code),
        expiresAt,
      },
    });

    try {
      await this.delivery.sendLoginCode(email, code, OTP_TTL_MILLISECONDS / 60_000);
    } catch (error) {
      await this.prisma.emailOtpChallenge.delete({ where: { id: challengeId } }).catch(() => undefined);
      throw error;
    }

    return {
      challengeId,
      maskedEmail: this.maskEmail(email),
      expiresInSeconds: OTP_TTL_MILLISECONDS / 1000,
      resendAfterSeconds: RESEND_COOLDOWN_MILLISECONDS / 1000,
      ...(this.delivery.exposesDevelopmentCode() ? { developmentCode: code } : {}),
    };
  }

  async verifyCode(dto: VerifyEmailCodeDto) {
    const email = this.normalizeEmail(dto.email);
    const challenge = await this.prisma.emailOtpChallenge.findUnique({
      where: { id: dto.challengeId },
    });
    const now = new Date();

    if (
      !challenge
      || challenge.email !== email
      || challenge.consumedAt
      || challenge.expiresAt <= now
      || challenge.attemptCount >= MAX_ATTEMPTS
    ) {
      throw new BadRequestException('验证码无效或已过期');
    }

    const actual = Buffer.from(this.digest(challenge.id, email, dto.code), 'hex');
    const expected = Buffer.from(challenge.codeDigest, 'hex');
    if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
      await this.prisma.emailOtpChallenge.updateMany({
        where: { id: challenge.id, consumedAt: null, attemptCount: { lt: MAX_ATTEMPTS } },
        data: { attemptCount: { increment: 1 } },
      });
      throw new BadRequestException('验证码无效或已过期');
    }

    const consumed = await this.prisma.emailOtpChallenge.updateMany({
      where: {
        id: challenge.id,
        consumedAt: null,
        expiresAt: { gt: now },
        attemptCount: { lt: MAX_ATTEMPTS },
      },
      data: { consumedAt: now },
    });
    if (consumed.count !== 1) {
      throw new BadRequestException('验证码无效或已过期');
    }

    const displayName = dto.displayName?.trim() || '新成员';
    const user = await this.identities.loginOrCreateIdentity({
      provider: AuthProvider.EMAIL,
      providerSubject: email,
      displayName,
      updateDisplayName: false,
      verifiedAt: now,
    });
    const tokens = await this.sessions.createSession(user.id, dto);
    return { user, ...tokens };
  }

  private async assertRequestLimit(email: string, now: Date, windowMilliseconds: number, limit: number) {
    const count = await this.prisma.emailOtpChallenge.count({
      where: {
        email,
        createdAt: { gte: new Date(now.getTime() - windowMilliseconds) },
      },
    });
    if (count >= limit) {
      throw new HttpException(
        '验证码请求过于频繁，请稍后重试',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  private normalizeEmail(rawEmail: string) {
    return rawEmail.trim().toLowerCase();
  }

  private digest(challengeId: string, email: string, code: string) {
    return createHmac('sha256', this.secret())
      .update(`${challengeId}:${email}:${code}`)
      .digest('hex');
  }

  private secret() {
    return process.env.EMAIL_OTP_SECRET || 'development-email-otp-secret-change-before-production';
  }

  private assertProductionSecret() {
    if (process.env.NODE_ENV !== 'production') return;
    const secret = process.env.EMAIL_OTP_SECRET;
    if (!secret || Buffer.byteLength(secret) < 32) {
      throw new Error('EMAIL_OTP_SECRET must contain at least 32 bytes in production');
    }
  }

  private maskEmail(email: string) {
    const [local, domain] = email.split('@');
    const visible = local.length <= 2 ? local.slice(0, 1) : local.slice(0, 2);
    return `${visible}***@${domain}`;
  }
}
