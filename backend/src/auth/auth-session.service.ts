import { Injectable, UnauthorizedException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { createHash, createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from './auth-user';
import { SessionDeviceDto } from './dto/session-device.dto';

const ACCESS_TOKEN_SECONDS = 15 * 60;
const REFRESH_IDLE_MILLISECONDS = 30 * 24 * 60 * 60 * 1000;
const SESSION_ABSOLUTE_MILLISECONDS = 90 * 24 * 60 * 60 * 1000;
const TOKEN_ISSUER = 'family-guard-api';
const TOKEN_AUDIENCE = 'family-guard-ios';

interface AccessTokenPayload {
  aud: string;
  exp: number;
  iat: number;
  iss: string;
  jti: string;
  sid: string;
  sub: string;
  typ: 'access';
}

export interface AuthTokenPair {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresAt: Date;
  refreshTokenExpiresAt: Date;
}

type RefreshOutcome = { error: string } | { tokens: AuthTokenPair };

@Injectable()
export class AuthSessionService {
  constructor(private readonly prisma: PrismaService) {
    this.assertProductionSecret();
  }

  async createSession(userId: string, device: SessionDeviceDto = {}): Promise<AuthTokenPair> {
    const now = new Date();
    const absoluteExpiresAt = new Date(now.getTime() + SESSION_ABSOLUTE_MILLISECONDS);
    const refreshTokenExpiresAt = this.refreshExpiry(now, absoluteExpiresAt);
    const refreshToken = this.generateRefreshToken();

    const session = await this.prisma.authSession.create({
      data: {
        userId,
        deviceId: this.clean(device.deviceId),
        deviceName: this.clean(device.deviceName),
        platform: this.clean(device.platform),
        appVersion: this.clean(device.appVersion),
        lastUsedAt: now,
        idleExpiresAt: refreshTokenExpiresAt,
        absoluteExpiresAt,
        refreshTokens: {
          create: {
            tokenHash: this.hashRefreshToken(refreshToken),
            expiresAt: refreshTokenExpiresAt,
          },
        },
      },
    });

    return this.tokenPair(userId, session.id, refreshToken, now, refreshTokenExpiresAt);
  }

  async refresh(rawRefreshToken: string): Promise<AuthTokenPair> {
    const tokenHash = this.hashRefreshToken(rawRefreshToken);
    const replacementToken = this.generateRefreshToken();
    const replacementHash = this.hashRefreshToken(replacementToken);
    const now = new Date();

    let outcome: RefreshOutcome | undefined;
    for (let attempt = 0; attempt < 2; attempt += 1) {
      try {
        outcome = await this.prisma.$transaction(
          async (transaction): Promise<RefreshOutcome> => {
            const storedToken = await transaction.authRefreshToken.findUnique({
              where: { tokenHash },
              include: { session: true },
            });

            if (!storedToken) {
              return { error: 'Invalid refresh token' };
            }

            const session = storedToken.session;
            if (session.revokedAt) {
              return { error: 'Session has been revoked' };
            }

            if (storedToken.usedAt) {
              await this.revokeSessionTransaction(
                transaction,
                session.id,
                now,
                'refresh_token_reuse',
              );
              return { error: 'Refresh token reuse detected' };
            }

            if (
              storedToken.expiresAt <= now
              || session.idleExpiresAt <= now
              || session.absoluteExpiresAt <= now
            ) {
              await this.revokeSessionTransaction(transaction, session.id, now, 'expired');
              return { error: 'Refresh token has expired' };
            }

            const consumed = await transaction.authRefreshToken.updateMany({
              where: { id: storedToken.id, usedAt: null },
              data: { usedAt: now },
            });
            if (consumed.count !== 1) {
              await this.revokeSessionTransaction(
                transaction,
                session.id,
                now,
                'refresh_token_reuse',
              );
              return { error: 'Refresh token reuse detected' };
            }

            const refreshTokenExpiresAt = this.refreshExpiry(now, session.absoluteExpiresAt);
            await transaction.authRefreshToken.create({
              data: {
                sessionId: session.id,
                tokenHash: replacementHash,
                expiresAt: refreshTokenExpiresAt,
              },
            });
            await transaction.authSession.update({
              where: { id: session.id },
              data: {
                lastUsedAt: now,
                idleExpiresAt: refreshTokenExpiresAt,
              },
            });

            return {
              tokens: this.tokenPair(
                session.userId,
                session.id,
                replacementToken,
                now,
                refreshTokenExpiresAt,
              ),
            };
          },
          { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
        );
        break;
      } catch (error) {
        const shouldRetry = error instanceof Prisma.PrismaClientKnownRequestError
          && error.code === 'P2034'
          && attempt === 0;
        if (!shouldRetry) throw error;
      }
    }

    if (!outcome || 'error' in outcome) {
      const message = outcome && 'error' in outcome ? outcome.error : 'Refresh failed';
      throw new UnauthorizedException(message);
    }
    return outcome.tokens;
  }

  async verifyAccessToken(token: string): Promise<AuthUser> {
    const payload = this.verifyJwt(token);
    const now = new Date();
    const session = await this.prisma.authSession.findUnique({
      where: { id: payload.sid },
      include: { user: true },
    });

    if (
      !session
      || session.userId !== payload.sub
      || session.revokedAt
      || session.absoluteExpiresAt <= now
      || session.user.anonymizedAt
    ) {
      throw new UnauthorizedException('Session is no longer valid');
    }

    return {
      id: session.user.id,
      displayName: session.user.displayName,
      sessionId: session.id,
    };
  }

  async revokeSession(sessionId: string, userId: string, reason = 'logout') {
    const result = await this.prisma.authSession.updateMany({
      where: { id: sessionId, userId, revokedAt: null },
      data: { revokedAt: new Date(), revokedReason: reason },
    });
    return { revoked: result.count === 1 };
  }

  async revokeAllSessions(userId: string, reason = 'logout_all') {
    const result = await this.prisma.authSession.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date(), revokedReason: reason },
    });
    return { revokedSessions: result.count };
  }

  async listSessions(user: AuthUser) {
    const now = new Date();
    const sessions = await this.prisma.authSession.findMany({
      where: {
        userId: user.id,
        revokedAt: null,
        idleExpiresAt: { gt: now },
        absoluteExpiresAt: { gt: now },
      },
      orderBy: { lastUsedAt: 'desc' },
    });

    return sessions.map((session) => ({
      id: session.id,
      isCurrent: session.id === user.sessionId,
      deviceName: session.deviceName,
      platform: session.platform,
      appVersion: session.appVersion,
      createdAt: session.createdAt,
      lastUsedAt: session.lastUsedAt,
      expiresAt: session.idleExpiresAt,
      absoluteExpiresAt: session.absoluteExpiresAt,
    }));
  }

  private tokenPair(
    userId: string,
    sessionId: string,
    refreshToken: string,
    now: Date,
    refreshTokenExpiresAt: Date,
  ): AuthTokenPair {
    const accessTokenExpiresAt = new Date(now.getTime() + ACCESS_TOKEN_SECONDS * 1000);
    return {
      accessToken: this.signJwt({
        aud: TOKEN_AUDIENCE,
        exp: Math.floor(accessTokenExpiresAt.getTime() / 1000),
        iat: Math.floor(now.getTime() / 1000),
        iss: TOKEN_ISSUER,
        jti: randomBytes(16).toString('base64url'),
        sid: sessionId,
        sub: userId,
        typ: 'access',
      }),
      refreshToken,
      accessTokenExpiresAt,
      refreshTokenExpiresAt,
    };
  }

  private signJwt(payload: AccessTokenPayload): string {
    const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
    const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
    const signature = this.sign(`${header}.${body}`);
    return `${header}.${body}.${signature}`;
  }

  private verifyJwt(token: string): AccessTokenPayload {
    const [header, body, signature, extra] = token.split('.');
    if (!header || !body || !signature || extra) {
      throw new UnauthorizedException('Invalid access token');
    }

    const expected = this.sign(`${header}.${body}`);
    const actualBuffer = Buffer.from(signature);
    const expectedBuffer = Buffer.from(expected);
    if (
      actualBuffer.length !== expectedBuffer.length
      || !timingSafeEqual(actualBuffer, expectedBuffer)
    ) {
      throw new UnauthorizedException('Invalid access token signature');
    }

    try {
      const parsedHeader = JSON.parse(Buffer.from(header, 'base64url').toString('utf8')) as {
        alg?: string;
        typ?: string;
      };
      const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8')) as AccessTokenPayload;
      const now = Math.floor(Date.now() / 1000);
      if (
        parsedHeader.alg !== 'HS256'
        || parsedHeader.typ !== 'JWT'
        || payload.typ !== 'access'
        || payload.iss !== TOKEN_ISSUER
        || payload.aud !== TOKEN_AUDIENCE
        || typeof payload.sub !== 'string'
        || typeof payload.sid !== 'string'
        || typeof payload.jti !== 'string'
        || typeof payload.exp !== 'number'
        || payload.exp <= now
      ) {
        throw new Error('invalid claims');
      }
      return payload;
    } catch {
      throw new UnauthorizedException('Invalid or expired access token');
    }
  }

  private sign(value: string): string {
    return createHmac('sha256', this.jwtSecret()).update(value).digest('base64url');
  }

  private jwtSecret(): string {
    return process.env.JWT_SECRET || 'development-only-secret-change-before-production';
  }

  private assertProductionSecret() {
    if (process.env.NODE_ENV !== 'production') return;
    const secret = process.env.JWT_SECRET;
    if (!secret || Buffer.byteLength(secret) < 32) {
      throw new Error('JWT_SECRET must contain at least 32 bytes in production');
    }
  }

  private generateRefreshToken(): string {
    return `frt_${randomBytes(48).toString('base64url')}`;
  }

  private hashRefreshToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private refreshExpiry(now: Date, absoluteExpiresAt: Date): Date {
    return new Date(Math.min(now.getTime() + REFRESH_IDLE_MILLISECONDS, absoluteExpiresAt.getTime()));
  }

  private clean(value?: string): string | undefined {
    const cleaned = value?.trim();
    return cleaned || undefined;
  }

  private async revokeSessionTransaction(
    transaction: Prisma.TransactionClient,
    sessionId: string,
    revokedAt: Date,
    revokedReason: string,
  ) {
    await transaction.authSession.updateMany({
      where: { id: sessionId, revokedAt: null },
      data: { revokedAt, revokedReason },
    });
  }
}
